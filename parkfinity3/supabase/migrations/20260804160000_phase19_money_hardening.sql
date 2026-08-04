-- ============================================================
-- Phase 19 — Money-flow hardening.
--
-- Two real defects closed here:
--   1. add_funds was a SECURITY DEFINER function reachable by any logged-in
--      user with a caller-supplied amount. A rider could mint wallet balance
--      by calling the RPC directly, without paying anything. Top-ups must be
--      credited by the server only, after SSLCommerz validation.
--   2. deduct_funds read the balance without locking the row, so two
--      concurrent bookings could both pass the check and overdraw the wallet.
-- ============================================================

-- ---------- 1. Idempotent, service-role-only top-up credit ----------

-- reject_withdrawal wrote a fixed literal here, which would collide with the
-- unique deposit index below. The withdrawal id is the correct reference.
UPDATE transactions SET reference_id = 'withdrawal_refund:' || id::text
WHERE type = 'deposit' AND reference_id = 'withdrawal_refund';

-- One completed deposit per gateway transaction id. A replayed IPN or a
-- double-tapped return screen hits this and credits nothing extra.
CREATE UNIQUE INDEX IF NOT EXISTS transactions_deposit_ref_uniq
  ON transactions (reference_id)
  WHERE type = 'deposit' AND reference_id IS NOT NULL;

CREATE OR REPLACE FUNCTION credit_wallet_verified(
  p_user   UUID,
  p_amount NUMERIC,
  p_txn    TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  -- Idempotency gate: if this gateway txn already credited, do nothing.
  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (p_user, p_amount, 'deposit', 'Completed', p_txn)
  ON CONFLICT (reference_id) WHERE (type = 'deposit' AND reference_id IS NOT NULL)
  DO NOTHING;

  IF NOT FOUND THEN
    RETURN FALSE;  -- already credited earlier
  END IF;

  UPDATE profiles
     SET wallet_balance = wallet_balance + p_amount, updated_at = now()
   WHERE id = p_user;

  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (p_user, 'Wallet topped up',
          '৳' || round(p_amount) || ' added to your wallet.',
          'payment', jsonb_build_object('amount', p_amount, 'txn', p_txn));

  RETURN TRUE;
END; $$;

REVOKE ALL ON FUNCTION credit_wallet_verified(UUID, NUMERIC, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION credit_wallet_verified(UUID, NUMERIC, TEXT) TO service_role;

-- The old client-callable mint. Keep the name for the archive's sake but make
-- it unreachable from a user JWT and route it through the guarded path.
CREATE OR REPLACE FUNCTION add_funds(user_id_param UUID, amount_param DECIMAL, txn_id_param VARCHAR)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM credit_wallet_verified(user_id_param, amount_param, txn_id_param);
END; $$;

REVOKE ALL ON FUNCTION add_funds(UUID, DECIMAL, VARCHAR) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION add_funds(UUID, DECIMAL, VARCHAR) TO service_role;

-- ---------- 2. Race-safe debit ----------

CREATE OR REPLACE FUNCTION deduct_funds(
  user_id_param     UUID,
  amount_param      DECIMAL,
  booking_id_param  UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
  VALUES (user_id_param, amount_param, 'payment', 'Completed', booking_id_param::varchar);
END; $$;

REVOKE ALL ON FUNCTION deduct_funds(UUID, DECIMAL, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_funds(UUID, DECIMAL, UUID) TO service_role;

-- ---------- 3. reject_withdrawal: per-withdrawal deposit reference ----------
-- Was a fixed 'withdrawal_refund' literal, which now collides with the unique
-- deposit index on the second rejection. Scope the reference to the withdrawal.
CREATE OR REPLACE FUNCTION reject_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT * INTO w FROM withdrawals WHERE id = p_withdrawal AND status = 'Pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  UPDATE profiles SET wallet_balance = wallet_balance + w.amount WHERE id = w.owner_id;
  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (w.owner_id, w.amount, 'deposit', 'Completed', 'withdrawal_refund:' || w.id::text);
  UPDATE withdrawals SET status = 'Rejected', processed_at = now() WHERE id = p_withdrawal;

  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (w.owner_id, 'Withdrawal rejected',
          'BDT ' || w.amount || ' was returned to your wallet. Check your bank details and try again.',
          'withdrawal', jsonb_build_object('withdrawal_id', w.id, 'amount', w.amount));
END; $$;

-- ---------- 4. Balance can never go below zero ----------

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_wallet_balance_nonneg;
ALTER TABLE profiles ADD CONSTRAINT profiles_wallet_balance_nonneg
  CHECK (wallet_balance >= 0) NOT VALID;
