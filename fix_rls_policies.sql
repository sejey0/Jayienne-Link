-- Fix RLS Policies to handle firebase_uid vs UUID mismatch
-- Run this migration in your Supabase SQL Editor

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can read own couple" ON couples;
DROP POLICY IF EXISTS "Users can update own couple" ON couples;
DROP POLICY IF EXISTS "Users can manage own invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Anyone can read valid invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Users can read couple locations" ON locations;
DROP POLICY IF EXISTS "Users can insert own locations" ON locations;
DROP POLICY IF EXISTS "Users can update own locations" ON locations;

-- =====================================================
-- UPDATED USERS POLICIES
-- =====================================================

-- Users can read their own profile (check both id and firebase_uid)
CREATE POLICY "Users can read own profile" ON users
    FOR SELECT USING (
        auth.uid()::text = firebase_uid OR
        auth.uid()::uuid = id
    );

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (
        auth.uid()::text = firebase_uid OR
        auth.uid()::uuid = id
    );

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (
        auth.uid()::text = firebase_uid OR
        auth.uid()::uuid = id
    );

-- =====================================================
-- UPDATED COUPLES POLICIES
-- =====================================================

-- Users can read their own couple
CREATE POLICY "Users can read own couple" ON couples
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = couples.id
            AND (firebase_uid = auth.uid()::text OR id = auth.uid()::uuid)
        )
    );

-- Users can update their own couple
CREATE POLICY "Users can update own couple" ON couples
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = couples.id
            AND (firebase_uid = auth.uid()::text OR id = auth.uid()::uuid)
        )
    );

-- Users can insert couples (needed for create_couple function)
CREATE POLICY "Users can create couples" ON couples
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL  -- Just check authenticated
    );

-- =====================================================
-- UPDATED INVITE_CODES POLICIES
-- =====================================================

-- Users can manage their own invite codes
CREATE POLICY "Users can manage own invite codes" ON invite_codes
    FOR ALL USING (
        -- User owns the invite code
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = invite_codes.user_id
            AND (users.firebase_uid = auth.uid()::text OR users.id = auth.uid()::uuid)
        ) OR
        -- User used the invite code
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = invite_codes.used_by
            AND (users.firebase_uid = auth.uid()::text OR users.id = auth.uid()::uuid)
        )
    );

-- Anyone authenticated can read valid invite codes (for redeeming)
CREATE POLICY "Anyone can read valid invite codes" ON invite_codes
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND
        NOT used AND
        expires_at > NOW()
    );

-- =====================================================
-- UPDATED LOCATIONS POLICIES
-- =====================================================

-- Users can read couple locations
CREATE POLICY "Users can read couple locations" ON locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE couple_id = locations.couple_id
            AND (firebase_uid = auth.uid()::text OR id = auth.uid()::uuid)
        )
    );

-- Users can insert their own locations
CREATE POLICY "Users can insert own locations" ON locations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = locations.owner_id
            AND (firebase_uid = auth.uid()::text OR id = auth.uid()::uuid)
        )
    );

-- Users can update their own locations
CREATE POLICY "Users can update own locations" ON locations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = locations.owner_id
            AND (firebase_uid = auth.uid()::text OR id = auth.uid()::uuid)
        )
    );

-- =====================================================
-- VERIFICATION
-- =====================================================

-- List all policies to verify
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
