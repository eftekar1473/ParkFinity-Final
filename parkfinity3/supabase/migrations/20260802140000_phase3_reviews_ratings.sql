-- ============================================================
-- Phase 3 - Reviews denormalization + rating aggregate
-- Adds listing_id to reviews (cheap per-listing avg), auto-fills
-- it from the booking, and exposes a rating summary view read by
-- rider discovery (details rating, AI scoring, filters).
-- Idempotent / additive / safe re-run.
-- ============================================================

-- ---------- 1. reviews: denormalized listing_id + role ----------
ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS listing_id     UUID REFERENCES listings(id),
  ADD COLUMN IF NOT EXISTS reviewer_role  TEXT; -- 'rider' | 'owner' (who wrote it)

-- Backfill listing_id from the booking chain for any existing rows.
UPDATE reviews r
SET listing_id = b.listing_id
FROM bookings b
WHERE r.booking_id = b.id
  AND r.listing_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_reviews_listing ON reviews(listing_id);

-- ---------- 2. auto-fill listing_id on insert ----------
CREATE OR REPLACE FUNCTION fill_review_listing_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.listing_id IS NULL AND NEW.booking_id IS NOT NULL THEN
    SELECT listing_id INTO NEW.listing_id
    FROM bookings WHERE id = NEW.booking_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_review_listing_id ON reviews;
CREATE TRIGGER trg_fill_review_listing_id
  BEFORE INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION fill_review_listing_id();

-- ---------- 3. rating summary view (rider reviews only) ----------
-- Only reviews written by riders count toward a listing's public rating.
CREATE OR REPLACE VIEW listing_rating_summary AS
SELECT
  listing_id,
  ROUND(AVG(rating)::numeric, 2) AS avg_rating,
  COUNT(*)                       AS review_count
FROM reviews
WHERE listing_id IS NOT NULL
  AND (reviewer_role IS DISTINCT FROM 'owner')  -- exclude owner->rider reviews
GROUP BY listing_id;

GRANT SELECT ON listing_rating_summary TO anon, authenticated;
