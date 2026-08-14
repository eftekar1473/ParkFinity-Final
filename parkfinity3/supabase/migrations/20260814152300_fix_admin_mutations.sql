-- Update all admin functions to use SET search_path = public and case-insensitive check
CREATE OR REPLACE FUNCTION public.admin_set_suspended(p_user UUID, p_suspended BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_prev BOOLEAN;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;

  SELECT is_suspended INTO v_prev FROM public.profiles WHERE id = p_user;
  UPDATE public.profiles SET is_suspended = p_suspended, updated_at = now() WHERE id = p_user;

  IF v_prev IS DISTINCT FROM p_suspended THEN
    INSERT INTO public.notifications (user_id, title, message, type, data)
    VALUES (p_user,
            CASE WHEN p_suspended THEN 'Account suspended'
                 ELSE 'Account reinstated' END,
            CASE WHEN p_suspended
                 THEN 'Your account has been suspended. Contact support@parkfinity.app.'
                 ELSE 'Your account is active again. Welcome back.' END,
            'account', jsonb_build_object('suspended', p_suspended));
  END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.admin_set_kyc(p_user UUID, p_status TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_prev TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_status NOT IN ('none','pending','verified') THEN
    RAISE EXCEPTION 'Bad kyc_status %', p_status;
  END IF;

  SELECT kyc_status INTO v_prev FROM public.profiles WHERE id = p_user;
  UPDATE public.profiles SET kyc_status = p_status, updated_at = now() WHERE id = p_user;

  -- Only speak when the decision actually changed something.
  IF v_prev IS DISTINCT FROM p_status THEN
    IF p_status = 'verified' THEN
      INSERT INTO public.notifications (user_id, title, message, type, data)
      VALUES (p_user, 'Account verified',
              'Your ID check passed. You can now book and list parking.',
              'kyc', jsonb_build_object('kyc_status', p_status));
    ELSIF p_status = 'none' THEN
      INSERT INTO public.notifications (user_id, title, message, type, data)
      VALUES (p_user, 'Verification rejected',
              'Your documents were not accepted. Please upload clearer photos of your NID and licence.',
              'kyc', jsonb_build_object('kyc_status', p_status));
    END IF;
  END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.approve_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT * INTO w FROM public.withdrawals WHERE id = p_withdrawal;
  IF NOT FOUND THEN RAISE EXCEPTION 'Withdrawal % not found', p_withdrawal; END IF;
  IF w.status <> 'Pending' THEN RAISE EXCEPTION 'Withdrawal is %', w.status; END IF;

  UPDATE public.withdrawals SET status = 'Approved', processed_at = now() WHERE id = p_withdrawal;
END; $$;

CREATE OR REPLACE FUNCTION public.reject_withdrawal(p_withdrawal UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE w RECORD;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  SELECT * INTO w FROM public.withdrawals WHERE id = p_withdrawal;
  IF NOT FOUND THEN RAISE EXCEPTION 'Withdrawal % not found', p_withdrawal; END IF;
  IF w.status <> 'Pending' THEN RAISE EXCEPTION 'Withdrawal is %', w.status; END IF;

  -- restore the held funds to the owner wallet
  UPDATE public.profiles SET wallet_balance = wallet_balance + w.amount WHERE id = w.owner_id;
  INSERT INTO public.transactions (user_id, amount, type, status, reference_id)
  VALUES (w.owner_id, w.amount, 'deposit', 'Completed', 'withdrawal_refund');
  UPDATE public.withdrawals SET status = 'Rejected', processed_at = now() WHERE id = p_withdrawal;
END; $$;

GRANT EXECUTE ON FUNCTION public.admin_set_suspended(UUID, BOOLEAN) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_kyc(UUID, TEXT)          TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.approve_withdrawal(UUID)           TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reject_withdrawal(UUID)            TO authenticated, anon;
