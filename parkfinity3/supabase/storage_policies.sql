-- Create buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('listings', 'listings', true);
INSERT INTO storage.buckets (id, name, public) VALUES ('documents', 'documents', true);

-- Policies for listings bucket
CREATE POLICY "Public Access listings" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'listings' );

CREATE POLICY "Users can upload listings" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'listings' AND auth.uid() = owner );

CREATE POLICY "Users can update their listings" 
ON storage.objects FOR UPDATE 
USING ( bucket_id = 'listings' AND auth.uid() = owner );

CREATE POLICY "Users can delete their listings" 
ON storage.objects FOR DELETE 
USING ( bucket_id = 'listings' AND auth.uid() = owner );

-- Policies for documents bucket
CREATE POLICY "Public Access documents" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'documents' );

CREATE POLICY "Users can upload documents" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'documents' AND auth.uid() = owner );

CREATE POLICY "Users can update their documents" 
ON storage.objects FOR UPDATE 
USING ( bucket_id = 'documents' AND auth.uid() = owner );

CREATE POLICY "Users can delete their documents" 
ON storage.objects FOR DELETE 
USING ( bucket_id = 'documents' AND auth.uid() = owner );
