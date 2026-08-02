import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

const STORE_ID = Deno.env.get('SSLCOMMERZ_STORE_ID') ?? 'testbox';
const STORE_PASS = Deno.env.get('SSLCOMMERZ_STORE_PASSWD') ?? 'testpass';
// Env-driven so production is a config change, not a code change.
const IS_SANDBOX = (Deno.env.get('SSLCOMMERZ_SANDBOX') ?? 'true') !== 'false';
const VALIDATION_URL = IS_SANDBOX
  ? 'https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php'
  : 'https://securepay.sslcommerz.com/validator/api/validationserverAPI.php';

serve(async (req) => {
  try {
    const formData = await req.formData();
    const status = formData.get('status');
    const val_id = formData.get('val_id');
    const tran_id = formData.get('tran_id');
    const amount = formData.get('amount');

    if (!tran_id || !status) {
      return new Response('Missing required IPN fields', { status: 400 });
    }

    const supabase = getSupabaseAdmin();

    // Only proceed if SSLCommerz reports success AND we can confirm it server-side.
    let validated = false;
    if ((status === 'VALID' || status === 'VALIDATED') && val_id) {
      // Real val_id validation — never trust the raw IPN. Ask SSLCommerz directly.
      const url = `${VALIDATION_URL}?val_id=${encodeURIComponent(val_id as string)}` +
        `&store_id=${encodeURIComponent(STORE_ID)}&store_passwd=${encodeURIComponent(STORE_PASS)}&format=json`;
      const res = await fetch(url);
      const v = await res.json();
      // Must be VALID/VALIDATED, tran_id must match, and amount must not be tampered.
      const amtOk = amount == null || Math.abs(Number(v.amount) - Number(amount)) < 0.01;
      validated =
        (v.status === 'VALID' || v.status === 'VALIDATED') &&
        v.tran_id === tran_id && amtOk;
    }

    if (validated) {
      const { data: payment, error: updErr } = await supabase
        .from('payments')
        .update({ status: 'Completed' })
        .eq('transaction_id', tran_id as string)
        .select()
        .single();
      if (updErr) throw updErr;

      if (payment?.booking_id) {
        await supabase.from('bookings').update({ status: 'Confirmed' }).eq('id', payment.booking_id);
      }
    } else {
      await supabase
        .from('payments')
        .update({ status: 'Failed' })
        .eq('transaction_id', tran_id as string);
    }

    return new Response('IPN processed', { status: 200 });
  } catch (error: any) {
    console.error('SSLCommerz Webhook Error:', error);
    return new Response(error.message || 'Internal Server Error', { status: 500 });
  }
});
