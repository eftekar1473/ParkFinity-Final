import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

// Wallet top-up credit. The client sends only a val_id; the amount and the
// payer come from SSLCommerz, never from the request body. Without this the
// client could name its own amount and mint balance.

const STORE_ID = Deno.env.get('SSLCOMMERZ_STORE_ID') ?? 'testbox';
const STORE_PASS = Deno.env.get('SSLCOMMERZ_STORE_PASSWD') ?? 'testpass';
const IS_SANDBOX = (Deno.env.get('SSLCOMMERZ_SANDBOX') ?? 'true') !== 'false';
const VALIDATION_URL = IS_SANDBOX
  ? 'https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php'
  : 'https://securepay.sslcommerz.com/validator/api/validationserverAPI.php';

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status,
    });

  try {
    const { val_id } = await req.json();
    if (!val_id) return json({ error: 'Missing val_id' }, 400);

    // Caller identity comes from the JWT, not the body.
    const supabase = getSupabaseAdmin();
    const token = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (!token) return json({ error: 'Unauthorized' }, 401);
    const { data: userData, error: uErr } = await supabase.auth.getUser(token);
    if (uErr || !userData?.user) return json({ error: 'Unauthorized' }, 401);
    const userId = userData.user.id;

    const url = `${VALIDATION_URL}?val_id=${encodeURIComponent(val_id)}` +
      `&store_id=${encodeURIComponent(STORE_ID)}` +
      `&store_passwd=${encodeURIComponent(STORE_PASS)}&format=json`;
    const v = await (await fetch(url)).json();

    if (v.status !== 'VALID' && v.status !== 'VALIDATED') {
      return json({ error: 'Payment not valid', credited: false }, 402);
    }

    const amount = Number(v.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: 'Bad amount from gateway', credited: false }, 502);
    }

    // Idempotent: replaying the same val_id credits nothing extra.
    const { data: credited, error: cErr } = await supabase.rpc('credit_wallet_verified', {
      p_user: userId, p_amount: amount, p_txn: String(v.tran_id ?? val_id),
    });
    if (cErr) throw cErr;

    return json({ credited: credited === true, amount }, 200);
  } catch (error: any) {
    console.error('wallet-topup error:', error);
    return json({ error: error.message || 'Internal Server Error' }, 500);
  }
});
