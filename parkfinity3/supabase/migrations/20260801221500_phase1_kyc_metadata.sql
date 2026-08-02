-- Phase 1 - backfill auth JWT metadata so the router KYC gate (which reads
-- user_metadata synchronously) does not lock out pre-existing users.
-- Runs as postgres via `db push`, so it may touch the auth schema.

-- Grandfather every existing auth user to verified (their profiles row was
-- already set to 'verified' in Phase 0). New sign-ups get 'none' via the
-- column default + handle_new_user trigger, so they still hit the KYC gate.
UPDATE auth.users
SET raw_user_meta_data =
      COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"kyc_status":"verified"}'::jsonb
WHERE COALESCE(raw_user_meta_data->>'kyc_status', '') <> 'verified';

-- Keep the profiles.kyc_status and auth metadata in lock-step going forward:
-- whenever a profile's kyc_status changes, mirror it into the JWT metadata.
CREATE OR REPLACE FUNCTION public.sync_kyc_to_auth()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.kyc_status IS DISTINCT FROM OLD.kyc_status THEN
    UPDATE auth.users
    SET raw_user_meta_data =
          COALESCE(raw_user_meta_data, '{}'::jsonb)
          || jsonb_build_object('kyc_status', NEW.kyc_status)
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_sync_kyc ON public.profiles;
CREATE TRIGGER trg_sync_kyc
  AFTER UPDATE OF kyc_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_kyc_to_auth();
