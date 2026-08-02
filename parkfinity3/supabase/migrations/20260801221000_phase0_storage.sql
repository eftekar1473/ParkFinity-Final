-- Phase 0b - create the listings_video bucket the client already uploads to,
-- plus KYC/documents hardening. Idempotent.

-- listings_video bucket (client: add_listing_screen.dart uploads here; had no backing config)
INSERT INTO storage.buckets (id, name, public)
VALUES ('listings_video', 'listings_video', true)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Public Access listings_video') THEN
    CREATE POLICY "Public Access listings_video" ON storage.objects
      FOR SELECT USING (bucket_id = 'listings_video');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can upload listings_video') THEN
    CREATE POLICY "Users can upload listings_video" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'listings_video' AND auth.uid() = owner);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their listings_video') THEN
    CREATE POLICY "Users can update their listings_video" ON storage.objects
      FOR UPDATE USING (bucket_id = 'listings_video' AND auth.uid() = owner);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their listings_video') THEN
    CREATE POLICY "Users can delete their listings_video" ON storage.objects
      FOR DELETE USING (bucket_id = 'listings_video' AND auth.uid() = owner);
  END IF;
END $$;
