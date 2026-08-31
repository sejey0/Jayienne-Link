-- ============================================================================
-- Migration: Create couple_voice_notes table and storage bucket permissions
-- Description: Stores 10-second love voice notes with full Supabase storage RLS
-- ============================================================================

-- 1. Create Table
CREATE TABLE IF NOT EXISTS public.couple_voice_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    sender_name TEXT,
    sender_photo_url TEXT,
    audio_url TEXT NOT NULL,
    duration_seconds INTEGER NOT NULL DEFAULT 10,
    title TEXT,
    is_listened BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indices for rapid lookup by couple_id
CREATE INDEX IF NOT EXISTS idx_couple_voice_notes_couple_id 
    ON public.couple_voice_notes (couple_id, created_at DESC);

-- Enable Table Row Level Security (RLS)
ALTER TABLE public.couple_voice_notes ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to select, insert, and delete couple voice notes
DROP POLICY IF EXISTS "Allow authenticated access to couple_voice_notes" ON public.couple_voice_notes;
CREATE POLICY "Allow authenticated access to couple_voice_notes"
ON public.couple_voice_notes
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Also allow anon access if your project uses anon keys
DROP POLICY IF EXISTS "Allow anon access to couple_voice_notes" ON public.couple_voice_notes;
CREATE POLICY "Allow anon access to couple_voice_notes"
ON public.couple_voice_notes
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- 2. Storage Bucket Creation (public bucket with 50MB limit)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('voice-notes', 'voice-notes', true, 52428800, ARRAY['audio/m4a', 'audio/aac', 'audio/mp4', 'audio/wav', 'audio/mpeg', 'audio/*'])
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['audio/m4a', 'audio/aac', 'audio/mp4', 'audio/wav', 'audio/mpeg', 'audio/*'];

-- 3. Storage Policies on storage.objects for voice-notes bucket
DROP POLICY IF EXISTS "Public Access voice-notes" ON storage.objects;
CREATE POLICY "Public Access voice-notes"
ON storage.objects FOR SELECT
USING (bucket_id = 'voice-notes');

DROP POLICY IF EXISTS "Authenticated upload voice-notes" ON storage.objects;
CREATE POLICY "Authenticated upload voice-notes"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (bucket_id = 'voice-notes');

DROP POLICY IF EXISTS "Authenticated update voice-notes" ON storage.objects;
CREATE POLICY "Authenticated update voice-notes"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (bucket_id = 'voice-notes');

DROP POLICY IF EXISTS "Authenticated delete voice-notes" ON storage.objects;
CREATE POLICY "Authenticated delete voice-notes"
ON storage.objects FOR DELETE
TO authenticated, anon
USING (bucket_id = 'voice-notes');

-- 4. Enable Realtime replication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'couple_voice_notes'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.couple_voice_notes;
    END IF;
END $$;
