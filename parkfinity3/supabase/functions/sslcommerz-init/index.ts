import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

const STORE_ID = Deno.env.get('SSLCOMMERZ_STORE_ID') ?? 'testbox';
const STORE_PASS = Deno.env.get('SSLCOMMERZ_STORE_PASS') ?? 'testpass';
const IS_SANDBOX = true;
const SSL_URL = IS_SANDBOX 
  ? 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php'
  : 'https://securepay.sslcommerz.com/gwprocess/v4/api.php';

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { booking_id } = await req.json();

    if (!booking_id) {
      return new Response(JSON.stringify({ error: 'Missing booking_id' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
    }

    const supabase = getSupabaseAdmin();

    // Fetch booking details
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('*, profiles:rider_id (full_name, email, phone_number)')
      .eq('id', booking_id)
      .single();

    if (bookingError || !booking) {
      throw new Error('Booking not found');
    }

    const transactionId = `txn_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    // Generate Form Data for SSLCommerz
    const formData = new URLSearchParams();
    formData.append('store_id', STORE_ID);
    formData.append('store_passwd', STORE_PASS);
    formData.append('total_amount', booking.total_amount.toString());
    formData.append('currency', 'BDT');
    formData.append('tran_id', transactionId);
    formData.append('success_url', 'https://parkfinity.com/payment/success');
    formData.append('fail_url', 'https://parkfinity.com/payment/fail');
    formData.append('cancel_url', 'https://parkfinity.com/payment/cancel');
    formData.append('ipn_url', `${Deno.env.get('SUPABASE_URL')}/functions/v1/sslcommerz-webhook`);
    formData.append('cus_name', booking.profiles?.full_name || 'Rider');
    formData.append('cus_email', booking.profiles?.email || 'test@test.com');
    formData.append('cus_add1', 'Dhaka');
    formData.append('cus_phone', booking.profiles?.phone_number || '01700000000');
    formData.append('shipping_method', 'NO');
    formData.append('product_name', 'Parking Booking');
    formData.append('product_category', 'Service');
    formData.append('product_profile', 'non-physical-goods');

    // Make request to SSLCommerz
    const response = await fetch(SSL_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData.toString(),
    });

    const sslData = await response.json();

    if (sslData.status !== 'SUCCESS') {
      throw new Error(`SSLCommerz Error: ${sslData.failedreason}`);
    }

    // Save pending payment record
    await supabase.from('payments').insert({
      booking_id,
      user_id: booking.rider_id,
      amount: booking.total_amount,
      transaction_id: transactionId,
      payment_method: 'SSLCommerz',
      status: 'Pending'
    });

    return new Response(
      JSON.stringify({ GatewayPageURL: sslData.GatewayPageURL }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error: any) {
    console.error('SSLCommerz Init Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal Server Error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
