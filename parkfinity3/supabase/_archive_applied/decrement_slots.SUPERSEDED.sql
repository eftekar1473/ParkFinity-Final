CREATE OR REPLACE FUNCTION decrement_slots(listing_id_param UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE listings
  SET available_slots = available_slots - 1
  WHERE id = listing_id_param AND available_slots > 0;
END;
$$ LANGUAGE plpgsql;
