-- =============================================================================
-- JAYIENNE LINK: ANNIVERSARY & RELATIONSHIP MILESTONES MIGRATION SCRIPT
-- Executes schema creation, RLS security policies, storage buckets, and stats RPC
-- =============================================================================

-- 1. CREATE RELATIONSHIP MILESTONES TABLE
CREATE TABLE IF NOT EXISTS public.relationship_milestones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    event_date TIMESTAMPTZ NOT NULL,
    category TEXT NOT NULL DEFAULT 'special_moment',
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Backward compatibility view alias for 'milestones' table reference
CREATE OR REPLACE VIEW public.milestones AS 
SELECT 
    id,
    couple_id,
    created_by AS created_by_id,
    title,
    description,
    event_date,
    category,
    photo_url,
    created_at
FROM public.relationship_milestones;

-- Add performance indexes for rapid timeline loading and date filtering
CREATE INDEX IF NOT EXISTS idx_milestones_couple_id ON public.relationship_milestones(couple_id);
CREATE INDEX IF NOT EXISTS idx_milestones_event_date ON public.relationship_milestones(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_milestones_created_by ON public.relationship_milestones(created_by);

-- =============================================================================
-- 2. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

ALTER TABLE public.relationship_milestones ENABLE ROW LEVEL SECURITY;

-- Helper function to check if current auth.uid() belongs to a given couple_id
CREATE OR REPLACE FUNCTION public.is_couple_member(p_couple_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.couples c
        WHERE c.id = p_couple_id
        AND (
            auth.uid() = ANY(c.partner_ids)
            OR auth.uid() = c.partner_1_id
            OR auth.uid() = c.partner_2_id
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policy 1: SELECT (View Milestones)
CREATE POLICY "Couples can view their relationship milestones" 
ON public.relationship_milestones
FOR SELECT 
USING (public.is_couple_member(couple_id));

-- RLS Policy 2: INSERT (Add Milestones)
CREATE POLICY "Couples can insert relationship milestones" 
ON public.relationship_milestones
FOR INSERT 
WITH CHECK (
    public.is_couple_member(couple_id) 
    AND auth.uid() = created_by
);

-- RLS Policy 3: UPDATE (Edit Milestones)
CREATE POLICY "Couples can update their relationship milestones" 
ON public.relationship_milestones
FOR UPDATE 
USING (public.is_couple_member(couple_id))
WITH CHECK (public.is_couple_member(couple_id));

-- RLS Policy 4: DELETE (Remove Milestones)
CREATE POLICY "Couples can delete their relationship milestones" 
ON public.relationship_milestones
FOR DELETE 
USING (public.is_couple_member(couple_id));

-- =============================================================================
-- 3. SUPABASE STORAGE BUCKET setup ('milestones')
-- =============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('milestones', 'milestones', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policy 1: SELECT (View Milestone Photos)
CREATE POLICY "Public Read Access for Milestone Photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'milestones');

-- Storage RLS Policy 2: INSERT (Upload Milestone Photos)
CREATE POLICY "Authenticated Users Upload Milestone Photos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'milestones' 
    AND auth.role() = 'authenticated'
);

-- Storage RLS Policy 3: UPDATE (Replace Milestone Photos)
CREATE POLICY "Authenticated Users Update Milestone Photos"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'milestones' 
    AND auth.role() = 'authenticated'
);

-- Storage RLS Policy 4: DELETE (Remove Milestone Photos)
CREATE POLICY "Authenticated Users Delete Milestone Photos"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'milestones' 
    AND auth.role() = 'authenticated'
);

-- =============================================================================
-- 4. STATS AGGREGATION FUNCTION (RPC)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_couple_stats(p_couple_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_heartbeats_count INT := 0;
    v_photos_count INT := 0;
    v_milestones_count INT := 0;
    v_result JSONB;
BEGIN
    -- Verify member authorization
    IF NOT public.is_couple_member(p_couple_id) THEN
        RAISE EXCEPTION 'Access Denied: User is not a member of this couple.';
    END IF;

    -- Count total heartbeats
    SELECT COUNT(*) INTO v_heartbeats_count
    FROM public.heartbeats
    WHERE couple_id = p_couple_id;

    -- Count total photos shared
    SELECT COUNT(*) INTO v_photos_count
    FROM public.photo_messages
    WHERE couple_id = p_couple_id;

    -- Count total relationship milestones
    SELECT COUNT(*) INTO v_milestones_count
    FROM public.relationship_milestones
    WHERE couple_id = p_couple_id;

    -- Construct JSON response payload
    v_result := jsonb_build_object(
        'total_heartbeats', COALESCE(v_heartbeats_count, 0),
        'total_photos', COALESCE(v_photos_count, 0),
        'total_milestones', COALESCE(v_milestones_count, 0)
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions on RPC function to authenticated users
GRANT EXECUTE ON FUNCTION public.get_couple_stats(UUID) TO authenticated;
