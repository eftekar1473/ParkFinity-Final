-- ============================================================
-- Phase 8 - Push notifications (FCM) auto-dispatch
-- Every row inserted into `notifications` fires the send-push edge
-- function via pg_net, so all existing notification writers (edge fns
-- AND the in-db overstay engine) get push for free — no code change
-- at any call site. In-app/realtime path is untouched.
-- Idempotent / additive / safe re-run.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

-- ---------- 1. private config (project url + service key) ----------
-- NOT world-readable (unlike platform_settings). Only the SECURITY DEFINER
-- trigger below reads it. Populate once after deploy (see NOTE at bottom):
--   UPDATE app_config SET
--     functions_url = 'https://<ref>.functions.supabase.co',
--     service_role_key = '<service-role-key>' WHERE id = TRUE;
CREATE TABLE IF NOT EXISTS app_config (
  id               BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  functions_url    TEXT,
  service_role_key TEXT
);
INSERT INTO app_config (id) VALUES (TRUE) ON CONFLICT (id) DO NOTHING;

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
-- No policies => no anon/authenticated access at all. Only SECURITY DEFINER reads it.
REVOKE ALL ON app_config FROM anon, authenticated;

-- ---------- 2. dispatch function ----------
CREATE OR REPLACE FUNCTION dispatch_push()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url  TEXT;
  v_key  TEXT;
BEGIN
  SELECT functions_url, service_role_key INTO v_url, v_key
  FROM app_config WHERE id = TRUE;

  -- Not configured yet → silently skip (in-app notification still saved).
  IF v_url IS NULL OR v_key IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/send-push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || v_key),
    body    := jsonb_build_object(
                 'user_id', NEW.user_id,
                 'title',   NEW.title,
                 'message', NEW.message,
                 'data',    COALESCE(NEW.data, '{}'::jsonb))
  );
  RETURN NEW;
END;
$$;

-- ---------- 3. trigger ----------
DROP TRIGGER IF EXISTS trg_dispatch_push ON notifications;
CREATE TRIGGER trg_dispatch_push
  AFTER INSERT ON notifications
  FOR EACH ROW EXECUTE FUNCTION dispatch_push();

-- ============================================================
-- NOTE (run once, out-of-band — values not committed to git):
--   UPDATE app_config SET
--     functions_url    = 'https://rkqduzjkkyplceipydir.functions.supabase.co',
--     service_role_key = '<SUPABASE_SERVICE_ROLE_KEY>'
--   WHERE id = TRUE;
-- And set the edge secret:
--   supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
-- ============================================================
