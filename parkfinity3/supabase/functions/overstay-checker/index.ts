import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

// Thin wrapper over the in-database engine. The real overstay logic lives in the
// process_overstays() plpgsql function, which pg_cron runs every 10 minutes.
// This endpoint just lets an admin / test harness trigger a sweep on demand.
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const supabase = getSupabaseAdmin();
    const { data, error } = await supabase.rpc('process_overstays');
    if (error) throw error;
    return new Response(JSON.stringify({ message: 'Overstay sweep complete', result: data }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error: any) {
    console.error('overstay-checker error:', error);
    return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
