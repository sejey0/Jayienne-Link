-- Migration: Fix Secret Media Restore & Soft-Delete Performance
-- Run this script in the Supabase SQL Editor

-- 1. Ensure deleted_at column and indexes exist
ALTER TABLE secret_media ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX IF NOT EXISTS idx_secret_media_deleted_at ON secret_media(deleted_at);
CREATE INDEX IF NOT EXISTS idx_secret_media_couple_deleted ON secret_media(couple_id, deleted_at);

-- 2. Allow both partners in a couple to update media (needed for soft delete and in-app restore)
DROP POLICY IF EXISTS "Users can update their own media" ON secret_media;
DROP POLICY IF EXISTS "Users can update their couple's media" ON secret_media;
CREATE POLICY "Users can update their couple's media" ON secret_media
  FOR UPDATE
  USING (
    couple_id IN (
      SELECT id FROM couples 
      WHERE auth.uid() = ANY(partner_ids)
    )
  )
  WITH CHECK (
    couple_id IN (
      SELECT id FROM couples 
      WHERE auth.uid() = ANY(partner_ids)
    )
  );

-- 3. Fast Bulk Restore Function (Admin Dashboard "Sync & Restore Vault")
CREATE OR REPLACE FUNCTION restore_all_hidden_vault_media(target_couple_id UUID DEFAULT NULL)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  restored_count INT;
BEGIN
  IF target_couple_id IS NOT NULL THEN
    UPDATE secret_media
    SET deleted_at = NULL,
        is_hidden = TRUE,
        updated_at = NOW()
    WHERE couple_id = target_couple_id
      AND deleted_at IS NOT NULL;
  ELSE
    UPDATE secret_media
    SET deleted_at = NULL,
        is_hidden = TRUE,
        updated_at = NOW()
    WHERE deleted_at IS NOT NULL;
  END IF;

  GET DIAGNOSTICS restored_count = ROW_COUNT;
  RETURN restored_count;
END;
$$;

GRANT EXECUTE ON FUNCTION restore_all_hidden_vault_media(UUID) TO authenticated;
