-- ==========================================
-- Enums
-- ==========================================
CREATE TYPE user_role AS ENUM ('Rider', 'Owner', 'Admin');

CREATE TYPE vehicle_type AS ENUM (
    'Bicycle', 'Motorcycle', 'Car', 'Rickshaw', 
    'Auto', 'CNG', 'SUV', 'Microbus', 'Pickup', 'EV', 'Other'
);

CREATE TYPE booking_status AS ENUM (
    'Pending', 'Confirmed', 'Active', 'Completed', 
    'Cancelled', 'Overstayed'
);

CREATE TYPE payment_status AS ENUM ('Pending', 'Completed', 'Failed', 'Refunded');
CREATE TYPE withdrawal_status AS ENUM ('Pending', 'Approved', 'Rejected', 'Completed');

-- ==========================================
-- Tables
-- ==========================================

-- 1. Users Profile
-- Note: 'id' maps to the Firebase Auth UID or Supabase Auth ID
CREATE TABLE profiles (
    id UUID PRIMARY KEY, 
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    role user_role DEFAULT 'Rider',
    avatar_url TEXT,
    nid_url TEXT, -- Cloudinary URL
    driving_license_url TEXT, -- Cloudinary URL
    wallet_balance DECIMAL(12, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Vehicles (For Riders)
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    type vehicle_type NOT NULL,
    brand VARCHAR(100),
    model VARCHAR(100),
    license_plate VARCHAR(50) UNIQUE NOT NULL,
    color VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Parking Listings (For Owners)
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    address TEXT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    is_covered BOOLEAN DEFAULT FALSE,
    has_security BOOLEAN DEFAULT FALSE,
    has_cctv BOOLEAN DEFAULT FALSE,
    has_ev_charging BOOLEAN DEFAULT FALSE,
    allowed_vehicle_types vehicle_type[] NOT NULL,
    hourly_rate DECIMAL(10, 2),
    daily_rate DECIMAL(10, 2),
    weekly_rate DECIMAL(10, 2),
    monthly_rate DECIMAL(10, 2),
    instant_booking BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    photos TEXT[], -- Array of Cloudinary URLs
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Bookings
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id UUID REFERENCES profiles(id),
    listing_id UUID REFERENCES listings(id),
    vehicle_id UUID REFERENCES vehicles(id),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    actual_end_time TIMESTAMP WITH TIME ZONE,
    total_amount DECIMAL(10, 2) NOT NULL,
    commission_amount DECIMAL(10, 2) NOT NULL, -- Platform fee taken from total
    owner_earnings DECIMAL(10, 2) NOT NULL, -- total_amount - commission_amount
    status booking_status DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Payments
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id),
    amount DECIMAL(10, 2) NOT NULL,
    transaction_id VARCHAR(255) UNIQUE, -- SSLCommerz TXN ID
    payment_method VARCHAR(50), -- e.g., 'SSLCommerz', 'Wallet'
    status payment_status DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Withdrawals (Owner payouts)
CREATE TABLE withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES profiles(id),
    amount DECIMAL(10, 2) NOT NULL,
    bank_account_details TEXT NOT NULL,
    status withdrawal_status DEFAULT 'Pending',
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Reviews (Rider -> Listing/Owner, Owner -> Rider)
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    reviewer_id UUID REFERENCES profiles(id),
    reviewee_id UUID REFERENCES profiles(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
