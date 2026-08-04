-- ============================================================
-- Phase 19: notification completeness
--
-- Every notification INSERT already fires trg_dispatch_push, so adding the
-- missing INSERTs is all that is needed to get both the in-app row and the
-- push. The gaps closed here: KYC decision, withdrawal approve/reject,
-- account suspension, and "someone reviewed you".
-- ============================================================

-- ---------- KYC decision ----------
CREATE OR REPLACE FUNCTION admin_set_kyc(p_user UUID, p_status TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_prev TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_status NOT IN ('none','pending','verified') THEN
    RAISE EXCEPTION 'Bad kyc_status %', p_status;
  END IF;

  SELECT kyc_status INTO v_prev FROM profiles WHERE id = p_user;
  UPDATE profiles SET kyc_status = p_status, updated_at = now() WHERE id = p_user;

  -- Only speak when the decision actually changed something.
  IF v_prev IS DISTINCT FROM p_status THEN
    IF p_status = 'verified' THEN
      INSERT INTO notifications (user_id, title, message, type, data)
      VALUES (p_user, 'Account verified',
              'Your ID check passed. You can now book and list parking.',
              'kyc', jsonb_build_object('kyc_status', p_status));
    ELSIF p_status = 'none' THEN
      INSERT INTO notifications (user_id, title, message, type, data)
      VALUES (p_user, 'Verification rejected',
              'Your documents were not accepted. Please upload clearer photos of your NID and licence.',
              'kyc', jsonb_build_object('kyc_status', p_status));
    END IF;
  END IF;
END; $$;

-- ---------- Suspension ----------
CREATE OR REPLACE FUNCTION admin_set_suspended(p_user UUID, p_suspended BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_prev BOOLEAN;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;

  SELECT is_suspended INTO v_prev FROM profiles WHERE id = p_user;
  UPDATE profiles SET is_suspended = p_suspended, updated_at = now() WHERE id = p_user;

  IF v_prev IS DISTINCT FROM p_suspended THEN
    INSERT INTO notifications (user_id, title, message, type, data)
    VALUES (p_user,
            CASE WHEN p_suspended THEN 'Account suspended'
                 ELSE 'Account reinstated' END,
            CASE WHEN p_suspended
                 THEN 'Your account has been suspended. Contact support@parkfinity.app.'
                 ELSE 'Your account is active again. Welcome back.' END,
            'account', jsonb_build_object('suspended', p_suspended));
  END IF;
END; $$;

-- ---------- Withdrawal approved ----------
CREATE OR REPLACE FUNCTION approve_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;

  UPDATE withdrawals
    SET status = 'Completed', processed_at = now()
  WHERE id = p_withdrawal AND status = 'Pending'
  RETURNING * INTO w;

  IF NOT FOUND THEN RETURN; END IF;

  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (w.owner_id, 'Withdrawal paid',
          'BDT ' || w.amount || ' has been sent to your bank account.',
          'withdrawal', jsonb_build_object('withdrawal_id', w.id, 'amount', w.amount));
END; $$;

-- ---------- Withdrawal rejected ----------
CREATE OR REPLACE FUNCTION reject_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT * INTO w FROM withdrawals WHERE id = p_withdrawal AND status = 'Pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  -- restore the held funds to the owner wallet
  UPDATE profiles SET wallet_balance = wallet_balance + w.amount WHERE id = w.owner_id;
  INSERT INTO transactions (user_id, amount, type, status, reference_id)
  VALUES (w.owner_id, w.amount, 'deposit', 'Completed', 'withdrawal_refund');
  UPDATE withdrawals SET status = 'Rejected', processed_at = now() WHERE id = p_withdrawal;

  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (w.owner_id, 'Withdrawal rejected',
          'BDT ' || w.amount || ' was returned to your wallet. Check your bank details and try again.',
          'withdrawal', jsonb_build_object('withdrawal_id', w.id, 'amount', w.amount));
END; $$;

-- ---------- Review received ----------
-- Fires on the review row itself rather than inside submit_review, so a review
-- written by any path still notifies the person being rated.
CREATE OR REPLACE FUNCTION notify_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO notifications (user_id, title, message, type, data)
  VALUES (NEW.reviewee_id,
          'New review',
          'You received ' || NEW.rating || '★' ||
          COALESCE(' — "' || LEFT(NEW.comment, 80) || '"', '') || '.',
          'review',
          jsonb_build_object('booking_id', NEW.booking_id,
                             'rating', NEW.rating));
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_notify_review ON reviews;
CREATE TRIGGER trg_notify_review
  AFTER INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION notify_review();
