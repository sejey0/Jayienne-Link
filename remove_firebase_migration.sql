-- Remove Firebase Compatibility and Clean Up Database
-- This migration removes all Firebase-related fields and simplifies RLS policies

-- =====================================================
-- STEP 1: Drop old RLS policies
-- =====================================================

DROP POLICY IF EXISTS "Users can read own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can read own couple" ON couples;
DROP POLICY IF EXISTS "Users can update own couple" ON couples;
DROP POLICY IF EXISTS "Users can create couples" ON couples;
DROP POLICY IF EXISTS "Users can manage own invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Anyone can read valid invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Users can read couple locations" ON locations;
DROP POLICY IF EXISTS "Users can insert own locations" ON locations;
DROP POLICY IF EXISTS "Users can update own locations" ON locations;

-- =====================================================
-- STEP 2: Ensure users.id matches auth.uid() for existing users
-- =====================================================

-- For any users where id != firebase_uid, update the id to match auth UID
-- This ensures consistency before dropping firebase_uid column
-- NOTE: This assumes firebase_uid is the auth.uid() from Supabase Auth

-- Drop foreign key constraints temporarily
ALTER TABLE invite_codes DROP CONSTRAINT IF EXISTS invite_codes_user_id_fkey;
ALTER TABLE invite_codes DROP CONSTRAINT IF EXISTS invite_codes_used_by_fkey;
ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_owner_id_fkey;
ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_partner_id_fkey;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_couple_id_fkey;

-- Update all references to use firebase_uid as the canonical ID
UPDATE invite_codes ic
SET user_id = (SELECT firebase_uid::uuid FROM users WHERE id = ic.user_id)
WHERE EXISTS (SELECT 1 FROM users WHERE id = ic.user_id AND firebase_uid IS NOT NULL);

UPDATE invite_codes ic
SET used_by = (SELECT firebase_uid::uuid FROM users WHERE id = ic.used_by)
WHERE used_by IS NOT NULL
AND EXISTS (SELECT 1 FROM users WHERE id = ic.used_by AND firebase_uid IS NOT NULL);

UPDATE locations l
SET owner_id = (SELECT firebase_uid::uuid FROM users WHERE id = l.owner_id)
WHERE EXISTS (SELECT 1 FROM users WHERE id = l.owner_id AND firebase_uid IS NOT NULL);

UPDATE locations l
SET partner_id = (SELECT firebase_uid::uuid FROM users WHERE id = l.partner_id)
WHERE partner_id IS NOT NULL
AND EXISTS (SELECT 1 FROM users WHERE id = l.partner_id AND firebase_uid IS NOT NULL);

-- Update couples.partner_ids array
UPDATE couples c
SET partner_ids = ARRAY[
    COALESCE((SELECT firebase_uid::uuid FROM users WHERE id = c.partner_ids[1]), c.partner_ids[1]),
    COALESCE((SELECT firebase_uid::uuid FROM users WHERE id = c.partner_ids[2]), c.partner_ids[2])
];

-- Update users.couple_id to match (no change needed, it references couples.id)

-- Now update users.id to match firebase_uid
UPDATE users
SET id = firebase_uid::uuid
WHERE firebase_uid IS NOT NULL
AND id != firebase_uid::uuid;

-- Re-create foreign key constraints
ALTER TABLE invite_codes
    ADD CONSTRAINT invite_codes_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE invite_codes
    ADD CONSTRAINT invite_codes_used_by_fkey
    FOREIGN KEY (used_by) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE locations
    ADD CONSTRAINT locations_owner_id_fkey
    FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;

ALTER TABLE locations
    ADD CONSTRAINT locations_partner_id_fkey
    FOREIGN KEY (partner_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE users
    ADD CONSTRAINT users_couple_id_fkey
    FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE SET NULL;

-- =====================================================
-- STEP 3: Drop Firebase-related columns and indices
-- =====================================================

DROP INDEX IF EXISTS idx_users_firebase_uid;
ALTER TABLE users DROP COLUMN IF EXISTS firebase_uid;

-- =====================================================
-- STEP 4: Create simplified RLS policies (Supabase only)
-- =====================================================

-- Users policies
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
            WHERE couple_id = couples.id
            AND id = auth.uid()
        )
    );

CREATE POLICY "Users can update own couple" ON couples
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = couples.id
            AND id = auth.uid()
        )
    );

CREATE POLICY "Users can create couples" ON couples
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL  -- Just check authenticated
    );

-- Invite codes policies
CREATE POLICY "Users can manage own invite codes" ON invite_codes
    FOR ALL USING (
        user_id = auth.uid() OR
        used_by = auth.uid()
    );

CREATE POLICY "Anyone can read valid invite codes" ON invite_codes
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND
        NOT used AND
        expires_at > NOW()
    );

-- Locations policies
CREATE POLICY "Users can read couple locations" ON locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = locations.couple_id
            AND id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own locations" ON locations
    FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update own locations" ON locations
    FOR UPDATE USING (owner_id = auth.uid());

-- =====================================================
-- STEP 5: Update helper functions
-- =====================================================

-- Drop old Firebase migration functions
DROP FUNCTION IF EXISTS migrate_firebase_user(TEXT, JSONB);
DROP FUNCTION IF EXISTS get_user_by_firebase_uid(TEXT);

-- =====================================================
-- VERIFICATION
-- =====================================================

-- List all policies to verify
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Verify no firebase_uid column exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users';
