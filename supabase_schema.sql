-- Supabase Database Schema for Jayienne Link
-- Pure Supabase setup (no Firebase compatibility)

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- =====================================================
-- COUPLES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS couples (
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
-- USERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
-- INVITE_CODES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS invite_codes (
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
-- PARTNER_REQUESTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS partner_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_email TEXT NOT NULL,
    receiver_email TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    receiver_name TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);

-- =====================================================
-- ANNIVERSARY_REQUESTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS anniversary_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    proposer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_date TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);

-- =====================================================
-- LOCATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS locations (
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
-- HEARTBEATS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS heartbeats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_couple_id ON users(couple_id);
CREATE INDEX IF NOT EXISTS idx_users_invite_code ON users(invite_code);

-- Couples indexes
CREATE INDEX IF NOT EXISTS idx_couples_partner_ids ON couples USING GIN(partner_ids);
CREATE INDEX IF NOT EXISTS idx_couples_created_at ON couples(created_at);

-- Invite codes indexes
CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_invite_codes_user_id ON invite_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_invite_codes_expires_at ON invite_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_invite_codes_used ON invite_codes(used);

-- Partner requests indexes
CREATE INDEX IF NOT EXISTS idx_partner_requests_sender_id ON partner_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_partner_requests_receiver_id ON partner_requests(receiver_id);
CREATE INDEX IF NOT EXISTS idx_partner_requests_status ON partner_requests(status);
CREATE INDEX IF NOT EXISTS idx_partner_requests_created_at ON partner_requests(created_at DESC);

-- Anniversary requests indexes
CREATE INDEX IF NOT EXISTS idx_anniversary_requests_couple_id ON anniversary_requests(couple_id);
CREATE INDEX IF NOT EXISTS idx_anniversary_requests_proposer_id ON anniversary_requests(proposer_id);
CREATE INDEX IF NOT EXISTS idx_anniversary_requests_partner_id ON anniversary_requests(partner_id);
CREATE INDEX IF NOT EXISTS idx_anniversary_requests_status ON anniversary_requests(status);

-- Locations indexes
CREATE INDEX IF NOT EXISTS idx_locations_couple_id ON locations(couple_id);
CREATE INDEX IF NOT EXISTS idx_locations_owner_id ON locations(owner_id);
CREATE INDEX IF NOT EXISTS idx_locations_timestamp ON locations(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_locations_created_at ON locations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_locations_coordinates ON locations USING GIST(point(longitude, latitude));

-- Heartbeats indexes
CREATE INDEX IF NOT EXISTS idx_heartbeats_couple_id ON heartbeats(couple_id);
CREATE INDEX IF NOT EXISTS idx_heartbeats_sender_id ON heartbeats(sender_id);
CREATE INDEX IF NOT EXISTS idx_heartbeats_receiver_id ON heartbeats(receiver_id);
CREATE INDEX IF NOT EXISTS idx_heartbeats_sent_at ON heartbeats(sent_at DESC);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_couples_updated_at ON couples;
CREATE TRIGGER update_couples_updated_at BEFORE UPDATE ON couples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE anniversary_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE heartbeats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can read own couple" ON couples;
DROP POLICY IF EXISTS "Users can update own couple" ON couples;
DROP POLICY IF EXISTS "Users can create couples" ON couples;
DROP POLICY IF EXISTS "Users can manage own invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Anyone can read valid invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Users can read own partner requests" ON partner_requests;
DROP POLICY IF EXISTS "Users can send partner requests" ON partner_requests;
DROP POLICY IF EXISTS "Users can update partner requests" ON partner_requests;
DROP POLICY IF EXISTS "Users can delete partner requests" ON partner_requests;
DROP POLICY IF EXISTS "Users can read own anniversary requests" ON anniversary_requests;
DROP POLICY IF EXISTS "Users can send anniversary requests" ON anniversary_requests;
DROP POLICY IF EXISTS "Users can update anniversary requests" ON anniversary_requests;
DROP POLICY IF EXISTS "Users can delete anniversary requests" ON anniversary_requests;
DROP POLICY IF EXISTS "Users can read couple locations" ON locations;
DROP POLICY IF EXISTS "Users can insert own locations" ON locations;
DROP POLICY IF EXISTS "Users can update own locations" ON locations;
DROP POLICY IF EXISTS "Users can read couple heartbeats" ON heartbeats;
DROP POLICY IF EXISTS "Users can send heartbeats" ON heartbeats;

-- Users policies (users.id = auth.uid())
CREATE POLICY "Users can read own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Couples policies
CREATE POLICY "Users can read own couple" ON couples
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = couples.id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can update own couple" ON couples
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = couples.id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can create couples" ON couples
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Invite codes policies
CREATE POLICY "Users can manage own invite codes" ON invite_codes
    FOR ALL USING (
        user_id = auth.uid() OR used_by = auth.uid()
    );

CREATE POLICY "Anyone can read valid invite codes" ON invite_codes
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND NOT used AND expires_at > NOW()
    );

-- Partner requests policies
CREATE POLICY "Users can read own partner requests" ON partner_requests
    FOR SELECT USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

CREATE POLICY "Users can send partner requests" ON partner_requests
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update partner requests" ON partner_requests
    FOR UPDATE USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

CREATE POLICY "Users can delete partner requests" ON partner_requests
    FOR DELETE USING (
        auth.uid() = sender_id OR auth.uid() = receiver_id
    );

-- Anniversary requests policies
CREATE POLICY "Users can read own anniversary requests" ON anniversary_requests
    FOR SELECT USING (
        auth.uid() = proposer_id OR auth.uid() = partner_id
    );

CREATE POLICY "Users can send anniversary requests" ON anniversary_requests
    FOR INSERT WITH CHECK (auth.uid() = proposer_id);

CREATE POLICY "Users can update anniversary requests" ON anniversary_requests
    FOR UPDATE USING (
        auth.uid() = proposer_id OR auth.uid() = partner_id
    );

CREATE POLICY "Users can delete anniversary requests" ON anniversary_requests
    FOR DELETE USING (
        auth.uid() = proposer_id OR auth.uid() = partner_id
    );

-- Locations policies
CREATE POLICY "Users can read couple locations" ON locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = locations.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own locations" ON locations
    FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update own locations" ON locations
    FOR UPDATE USING (owner_id = auth.uid());

-- Heartbeats policies
CREATE POLICY "Users can read couple heartbeats" ON heartbeats
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = heartbeats.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can send heartbeats" ON heartbeats
    FOR INSERT WITH CHECK (sender_id = auth.uid());

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_expired_invite_codes()
RETURNS void AS $$
BEGIN
    DELETE FROM invite_codes WHERE expires_at < NOW() AND NOT used;
END;
$$ LANGUAGE plpgsql;

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
    INSERT INTO couples (partner_ids, partner_names)
    VALUES (ARRAY[user1_id, user2_id], ARRAY[user1_name, user2_name])
    RETURNING id INTO new_couple_id;

    UPDATE users SET couple_id = new_couple_id WHERE id IN (user1_id, user2_id);

    RETURN new_couple_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
