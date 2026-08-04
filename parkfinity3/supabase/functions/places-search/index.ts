// Places proxy. The Google key lives here as a Supabase secret so it is never
// shipped inside the APK (ADR-05). Two actions:
//   { action: 'autocomplete', query, lat?, lng? } -> [{ id, title, subtitle }]
//   { action: 'details', place_id }               -> { lat, lng, address }
// Any Google-side failure returns 200 with an empty list so the client can fall
// back to on-device geocoding instead of showing an error to the rider.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

const KEY = Deno.env.get('GOOGLE_PLACES_KEY') ?? '';
const BASE = 'https://maps.googleapis.com/maps/api/place';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    if (!KEY) return json({ predictions: [], error: 'places_key_missing' });

    const body = await req.json();
    const action = body.action ?? 'autocomplete';

    if (action === 'details') {
      const placeId = String(body.place_id ?? '');
      if (!placeId) return json({ error: 'place_id required' }, 400);

      const url =
        `${BASE}/details/json?place_id=${encodeURIComponent(placeId)}` +
        `&fields=geometry,formatted_address,name&key=${KEY}`;
      const r = await fetch(url);
      const d = await r.json();
      const loc = d?.result?.geometry?.location;
      if (!loc) return json({ error: d?.status ?? 'not_found' }, 404);

      return json({
        lat: loc.lat,
        lng: loc.lng,
        address: d.result.formatted_address ?? d.result.name ?? '',
      });
    }

    const query = String(body.query ?? '').trim();
    if (query.length < 2) return json({ predictions: [] });

    // Bias to the rider's position when we have it; Bangladesh otherwise, since
    // that is the only market the app serves today.
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    const bias =
      Number.isFinite(lat) && Number.isFinite(lng)
        ? `&location=${lat},${lng}&radius=30000`
        : '&components=country:bd';

    const url =
      `${BASE}/autocomplete/json?input=${encodeURIComponent(query)}` +
      `${bias}&key=${KEY}`;
    const r = await fetch(url);
    const d = await r.json();

    if (d.status !== 'OK' && d.status !== 'ZERO_RESULTS') {
      // REQUEST_DENIED / OVER_QUERY_LIMIT etc. -> let the client fall back.
      return json({ predictions: [], error: d.status ?? 'places_failed' });
    }

    const predictions = (d.predictions ?? []).slice(0, 6).map((p: any) => ({
      id: p.place_id,
      title: p.structured_formatting?.main_text ?? p.description ?? '',
      subtitle: p.structured_formatting?.secondary_text ?? '',
    }));

    return json({ predictions });
  } catch (e) {
    return json({ predictions: [], error: String(e) });
  }
});
