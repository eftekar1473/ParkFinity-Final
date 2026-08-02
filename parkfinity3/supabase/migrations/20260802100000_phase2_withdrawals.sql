-- ============================================================
-- Phase 2 - Owner payouts: atomic withdrawal request + admin actions.
-- Idempotent, additive. ParkFinityDB.
-- ============================================================

-- Request a payout: verify balance, deduct (hold) from wallet, record a
-- transaction, and insert a Pending withdrawal — all in one transaction.
CREATE OR REPLACE FUNCTION request_withdrawal(
  p_owner   UUID,
  p_amount  DECIMAL,
  p_bank    TEXT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  bal DECIMAL;
  wid UUID;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;

  SELECT wallet_balance INTO bal FROM profiles WHERE id = p_owner FOR UPDATE;
  IF bal IS NULL OR bal < p_amount THEN
    RAISE EXCEPTION 'Insufficient wallet balance';
  END IF;

  UPDATE profiles SET wallet_balance = wallet_balance - p_amount WHERE id = p_owner;

  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (p_owner, p_amount, 'withdrawal', 'Pending', 'withdrawal_request');

  INSERT INTO withdrawals (owner_id, amount, bank_account_details, status)
  VALUES (p_owner, p_amount, p_bank, 'Pending')
  RETURNING id INTO wid;

  RETURN wid;
END; $$;

-- Admin: approve a payout (funds already held; just mark Completed/paid).
CREATE OR REPLACE FUNCTION approve_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE withdrawals
    SET status = 'Completed', processed_at = now()
  WHERE id = p_withdrawal AND status = 'Pending';
END; $$;

-- Admin: reject a payout — restore the held funds to the owner wallet.
CREATE OR REPLACE FUNCTION reject_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  w RECORD;
BEGIN
  SELECT * INTO w FROM withdrawals WHERE id = p_withdrawal AND status = 'Pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  UPDATE profiles SET wallet_balance = wallet_balance + w.amount WHERE id = w.owner_id;

  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (w.owner_id, w.amount, 'deposit', 'Completed', 'withdrawal_refund');

  UPDATE withdrawals SET status = 'Rejected', processed_at = now() WHERE id = p_withdrawal;
END; $$;

-- Owners read their own withdrawals; admins read all.
ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wd_own_select ON withdrawals;
CREATE POLICY wd_own_select ON withdrawals FOR SELECT
  USING (auth.uid() = owner_id
         OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'Admin'));
