-- Migration script for Jayienne Link Admin Features & Universal Account Activation/Deactivation
-- Run this complete script in your Supabase SQL Editor.
-- This guarantees account deactivation/activation applies immediately across ALL APK versions and sessions.

-- 1. Ensure role and is_active columns exist
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. Indexes for fast administrative queries
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);

-- 3. Security Definer helper function to check admin rights
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Clean up any existing policies
DROP POLICY IF EXISTS "Admins can read all users" ON public.users;
DROP POLICY IF EXISTS "Admins can update all users" ON public.users;

-- 5. Row Level Security (RLS) Policies for Admin Users
CREATE POLICY "Admins can read all users" ON public.users
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Admins can update all users" ON public.users
    FOR UPDATE USING (public.is_admin());

-- 6. Universal Auth Ban Synchronization Trigger
-- When is_active is set to FALSE, bans the user in auth.users immediately.
-- This forces Supabase Auth to reject all API/storage requests and terminate sessions across ALL APK versions.
CREATE OR REPLACE FUNCTION public.sync_user_active_status_to_auth()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = FALSE THEN
    -- Block all sessions & JWT auth requests instantly across any APK version
    UPDATE auth.users
    SET banned_until = '2999-12-31 23:59:59+00'::timestamptz
    WHERE id = NEW.id;
  ELSIF NEW.is_active = TRUE AND (OLD.is_active = FALSE OR OLD.is_active IS NULL) THEN
    -- Restore access immediately
    UPDATE auth.users
    SET banned_until = NULL
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_user_active_status ON public.users;
CREATE TRIGGER trigger_sync_user_active_status
  AFTER UPDATE OF is_active ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_user_active_status_to_auth();

-- 7. Atomic RPC Function to set user active status
CREATE OR REPLACE FUNCTION public.set_user_active_status(target_uid UUID, is_active BOOLEAN)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 1. Update public.users
  UPDATE public.users
  SET is_active = set_user_active_status.is_active,
      updated_at = NOW()
  WHERE id = target_uid;

  -- 2. Update auth.users ban status
  IF is_active = FALSE THEN
    UPDATE auth.users
    SET banned_until = '2999-12-31 23:59:59+00'::timestamptz
    WHERE id = target_uid;
  ELSE
    UPDATE auth.users
    SET banned_until = NULL
    WHERE id = target_uid;
  END IF;

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_active_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
