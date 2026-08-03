-- Migration script for Jayienne Link Admin Features & Row Level Security (RLS)
-- Run this complete script in your Supabase SQL Editor to fix RLS infinite recursion

-- 1. Add role and is_active columns to users table if they don't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. Create indexes on role and is_active for faster administrative queries
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- 3. Create Security Definer helper function to avoid infinite recursion in RLS policies
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Clean up any existing broken policies
DROP POLICY IF EXISTS "Admins can read all users" ON users;
DROP POLICY IF EXISTS "Admins can update all users" ON users;

-- 5. Row Level Security (RLS) Policies for Admin Users (using is_admin() helper)
CREATE POLICY "Admins can read all users" ON users
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Admins can update all users" ON users
    FOR UPDATE USING (public.is_admin());

-- 6. Helper: SQL query to promote an existing user to admin
-- Replace 'your_email@example.com' with the email of your user account:
-- UPDATE users SET role = 'admin' WHERE email = 'your_email@example.com';
