-- vehicles table
CREATE TABLE public.vehicles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    rider_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    make TEXT NOT NULL,
    model TEXT NOT NULL,
    license_plate TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Ensure license_plate is unique per rider so they don't add the same car twice
    UNIQUE (rider_id, license_plate)
);

-- Enable RLS
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Policies for vehicles
CREATE POLICY "Users can view their own vehicles" 
    ON public.vehicles FOR SELECT 
    USING (auth.uid() = rider_id);

CREATE POLICY "Users can insert their own vehicles" 
    ON public.vehicles FOR INSERT 
    WITH CHECK (auth.uid() = rider_id);

CREATE POLICY "Users can update their own vehicles" 
    ON public.vehicles FOR UPDATE 
    USING (auth.uid() = rider_id);

CREATE POLICY "Users can delete their own vehicles" 
    ON public.vehicles FOR DELETE 
    USING (auth.uid() = rider_id);
