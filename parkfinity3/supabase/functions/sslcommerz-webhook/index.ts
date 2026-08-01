import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { getSupabaseAdmin } from '../_shared/supabase.ts';

serve(async (req) => {
  try {
    // SSLCommerz webhook sends data as form-urlencoded
    const formData = await req.formData();
    const status = formData.get('status');
    const val_id = formData.get('val_id');
    const tran_id = formData.get('tran_id');

    if (!tran_id || !status) {
      return new Response('Missing required IPN fields', { status: 400 });
    }

    const supabase = getSupabaseAdmin();

    if (status === 'VALID' || status === 'VALIDATED') {
      // Normally you would make a call to SSLCommerz API to validate the val_id here.
      // Assuming successful validation for now.

      // 1. Update Payment Status
      const { data: payment, error: updatePaymentError } = await supabase
        .from('payments')
        .update({ status: 'Completed' })
        .eq('transaction_id', tran_id as string)
        .select()
        .single();

      if (updatePaymentError) throw updatePaymentError;

      // 2. Update Booking Status
      if (payment && payment.booking_id) {
        await supabase
          .from('bookings')
          .update({ status: 'Confirmed' })
          .eq('id', payment.booking_id);
          
        // Note: A trigger could also notify the Owner via FCM here
      }
    } else {
      // Mark as Failed
      await supabase
        .from('payments')
        .update({ status: 'Failed' })
        .eq('transaction_id', tran_id as string);
    }

    return new Response('IPN processed successfully', { status: 200 });
  } catch (error: any) {
    console.error('SSLCommerz Webhook Error:', error);
    return new Response(error.message || 'Internal Server Error', { status: 500 });
  }
});
