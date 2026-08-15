import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { computePrice, DurationType } from '../_shared/pricing.ts';

// Server-authoritative booking creation.
// Order: validate -> compat -> atomic book_slot -> price -> deduct wallet -> insert -> notify.
// On any post-slot failure the slot is released so inventory never leaks.

const DURATION_UNIT_MS: Record<DurationType, number> = {
  Hourly: 3600e3,
  Daily: 86400e3,
  Weekly: 604800e3,
  Monthly: 2592000e3,
  Yearly: 31536000e3,
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const supabase = getSupabaseAdmin();
  let slotBooked: { listing: string; vtype: string; qty: number } | null = null;

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status,
    });

  try {
    const {
      rider_id, listing_id, vehicle_id, vehicle_type,
      duration_type, duration_count, start_time,
    } = await req.json();

    if (!rider_id || !listing_id || !vehicle_id || !vehicle_type || !duration_type || !duration_count) {
      return json({ error: 'Missing required booking fields' }, 400);
    }
    const dtype = duration_type as DurationType;
    const units = Number(duration_count);
    if (!DURATION_UNIT_MS[dtype] || units < 1) return json({ error: 'Invalid duration' }, 400);

    const start = start_time ? new Date(start_time) : new Date();
    const end = new Date(start.getTime() + DURATION_UNIT_MS[dtype] * units);

    // 0. Payment-due gate: riders with an unsettled overstay penalty are blocked.
    const { data: rider } = await supabase
      .from('profiles').select('has_payment_due, is_suspended').eq('id', rider_id).single();
    if (rider?.is_suspended) {
      return json({ error: 'Your account is suspended. Contact support.' }, 403);
    }
    if (rider?.has_payment_due) {
      return json({ error: 'You have an unpaid overstay penalty. Settle it before booking again.' }, 403);
    }

    // 1. Listing + rates + slot maps
    const { data: listing, error: lErr } = await supabase
      .from('listings')
      .select('is_active, instant_booking, hourly_rate, daily_rate, weekly_rate, monthly_rate, yearly_rate, slot_capacity, slot_available')
      .eq('id', listing_id)
      .single();
    if (lErr || !listing) throw new Error('Listing not found');
    if (!listing.is_active) throw new Error('This listing is currently inactive');

    // 2. Vehicle-type compatibility (must be a configured slot type)
    const capacity = (listing.slot_capacity ?? {}) as Record<string, number>;
    if (!(vehicle_type in capacity)) {
      return json({ error: `This spot does not accept ${vehicle_type}` }, 400);
    }
    const availableBefore = ((listing.slot_available ?? {}) as Record<string, number>)[vehicle_type] ?? 0;

    // 3. Platform settings + 7-day hour demand (for pricing)
    const [{ data: settings }, { data: demandCount }] = await Promise.all([
      supabase.from('platform_settings')
        .select('commission_rate, peak_multiplier, weekend_multiplier').eq('id', true).single(),
      supabase.rpc('listing_hour_demand', { p_listing: listing_id, p_hour: start.getUTCHours() }),
    ]);
    const cfg = settings ?? { commission_rate: 0.10, peak_multiplier: 1.5, weekend_multiplier: 1.2 };

    const price = computePrice({
      rates: listing,
      durationType: dtype,
      units,
      start,
      demandCount: (demandCount as number) ?? 0,
      available: availableBefore,
      capacity: capacity[vehicle_type] ?? 0,
      settings: cfg,
    });

    // 4. Interval reservation. Counts peak concurrency inside [start, end) instead
    //    of a single "slots free right now" number, so a 2pm-3pm booking never
    //    blocks a 5pm-6pm one on the same slot.
    const { data: booked, error: bookErr } = await supabase.rpc('reserve_interval', {
      p_listing: listing_id, p_vtype: vehicle_type, p_qty: 1,
      p_start: start.toISOString(), p_end: end.toISOString(),
    });
    if (bookErr) throw bookErr;
    if (booked !== true) {
      return json({ error: `No ${vehicle_type} slot available for that time` }, 409);
    }
    slotBooked = { listing: listing_id, vtype: vehicle_type, qty: 1 };

    // 5. Insert booking (manual mode stays Pending owner-approval; instant -> Confirmed)
    const status = listing.instant_booking === false ? 'Pending' : 'Confirmed';
    const { data: newBooking, error: insErr } = await supabase
      .from('bookings')
      .insert({
        rider_id, listing_id, vehicle_id, vehicle_type,
        duration_type: dtype, slot_qty: 1,
        start_time: start.toISOString(), end_time: end.toISOString(),
        base_amount: price.subtotal,
        total_amount: price.total,
        commission_amount: price.commission,
        owner_earnings: price.ownerEarnings,
        status,
      })
      .select()
      .single();
    if (insErr) throw insErr;

    // 6. Charge wallet (server-authoritative). Rollback slot + booking if it fails.
    const { error: payErr } = await supabase.rpc('deduct_funds', {
      user_id_param: rider_id, amount_param: price.total, booking_id_param: newBooking.id,
    });
    if (payErr) {
      await supabase.from('bookings').update({ status: 'Cancelled' }).eq('id', newBooking.id);
      await supabase.rpc('release_slot', { p_listing: listing_id, p_vtype: vehicle_type, p_qty: 1 });
      slotBooked = null;
      // Only the true "not enough balance" case is a 402; every other RPC
      // failure (missing column, constraint, type error) was previously
      // mislabelled as "insufficient balance" and hid the real defect.
      const msg = payErr.message ?? String(payErr);
      const insufficient = /insufficient wallet balance/i.test(msg);
      return json(
        { error: insufficient ? 'Payment failed: insufficient wallet balance' : `Payment failed: ${msg}` },
        insufficient ? 402 : 500,
      );
    }

    // 7. Notifications (rider + owner). Best-effort.
    const { data: ownerRow } = await supabase.from('listings').select('owner_id, title').eq('id', listing_id).single();
    await supabase.from('notifications').insert([
      {
        user_id: rider_id, type: 'booking',
        title: 'Booking confirmed',
        message: `Your ${vehicle_type} spot is booked for ৳${price.total}.`,
        data: { booking_id: newBooking.id, listing_id },
      },
      ownerRow?.owner_id ? {
        user_id: ownerRow.owner_id, type: 'booking',
        title: 'New booking',
        message: `A ${vehicle_type} slot at ${ownerRow.title ?? 'your listing'} was booked.`,
        data: { booking_id: newBooking.id, listing_id },
      } : null,
    ].filter(Boolean));

    return json({ message: 'Booking created', booking: newBooking, price }, 201);
  } catch (error: any) {
    // Roll back slot if we grabbed one before failing.
    if (slotBooked) {
      await supabase.rpc('release_slot', {
        p_listing: slotBooked.listing, p_vtype: slotBooked.vtype, p_qty: slotBooked.qty,
      }).catch(() => {});
    }
    console.error('create-booking error:', error);
    return json({ error: error.message || 'Internal Server Error' }, 500);
  }
});
