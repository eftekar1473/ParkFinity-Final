-- Fix invalid transaction_type enum in deduct_funds
ALTER TYPE transaction_type ADD VALUE IF NOT EXISTS 'payment';

CREATE OR REPLACE FUNCTION deduct_funds(
  user_id_param UUID,
  amount_param DECIMAL,
  booking_id_param UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  bal DECIMAL;
BEGIN
  IF amount_param IS NULL OR amount_param <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  -- FOR UPDATE: without it two concurrent bookings both read the pre-debit
  -- balance, both pass the check, and the wallet goes negative.
  SELECT wallet_balance INTO bal FROM profiles WHERE id = user_id_param FOR UPDATE;

  IF bal IS NULL OR bal < amount_param THEN
    RAISE EXCEPTION 'Insufficient wallet balance';
  END IF;

  UPDATE profiles
     SET wallet_balance = wallet_balance - amount_param, updated_at = now()
   WHERE id = user_id_param;

  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (user_id_param, amount_param, 'booking_deduction', 'Completed', booking_id_param::varchar);
END;
$$;
