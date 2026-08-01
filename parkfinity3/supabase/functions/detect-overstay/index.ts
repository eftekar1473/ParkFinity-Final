import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = getSupabaseAdmin();
    const now = new Date().toISOString();

    // Find bookings that have passed their end_time, are confirmed, and haven't checked out yet
    const { data: overstayedBookings, error: fetchError } = await supabase
      .from('bookings')
      .select('*')
      .eq('status', 'Confirmed')
      .lt('end_time', now)
      .is('actual_end_time', null);

    if (fetchError) throw fetchError;

    if (!overstayedBookings || overstayedBookings.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No overstayed bookings found.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      );
    }

    const updatedIds = [];

    for (const booking of overstayedBookings) {
      // Mark as Overstayed
      const { error: updateError } = await supabase
        .from('bookings')
        .update({ status: 'Overstayed' })
        .eq('id', booking.id);

      if (!updateError) {
        updatedIds.push(booking.id);
        // Note: Here you would trigger an FCM Push Notification to the Rider warning them of penalty charges.
      }
    }

    return new Response(
      JSON.stringify({ message: `Marked ${updatedIds.length} bookings as overstayed.`, updatedIds }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error: any) {
    console.error('Overstay Detection Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
