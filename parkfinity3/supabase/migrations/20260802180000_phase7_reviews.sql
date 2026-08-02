-- ============================================================
-- Phase 7 - Ratings & Reviews (two-way, server-authoritative)
-- Adds one-per-side uniqueness, RLS, and a submit_review RPC that
-- validates the booking is Completed and the caller owns that side,
-- auto-resolving reviewee_id + reviewer_role + listing_id.
-- Idempotent / additive / safe re-run.
-- ============================================================

-- ---------- 1. one review per booking per side ----------
-- Rider writes one, owner writes one; reviewer_role distinguishes.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_review_booking_role
  ON reviews (booking_id, reviewer_role);

-- ---------- 2. RLS ----------
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Reviews are public (feed listing rating + reviewer name on details).
DROP POLICY IF EXISTS reviews_read ON reviews;
CREATE POLICY reviews_read ON reviews
  FOR SELECT USING (true);

-- Writes only through submit_review (SECURITY DEFINER); no direct client insert.
DROP POLICY IF EXISTS reviews_no_direct_insert ON reviews;
CREATE POLICY reviews_no_direct_insert ON reviews
  FOR INSERT WITH CHECK (false);

-- ---------- 3. submit_review RPC ----------
CREATE OR REPLACE FUNCTION submit_review(
  p_booking  UUID,
  p_rating   INT,
  p_comment  TEXT DEFAULT NULL,
  p_as_owner BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_rider     UUID;
  v_owner     UUID;
  v_listing   UUID;
  v_status    TEXT;
  v_reviewer  UUID;
  v_reviewee  UUID;
  v_role      TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Not authenticated');
  END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Rating must be 1-5');
  END IF;

  SELECT b.rider_id, l.owner_id, b.listing_id, b.status
    INTO v_rider, v_owner, v_listing, v_status
  FROM bookings b
  JOIN listings l ON l.id = b.listing_id
  WHERE b.id = p_booking;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Booking not found');
  END IF;
  IF v_status <> 'Completed' THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Can only review completed bookings');
  END IF;

  IF p_as_owner THEN
    IF v_uid <> v_owner THEN
      RETURN jsonb_build_object('ok', false, 'msg', 'Not your listing');
    END IF;
    v_reviewer := v_owner; v_reviewee := v_rider; v_role := 'owner';
  ELSE
    IF v_uid <> v_rider THEN
      RETURN jsonb_build_object('ok', false, 'msg', 'Not your booking');
    END IF;
    v_reviewer := v_rider; v_reviewee := v_owner; v_role := 'rider';
  END IF;

  INSERT INTO reviews (booking_id, reviewer_id, reviewee_id, listing_id,
                       reviewer_role, rating, comment)
  VALUES (p_booking, v_reviewer, v_reviewee, v_listing,
          v_role, p_rating, NULLIF(TRIM(COALESCE(p_comment, '')), ''))
  ON CONFLICT (booking_id, reviewer_role) DO NOTHING;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'msg', 'Already reviewed');
  END IF;

  RETURN jsonb_build_object('ok', true, 'msg', 'Thanks for your review');
END;
$$;

GRANT EXECUTE ON FUNCTION submit_review(UUID, INT, TEXT, BOOLEAN) TO authenticated;

-- ---------- 4. my_reviewed_bookings helper ----------
-- Returns booking_ids the caller has already reviewed for a given role,
-- so the client can hide the "Rate" button.
CREATE OR REPLACE FUNCTION my_reviewed_bookings(p_as_owner BOOLEAN DEFAULT FALSE)
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT booking_id FROM reviews
  WHERE reviewer_id = auth.uid()
    AND reviewer_role = CASE WHEN p_as_owner THEN 'owner' ELSE 'rider' END;
$$;

GRANT EXECUTE ON FUNCTION my_reviewed_bookings(BOOLEAN) TO authenticated;
