-- Jayienne Link - Secret Media Feature Schema
-- Execute this script in Supabase SQL Editor to create the secret_media table

-- Create the secret_media table
CREATE TABLE IF NOT EXISTS secret_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
  uploaded_by_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('image', 'video')),
  media_url TEXT NOT NULL,
  thumbnail TEXT,
  caption TEXT,
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_encrypted BOOLEAN DEFAULT TRUE,
  is_hidden BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure deleted_at exists for existing tables
ALTER TABLE secret_media ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_secret_media_couple_id ON secret_media(couple_id);
CREATE INDEX IF NOT EXISTS idx_secret_media_uploaded_by_id ON secret_media(uploaded_by_id);
CREATE INDEX IF NOT EXISTS idx_secret_media_is_hidden ON secret_media(is_hidden);
CREATE INDEX IF NOT EXISTS idx_secret_media_couple_hidden ON secret_media(couple_id, is_hidden);
CREATE INDEX IF NOT EXISTS idx_secret_media_uploaded_at ON secret_media(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_secret_media_deleted_at ON secret_media(deleted_at);

-- Enable Row Level Security (RLS)
ALTER TABLE secret_media ENABLE ROW LEVEL SECURITY;

-- Re-runnable policy cleanup
DROP POLICY IF EXISTS "Users can view their couple's media" ON secret_media;
DROP POLICY IF EXISTS "Users can insert media for their couple" ON secret_media;
DROP POLICY IF EXISTS "Users can update their own media" ON secret_media;
DROP POLICY IF EXISTS "Users can delete their own media" ON secret_media;

-- RLS Policy: Users can only see media from their couple
CREATE POLICY "Users can view their couple's media" ON secret_media
  FOR SELECT
  USING (
    couple_id IN (
      SELECT id FROM couples 
      WHERE auth.uid() = ANY(partner_ids)
    )
  );

-- RLS Policy: Users can only insert media for their couple
CREATE POLICY "Users can insert media for their couple" ON secret_media
  FOR INSERT
  WITH CHECK (
    couple_id IN (
      SELECT id FROM couples 
      WHERE auth.uid() = ANY(partner_ids)
    )
    AND uploaded_by_id = auth.uid()
  );

-- RLS Policy: Users can update media in their couple's vault
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

-- RLS Policy: Users can delete media in their couple's vault
DROP POLICY IF EXISTS "Users can delete their own media" ON secret_media;
DROP POLICY IF EXISTS "Users can delete their couple's media" ON secret_media;
CREATE POLICY "Users can delete their couple's media" ON secret_media
  FOR DELETE
  USING (
    couple_id IN (
      SELECT id FROM couples 
      WHERE auth.uid() = ANY(partner_ids)
    )
  );

-- Create trigger to update the updated_at column
CREATE OR REPLACE FUNCTION update_secret_media_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS secret_media_updated_at_trigger ON secret_media;

-- Create trigger
CREATE TRIGGER secret_media_updated_at_trigger
  BEFORE UPDATE ON secret_media
  FOR EACH ROW
  EXECUTE FUNCTION update_secret_media_updated_at();

-- Create storage bucket for secret media (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('secret-media', 'secret-media', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for secret-media bucket (re-runnable)
DROP POLICY IF EXISTS "Secret media upload own folder" ON storage.objects;
DROP POLICY IF EXISTS "Secret media read own folder" ON storage.objects;
DROP POLICY IF EXISTS "Secret media update own folder" ON storage.objects;
DROP POLICY IF EXISTS "Secret media delete own folder" ON storage.objects;

CREATE POLICY "Secret media upload own folder" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'secret-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Secret media read own folder" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'secret-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Secret media update own folder" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'secret-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'secret-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Secret media delete own folder" ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'secret-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Grant permissions
GRANT ALL ON secret_media TO authenticated;
GRANT SELECT ON secret_media TO authenticated;

-- Function to safely restore a soft-deleted secret media without modifying is_hidden
CREATE OR REPLACE FUNCTION restore_secret_media(target_id UUID)
RETURNS SETOF secret_media
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  UPDATE secret_media
  SET deleted_at = NULL,
      updated_at = NOW()
  WHERE id = target_id
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION restore_secret_media(UUID) TO authenticated;

-- Function to safely restore all hidden vault media for a couple (bypasses RLS to restore partner uploads)
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

