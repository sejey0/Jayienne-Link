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
    bubble_theme TEXT NOT NULL DEFAULT 'capybara',
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
    message TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- HEARTBEAT TYPING TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS heartbeat_typing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_typing BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (couple_id, user_id)
);

-- =====================================================
-- HEARTBEAT REACTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS heartbeat_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    heartbeat_id UUID NOT NULL REFERENCES heartbeats(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction TEXT NOT NULL DEFAULT 'purple_heart',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (heartbeat_id, user_id)
);

-- =====================================================
-- HEARTBEAT READS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS heartbeat_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    heartbeat_id UUID NOT NULL REFERENCES heartbeats(id) ON DELETE CASCADE,
    reader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (heartbeat_id, reader_id)
);

-- =====================================================
-- PHOTO MESSAGES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS photo_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    caption TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- MOOD MESSAGES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS mood_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mood TEXT NOT NULL,
    call_sign TEXT NOT NULL DEFAULT '',
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- MOOD MESSAGE READS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS mood_message_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    mood_message_id UUID NOT NULL REFERENCES mood_messages(id) ON DELETE CASCADE,
    reader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (mood_message_id, reader_id)
);

-- =====================================================
-- PHOTO MESSAGE READS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS photo_message_reads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    photo_message_id UUID NOT NULL REFERENCES photo_messages(id) ON DELETE CASCADE,
    reader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (photo_message_id, reader_id)
);

ALTER TABLE mood_messages
    ADD COLUMN IF NOT EXISTS call_sign TEXT NOT NULL DEFAULT '';

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS bubble_theme TEXT NOT NULL DEFAULT 'capybara';

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

-- Heartbeat typing indexes
CREATE INDEX IF NOT EXISTS idx_heartbeat_typing_couple_id
    ON heartbeat_typing(couple_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_typing_updated_at
    ON heartbeat_typing(updated_at DESC);

-- Heartbeat reactions indexes
CREATE INDEX IF NOT EXISTS idx_heartbeat_reactions_couple_id
    ON heartbeat_reactions(couple_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_reactions_heartbeat_id
    ON heartbeat_reactions(heartbeat_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_reactions_user_id
    ON heartbeat_reactions(user_id);

-- Heartbeat reads indexes
CREATE INDEX IF NOT EXISTS idx_heartbeat_reads_couple_id
    ON heartbeat_reads(couple_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_reads_heartbeat_id
    ON heartbeat_reads(heartbeat_id);
CREATE INDEX IF NOT EXISTS idx_heartbeat_reads_reader_id
    ON heartbeat_reads(reader_id);

-- Photo messages indexes
CREATE INDEX IF NOT EXISTS idx_photo_messages_couple_id ON photo_messages(couple_id);
CREATE INDEX IF NOT EXISTS idx_photo_messages_sender_id ON photo_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_photo_messages_receiver_id ON photo_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_photo_messages_sent_at ON photo_messages(sent_at DESC);

-- Mood messages indexes
CREATE INDEX IF NOT EXISTS idx_mood_messages_couple_id ON mood_messages(couple_id);
CREATE INDEX IF NOT EXISTS idx_mood_messages_sender_id ON mood_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_mood_messages_receiver_id ON mood_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_mood_messages_sent_at ON mood_messages(sent_at DESC);

-- Mood message reads indexes
CREATE INDEX IF NOT EXISTS idx_mood_message_reads_couple_id
    ON mood_message_reads(couple_id);
CREATE INDEX IF NOT EXISTS idx_mood_message_reads_message_id
    ON mood_message_reads(mood_message_id);
CREATE INDEX IF NOT EXISTS idx_mood_message_reads_reader_id
    ON mood_message_reads(reader_id);

-- Photo message reads indexes
CREATE INDEX IF NOT EXISTS idx_photo_message_reads_couple_id
    ON photo_message_reads(couple_id);
CREATE INDEX IF NOT EXISTS idx_photo_message_reads_message_id
    ON photo_message_reads(photo_message_id);
CREATE INDEX IF NOT EXISTS idx_photo_message_reads_reader_id
    ON photo_message_reads(reader_id);

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
ALTER TABLE heartbeat_typing ENABLE ROW LEVEL SECURITY;
ALTER TABLE heartbeat_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE heartbeat_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE mood_message_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_message_reads ENABLE ROW LEVEL SECURITY;

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
DROP POLICY IF EXISTS "Users can read couple typing" ON heartbeat_typing;
DROP POLICY IF EXISTS "Users can insert own typing" ON heartbeat_typing;
DROP POLICY IF EXISTS "Users can update own typing" ON heartbeat_typing;
DROP POLICY IF EXISTS "Users can read couple reactions" ON heartbeat_reactions;
DROP POLICY IF EXISTS "Users can insert own reactions" ON heartbeat_reactions;
DROP POLICY IF EXISTS "Users can update own reactions" ON heartbeat_reactions;
DROP POLICY IF EXISTS "Users can delete own reactions" ON heartbeat_reactions;
DROP POLICY IF EXISTS "Users can read couple reads" ON heartbeat_reads;
DROP POLICY IF EXISTS "Users can insert own reads" ON heartbeat_reads;
DROP POLICY IF EXISTS "Users can update own reads" ON heartbeat_reads;
DROP POLICY IF EXISTS "Users can read couple photo messages" ON photo_messages;
DROP POLICY IF EXISTS "Users can send photo messages" ON photo_messages;
DROP POLICY IF EXISTS "Users can update photo messages" ON photo_messages;
DROP POLICY IF EXISTS "Users can delete photo messages" ON photo_messages;
DROP POLICY IF EXISTS "Users can read couple mood messages" ON mood_messages;
DROP POLICY IF EXISTS "Users can send mood messages" ON mood_messages;
DROP POLICY IF EXISTS "Users can read couple mood reads" ON mood_message_reads;
DROP POLICY IF EXISTS "Users can insert own mood reads" ON mood_message_reads;
DROP POLICY IF EXISTS "Users can update own mood reads" ON mood_message_reads;
DROP POLICY IF EXISTS "Users can read couple photo reads" ON photo_message_reads;
DROP POLICY IF EXISTS "Users can insert own photo reads" ON photo_message_reads;
DROP POLICY IF EXISTS "Users can update own photo reads" ON photo_message_reads;

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

-- Heartbeat typing policies
CREATE POLICY "Users can read couple typing" ON heartbeat_typing
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = heartbeat_typing.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own typing" ON heartbeat_typing
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own typing" ON heartbeat_typing
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Heartbeat reactions policies
CREATE POLICY "Users can read couple reactions" ON heartbeat_reactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = heartbeat_reactions.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own reactions" ON heartbeat_reactions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own reactions" ON heartbeat_reactions
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own reactions" ON heartbeat_reactions
    FOR DELETE USING (user_id = auth.uid());

-- Heartbeat reads policies
CREATE POLICY "Users can read couple reads" ON heartbeat_reads
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = heartbeat_reads.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own reads" ON heartbeat_reads
    FOR INSERT WITH CHECK (reader_id = auth.uid());

CREATE POLICY "Users can update own reads" ON heartbeat_reads
    FOR UPDATE USING (reader_id = auth.uid())
    WITH CHECK (reader_id = auth.uid());

-- Photo messages policies
CREATE POLICY "Users can read couple photo messages" ON photo_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = photo_messages.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can send photo messages" ON photo_messages
    FOR INSERT WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update photo messages" ON photo_messages
    FOR UPDATE USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can delete photo messages" ON photo_messages
    FOR DELETE USING (sender_id = auth.uid());

-- Mood messages policies
CREATE POLICY "Users can read couple mood messages" ON mood_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = mood_messages.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can send mood messages" ON mood_messages
    FOR INSERT WITH CHECK (sender_id = auth.uid());

-- Mood message reads policies
CREATE POLICY "Users can read couple mood reads" ON mood_message_reads
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = mood_message_reads.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own mood reads" ON mood_message_reads
    FOR INSERT WITH CHECK (reader_id = auth.uid());

CREATE POLICY "Users can update own mood reads" ON mood_message_reads
    FOR UPDATE USING (reader_id = auth.uid())
    WITH CHECK (reader_id = auth.uid());

-- Photo message reads policies
CREATE POLICY "Users can read couple photo reads" ON photo_message_reads
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = photo_message_reads.couple_id AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own photo reads" ON photo_message_reads
    FOR INSERT WITH CHECK (reader_id = auth.uid());

CREATE POLICY "Users can update own photo reads" ON photo_message_reads
    FOR UPDATE USING (reader_id = auth.uid())
    WITH CHECK (reader_id = auth.uid());

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

CREATE OR REPLACE FUNCTION update_couple_partner_names()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.display_name IS DISTINCT FROM OLD.display_name AND NEW.couple_id IS NOT NULL THEN
        UPDATE couples
        SET partner_names = ARRAY(
            SELECT u.display_name
            FROM unnest(partner_ids) WITH ORDINALITY AS p(partner_id, ord)
            JOIN users u ON u.id = partner_id
            ORDER BY ord
        ),
        updated_at = NOW()
        WHERE id = NEW.couple_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_couple_partner_names ON users;
CREATE TRIGGER trg_update_couple_partner_names
AFTER UPDATE OF display_name ON users
FOR EACH ROW
EXECUTE FUNCTION update_couple_partner_names();

-- Create decision_ideas table for dynamic date & food options
CREATE TABLE IF NOT EXISTS public.decision_ideas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN ('food', 'activity')),
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.decision_ideas ENABLE ROW LEVEL SECURITY;

-- Allow public read access to decision ideas
DROP POLICY IF EXISTS "Allow public read access to decision ideas" ON public.decision_ideas;
CREATE POLICY "Allow public read access to decision ideas"
    ON public.decision_ideas FOR SELECT
    USING (true);

-- Seed initial online decision ideas
INSERT INTO public.decision_ideas (category, title) VALUES
('food', 'Korean BBQ Grill'),
('food', 'Artisanal Coffee & Waffles'),
('food', 'Gourmet Burger & Fries'),
('food', 'Homemade Pasta Night'),
('food', 'Matcha & Boba Tea'),
('food', 'Gelato & Churros'),
('food', 'Authentic Tonkotsu Ramen'),
('food', 'Woodfired Neapolitan Pizza'),
('activity', 'Open-Air Drive-in Movie'),
('activity', 'Botanical Garden Stroll'),
('activity', 'Co-op Video Game Quest'),
('activity', 'Acoustic Jam & Karaoke'),
('activity', 'Scenic Highway Night Drive'),
('activity', 'Telescope Stargazing'),
('activity', 'Board Game Tournament')
ON CONFLICT DO NOTHING;

-- =====================================================
-- MOVIES / CINEMA DIARY TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.movies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    poster_url TEXT,
    status TEXT NOT NULL DEFAULT 'watchlist' CHECK (status IN ('watchlist', 'watched')),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    notes TEXT,
    watched_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.movies ENABLE ROW LEVEL SECURITY;

-- Indexes for fast query performance
CREATE INDEX IF NOT EXISTS idx_movies_couple_id ON public.movies(couple_id);
CREATE INDEX IF NOT EXISTS idx_movies_status ON public.movies(status);
CREATE INDEX IF NOT EXISTS idx_movies_created_at ON public.movies(created_at DESC);

-- RLS Policies for movies
DROP POLICY IF EXISTS "Couple members can select their movies" ON public.movies;
CREATE POLICY "Couple members can select their movies"
    ON public.movies FOR SELECT
    USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE auth.uid() = ANY(partner_ids)
        )
    );

DROP POLICY IF EXISTS "Couple members can insert movies" ON public.movies;
CREATE POLICY "Couple members can insert movies"
    ON public.movies FOR INSERT
    WITH CHECK (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE auth.uid() = ANY(partner_ids)
        )
    );

DROP POLICY IF EXISTS "Couple members can update their movies" ON public.movies;
CREATE POLICY "Couple members can update their movies"
    ON public.movies FOR UPDATE
    USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE auth.uid() = ANY(partner_ids)
        )
    );

DROP POLICY IF EXISTS "Couple members can delete their movies" ON public.movies;
CREATE POLICY "Couple members can delete their movies"
    ON public.movies FOR DELETE
    USING (
        couple_id IN (
            SELECT id FROM public.couples
            WHERE auth.uid() = ANY(partner_ids)
        )
    );

-- Enable real-time for movies (ignore if already added)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'movies'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.movies;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- =====================================================
-- PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

