// send-push — mint an FCM HTTP v1 access token from a service-account secret
// and deliver a push to one user's device(s). Called by the notifications
// AFTER INSERT trigger (pg_net) so EVERY notification row auto-pushes, and
// callable directly for ad-hoc sends. Deploy with --no-verify-jwt; it uses the
// service-role key internally to read profiles.fcm_token.
//
// Secrets required (supabase secrets set ...):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (auto-present in edge runtime)
//   FCM_SERVICE_ACCOUNT  = the Firebase service-account JSON (single line)
//
// Free: FCM is unlimited; token is cached in-memory per warm instance.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri: string;
}

let _sa: ServiceAccount | null = null;
function serviceAccount(): ServiceAccount {
  if (_sa) return _sa;
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) throw new Error('FCM_SERVICE_ACCOUNT secret not set');
  _sa = JSON.parse(raw);
  return _sa!;
}

// --- RS256 JWT signing via Web Crypto (no external deps) ---
function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

// Access-token cache (per warm instance) — avoid re-minting every call.
let _token: { value: string; exp: number } | null = null;

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (_token && _token.exp - 60 > now) return _token.value;

  const sa = serviceAccount();
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: FCM_SCOPE,
      aud: sa.token_uri,
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claim}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput)),
  );
  const jwt = `${signingInput}.${b64url(sig)}`;

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`token mint failed: ${JSON.stringify(json)}`);
  _token = { value: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return _token.value;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    // Accepts either an explicit user_id or a full notification row (from trigger).
    const userId: string | undefined = body.user_id ?? body.record?.user_id;
    const title: string = body.title ?? body.record?.title ?? 'ParkFinity';
    const message: string = body.message ?? body.record?.message ?? '';
    const data = body.data ?? body.record?.data ?? {};

    if (!userId) {
      return new Response(JSON.stringify({ ok: false, error: 'user_id required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .maybeSingle();

    const token = profile?.fcm_token as string | null;
    if (!token) {
      // Not an error — user just has no device registered. In-app row still exists.
      return new Response(JSON.stringify({ ok: true, skipped: 'no fcm_token' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const accessToken = await getAccessToken();
    const projectId = serviceAccount().project_id;

    // FCM data values must be strings.
    const stringData: Record<string, string> = {};
    for (const [k, v] of Object.entries(data ?? {})) {
      stringData[k] = typeof v === 'string' ? v : JSON.stringify(v);
    }

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: message },
            data: stringData,
            android: { priority: 'HIGH' },
          },
        }),
      },
    );

    const fcmJson = await fcmRes.json();
    if (!fcmRes.ok) {
      // Stale/invalid token → clear it so we stop retrying.
      const status = fcmJson?.error?.status;
      if (status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT' || status === 'UNREGISTERED') {
        await supabase.from('profiles').update({ fcm_token: null }).eq('id', userId);
      }
      return new Response(JSON.stringify({ ok: false, error: fcmJson }), {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ ok: true, name: fcmJson.name }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
