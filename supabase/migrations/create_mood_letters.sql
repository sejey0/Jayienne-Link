-- ============================================================================
-- Migration: Create letters table and open_letter atomic stored procedure
-- Description: Supports Mood Letters ("Open When...") 2-inbox architecture
-- ============================================================================

-- 1. Create Letters Table
CREATE TABLE IF NOT EXISTS public.letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'UNREAD' CHECK (status IN ('UNREAD', 'READ')),
    read_count INTEGER NOT NULL DEFAULT 0 CHECK (read_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    first_read_at TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ
);

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_letters_couple_id 
    ON public.letters (couple_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_letters_receiver_inbox 
    ON public.letters (receiver_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_letters_sender_inbox 
    ON public.letters (sender_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_letters_category 
    ON public.letters (receiver_id, category);

-- 3. Row Level Security (RLS)
ALTER TABLE public.letters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated access to letters" ON public.letters;
CREATE POLICY "Allow authenticated access to letters"
ON public.letters
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon access to letters" ON public.letters;
CREATE POLICY "Allow anon access to letters"
ON public.letters
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- 4. Enable Supabase Realtime for letters table
ALTER PUBLICATION supabase_realtime ADD TABLE public.letters;

-- 5. Atomic open_letter RPC Function
-- Handles status transition, timestamp recording, atomic counter increment,
-- and debounce enforcement (default 30s) to prevent spam increments.
CREATE OR REPLACE FUNCTION public.open_letter(
    p_letter_id UUID,
    p_user_id UUID,
    p_cooldown_seconds INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_letter RECORD;
    v_is_first_open BOOLEAN := FALSE;
    v_now TIMESTAMPTZ := NOW();
    v_sender_fcm_token TEXT;
    v_receiver_name TEXT;
    v_new_read_count INT;
BEGIN
    -- Lock letter row for update
    SELECT * INTO v_letter
    FROM public.letters
    WHERE id = p_letter_id AND receiver_id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Letter not found or unauthorized access.';
    END IF;

    -- Prevent duplicate rapid increments (Debounce Cooldown)
    IF v_letter.last_read_at IS NOT NULL 
       AND (EXTRACT(EPOCH FROM (v_now - v_letter.last_read_at)) < p_cooldown_seconds) THEN
        RETURN jsonb_build_object(
            'success', true,
            'debounced', true,
            'read_count', v_letter.read_count,
            'is_first_open', false
        );
    END IF;

    -- Check if first-time open
    IF v_letter.status = 'UNREAD' THEN
        v_is_first_open := TRUE;
        v_new_read_count := v_letter.read_count + 1;
        
        UPDATE public.letters
        SET status = 'READ',
            read_count = v_new_read_count,
            first_read_at = v_now,
            last_read_at = v_now
        WHERE id = p_letter_id;
    ELSE
        v_new_read_count := v_letter.read_count + 1;
        
        UPDATE public.letters
        SET read_count = v_new_read_count,
            last_read_at = v_now
        WHERE id = p_letter_id;
    END IF;

    -- Gather payload details for push notification if first-time open
    IF v_is_first_open THEN
        SELECT u.display_name INTO v_receiver_name FROM public.users u WHERE u.id = p_user_id;
        SELECT u.email INTO v_sender_fcm_token FROM public.users u WHERE u.id = v_letter.sender_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'debounced', false,
        'read_count', v_new_read_count,
        'is_first_open', v_is_first_open,
        'letter_title', v_letter.title,
        'sender_id', v_letter.sender_id,
        'receiver_name', COALESCE(v_receiver_name, 'Your partner'),
        'sender_fcm_token', v_sender_fcm_token
    );
END;
$$;
