-- =============================================================================
-- JAYIENNE LINK: COUPLE LINKS & SOCIAL PROFILES MIGRATION SCRIPT
-- Creates couple_links table with RLS security policies & performance indexes
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.couple_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES public.couples(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_display_name TEXT,
    user_photo_url TEXT,
    platform TEXT NOT NULL DEFAULT 'website',
    title TEXT NOT NULL DEFAULT '',
    username TEXT NOT NULL DEFAULT '',
    url TEXT NOT NULL DEFAULT '',
    icon_key TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_couple_links_couple_id ON public.couple_links(couple_id);
CREATE INDEX IF NOT EXISTS idx_couple_links_user_id ON public.couple_links(user_id);
CREATE INDEX IF NOT EXISTS idx_couple_links_created_at ON public.couple_links(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.couple_links ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid duplicate errors
DROP POLICY IF EXISTS "Couple members can select links" ON public.couple_links;
DROP POLICY IF EXISTS "Couple members can insert links" ON public.couple_links;
DROP POLICY IF EXISTS "Couple members can update links" ON public.couple_links;
DROP POLICY IF EXISTS "Couple members can delete links" ON public.couple_links;

-- 1. SELECT: Both partners in the couple can view their shared links
CREATE POLICY "Couple members can select links"
ON public.couple_links
FOR SELECT
TO authenticated
USING (
    couple_id IN (
        SELECT id FROM public.couples
        WHERE auth.uid() = ANY(partner_ids)
    )
);

-- 2. INSERT: A partner can add links to their couple
CREATE POLICY "Couple members can insert links"
ON public.couple_links
FOR INSERT
TO authenticated
WITH CHECK (
    couple_id IN (
        SELECT id FROM public.couples
        WHERE auth.uid() = ANY(partner_ids)
    )
);

-- 3. UPDATE: Users can update links in their couple
CREATE POLICY "Couple members can update links"
ON public.couple_links
FOR UPDATE
TO authenticated
USING (
    couple_id IN (
        SELECT id FROM public.couples
        WHERE auth.uid() = ANY(partner_ids)
    )
)
WITH CHECK (
    couple_id IN (
        SELECT id FROM public.couples
        WHERE auth.uid() = ANY(partner_ids)
    )
);

-- 4. DELETE: Users can delete links in their couple
CREATE POLICY "Couple members can delete links"
ON public.couple_links
FOR DELETE
TO authenticated
USING (
    couple_id IN (
        SELECT id FROM public.couples
        WHERE auth.uid() = ANY(partner_ids)
    )
);
