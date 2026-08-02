-- ============================================================
-- Phase 3 - Enable Realtime on listings
-- Rider map subscribes to listing changes (live slot availability).
-- Idempotent: only adds the table if not already in the publication.
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'listings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE listings;
  END IF;
END $$;
