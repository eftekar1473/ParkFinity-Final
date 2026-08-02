import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';
import { computePrice, DurationType } from '../_shared/pricing.ts';

// Extend an active/confirmed booking by extra duration.
// Prices the extra units with the same engine, guards against the next booking
// of that slot, charges the wallet, then pushes end_time. Same slot -> no re-lock.

const DURATION_UNIT_MS: Record<DurationType, number> = {
  Hourly: 3600e3, Daily: 86400e3, Weekly: 604800e3, Monthly: 2592000e3, Yearly: 31536000e3,
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const supabase = getSupabaseAdmin();
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: s });

  try {
    const { booking_id, rider_id, duration_type, duration_count } = await req.json();
    if (!booking_id || !rider_id || !duration_type || !duration_count) {
      return json({ error: 'Missing required fields' }, 400);
    }
    const dtype = duration_type as DurationType;
    const units = Number(duration_count);
    if (!DURATION_UNIT_MS[dtype] || units < 1) return json({ error: 'Invalid duration' }, 400);

    // 1. Load booking, verify ownership + state
    const { data: booking, error: bErr } = await supabase
      .from('bookings')
      .select('id, rider_id, listing_id, vehicle_type, end_time, status')
      .eq('id', booking_id)
      .single();
    if (bErr || !booking) throw new Error('Booking not found');
    if (booking.rider_id !== rider_id) return json({ error: 'Not your booking' }, 403);
    if (!['Confirmed', 'Active', 'Pending'].includes(booking.status)) {
      return json({ error: `Cannot extend a ${booking.status} booking` }, 409);
    }

    const currentEnd = new Date(booking.end_time);
    const newEnd = new Date(currentEnd.getTime() + DURATION_UNIT_MS[dtype] * units);

    // 2. Guard: cannot overrun the next booking of this slot
    const { data: nextStart } = await supabase.rpc('next_booking_start', {
      p_listing: booking.listing_id, p_exclude: booking.id, p_from: currentEnd.toISOString(),
    });
    if (nextStart && new Date(nextStart as string) < newEnd) {
      return json({ error: 'Slot is booked right after — choose a shorter extension' }, 409);
    }

    // 3. Price the extra units
    const { data: listing } = await supabase
      .from('listings')
      .select('hourly_rate, daily_rate, weekly_rate, monthly_rate, yearly_rate, slot_capacity, slot_available')
      .eq('id', booking.listing_id).single();
    if (!listing) throw new Error('Listing not found');

    const [{ data: settings }, { data: demandCount }] = await Promise.all([
      supabase.from('platform_settings').select('commission_rate, peak_multiplier, weekend_multiplier').eq('id', true).single(),
      supabase.rpc('listing_hour_demand', { p_listing: booking.listing_id, p_hour: currentEnd.getUTCHours() }),
    ]);
    const cfg = settings ?? { commission_rate: 0.10, peak_multiplier: 1.5, weekend_multiplier: 1.2 };
    const vtype = booking.vehicle_type ?? 'Car';
    const cap = (listing.slot_capacity ?? {}) as Record<string, number>;
    const avail = (listing.slot_available ?? {}) as Record<string, number>;

    const price = computePrice({
      rates: listing, durationType: dtype, units, start: currentEnd,
      demandCount: (demandCount as number) ?? 0,
      available: avail[vtype] ?? 0, capacity: cap[vtype] ?? 0, settings: cfg,
    });

    // 4. Charge wallet
    const { error: payErr } = await supabase.rpc('deduct_funds', {
      user_id_param: rider_id, amount_param: price.total, booking_id_param: booking.id,
    });
    if (payErr) return json({ error: 'Payment failed: insufficient wallet balance' }, 402);

    // 5. Push end_time + accumulate amounts
    const { data: updated, error: uErr } = await supabase
      .from('bookings')
      .update({ end_time: newEnd.toISOString(), updated_at: new Date().toISOString() })
      .eq('id', booking.id).select().single();
    if (uErr) throw uErr;

    await supabase.from('notifications').insert({
      user_id: rider_id, type: 'booking', title: 'Booking extended',
      message: `Extended by ${units} ${dtype} — ৳${price.total} charged.`,
      data: { booking_id: booking.id },
    });

    return json({ message: 'Extended', booking: updated, price }, 200);
  } catch (error: any) {
    console.error('extend-booking error:', error);
    return json({ error: error.message || 'Internal Server Error' }, 500);
  }
});
