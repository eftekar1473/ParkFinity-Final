import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

const PLATFORM_COMMISSION_PERCENTAGE = 0.10; // 10%

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { rider_id, listing_id, vehicle_id, start_time, end_time } = await req.json();

    if (!rider_id || !listing_id || !vehicle_id || !start_time || !end_time) {
      return new Response(
        JSON.stringify({ error: 'Missing required booking fields' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    const start = new Date(start_time);
    const end = new Date(end_time);

    if (start >= end) {
      return new Response(
        JSON.stringify({ error: 'End time must be after start time' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      );
    }

    const supabase = getSupabaseAdmin();

    // 1. Fetch the listing details
    const { data: listing, error: listingError } = await supabase
      .from('listings')
      .select('hourly_rate, is_active')
      .eq('id', listing_id)
      .single();

    if (listingError || !listing) {
      throw new Error('Listing not found');
    }
    if (!listing.is_active) {
      throw new Error('This listing is currently inactive');
    }

    // 2. Check for overlapping bookings
    const { data: overlapping, error: overlapError } = await supabase
      .from('bookings')
      .select('id')
      .eq('listing_id', listing_id)
      .neq('status', 'Cancelled')
      .lt('start_time', end.toISOString())
      .gt('end_time', start.toISOString());

    if (overlapError) throw overlapError;
    if (overlapping && overlapping.length > 0) {
      return new Response(
        JSON.stringify({ error: 'This time slot is already booked' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409 }
      );
    }

    // 3. Calculate dynamic pricing (Simple hourly calculation for MVP)
    const durationHours = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60));
    const totalAmount = durationHours * listing.hourly_rate;
    const commissionAmount = totalAmount * PLATFORM_COMMISSION_PERCENTAGE;
    const ownerEarnings = totalAmount - commissionAmount;

    // 4. Create the Booking
    const { data: newBooking, error: bookingError } = await supabase
      .from('bookings')
      .insert({
        rider_id,
        listing_id,
        vehicle_id,
        start_time: start.toISOString(),
        end_time: end.toISOString(),
        total_amount: totalAmount,
        commission_amount: commissionAmount,
        owner_earnings: ownerEarnings,
        status: 'Pending'
      })
      .select()
      .single();

    if (bookingError) throw bookingError;

    return new Response(
      JSON.stringify({ message: 'Booking created successfully', booking: newBooking }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 201 }
    );

  } catch (error: any) {
    console.error('Error creating booking:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
