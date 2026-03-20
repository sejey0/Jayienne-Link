-- Supabase Database Schema Migration Script
-- Migrating from Firebase Firestore to PostgreSQL

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =====================================================
-- COUPLES TABLE (equivalent to 'couples' collection)
-- =====================================================
-- Creating this first as users table references it
CREATE TABLE couples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    partner_ids UUID[] NOT NULL CHECK (array_length(partner_ids, 1) = 2),
    partner_names TEXT[] NOT NULL CHECK (array_length(partner_names, 1) = 2),
    couple_name TEXT,
    anniversary TIMESTAMPTZ,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- USERS TABLE (equivalent to 'users' collection)
-- =====================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE, -- For migration compatibility
    email TEXT UNIQUE NOT NULL,
    phone_number TEXT,
    display_name TEXT NOT NULL,
    photo_url TEXT,
    birthday TIMESTAMPTZ,
    couple_id UUID REFERENCES couples(id) ON DELETE SET NULL,
    invite_code TEXT,
    profile_complete BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INVITE_CODES TABLE (equivalent to 'inviteCodes' collection)
-- =====================================================
CREATE TABLE invite_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '48 hours'),
    used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES users(id) ON DELETE SET NULL,
    used_at TIMESTAMPTZ
);

-- =====================================================
-- LOCATIONS TABLE (equivalent to couples/{id}/locations subcollection)
-- =====================================================
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION NOT NULL DEFAULT 0,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Users indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_couple_id ON users(couple_id);
CREATE INDEX idx_users_invite_code ON users(invite_code);

-- Couples indexes
CREATE INDEX idx_couples_partner_ids ON couples USING GIN(partner_ids);
CREATE INDEX idx_couples_created_at ON couples(created_at);

-- Invite codes indexes
CREATE INDEX idx_invite_codes_code ON invite_codes(code);
CREATE INDEX idx_invite_codes_user_id ON invite_codes(user_id);
CREATE INDEX idx_invite_codes_expires_at ON invite_codes(expires_at);
CREATE INDEX idx_invite_codes_used ON invite_codes(used);

-- Locations indexes (for geo queries and filtering)
CREATE INDEX idx_locations_couple_id ON locations(couple_id);
CREATE INDEX idx_locations_owner_id ON locations(owner_id);
CREATE INDEX idx_locations_timestamp ON locations(timestamp DESC);
CREATE INDEX idx_locations_created_at ON locations(created_at DESC);

-- Geographic index for spatial queries (future use)
CREATE INDEX idx_locations_coordinates ON locations USING GIST(point(longitude, latitude));

-- =====================================================
-- TRIGGERS FOR AUTOMATIC TIMESTAMP UPDATES
-- =====================================================

-- Function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_couples_updated_at BEFORE UPDATE ON couples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can read own profile" ON users
    FOR SELECT USING (auth.uid()::text = firebase_uid);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid()::text = firebase_uid);

CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid()::text = firebase_uid);

-- Couples policies
CREATE POLICY "Users can read own couple" ON couples
    FOR SELECT USING (
        auth.uid()::uuid = ANY(partner_ids) OR
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid()::uuid AND couple_id = couples.id)
    );

CREATE POLICY "Users can update own couple" ON couples
    FOR UPDATE USING (
        auth.uid()::uuid = ANY(partner_ids) OR
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid()::uuid AND couple_id = couples.id)
    );

-- Invite codes policies
CREATE POLICY "Users can manage own invite codes" ON invite_codes
    FOR ALL USING (
        user_id = auth.uid()::uuid OR
        used_by = auth.uid()::uuid
    );

CREATE POLICY "Anyone can read valid invite codes" ON invite_codes
    FOR SELECT USING (NOT used AND expires_at > NOW());

-- Locations policies
CREATE POLICY "Users can read couple locations" ON locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()::uuid AND couple_id = locations.couple_id
        )
    );

CREATE POLICY "Users can insert own locations" ON locations
    FOR INSERT WITH CHECK (owner_id = auth.uid()::uuid);

CREATE POLICY "Users can update own locations" ON locations
    FOR UPDATE USING (owner_id = auth.uid()::uuid);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to clean up expired invite codes
CREATE OR REPLACE FUNCTION cleanup_expired_invite_codes()
RETURNS void AS $$
BEGIN
    DELETE FROM invite_codes WHERE expires_at < NOW() AND NOT used;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's partner ID
CREATE OR REPLACE FUNCTION get_partner_id(user_uuid UUID)
RETURNS UUID AS $$
DECLARE
    partner_uuid UUID;
BEGIN
    SELECT
        CASE
            WHEN partner_ids[1] = user_uuid THEN partner_ids[2]
            WHEN partner_ids[2] = user_uuid THEN partner_ids[1]
            ELSE NULL
        END INTO partner_uuid
    FROM couples c
    JOIN users u ON u.couple_id = c.id
    WHERE u.id = user_uuid;

    RETURN partner_uuid;
END;
$$ LANGUAGE plpgsql;

-- Function to create a couple relationship
CREATE OR REPLACE FUNCTION create_couple(
    user1_id UUID,
    user2_id UUID,
    user1_name TEXT,
    user2_name TEXT
)
RETURNS UUID AS $$
DECLARE
    new_couple_id UUID;
BEGIN
    -- Create the couple
    INSERT INTO couples (partner_ids, partner_names)
    VALUES (ARRAY[user1_id, user2_id], ARRAY[user1_name, user2_name])
    RETURNING id INTO new_couple_id;

    -- Update both users' couple_id
    UPDATE users SET couple_id = new_couple_id WHERE id IN (user1_id, user2_id);

    RETURN new_couple_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INITIAL SETUP COMPLETE
-- =====================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;