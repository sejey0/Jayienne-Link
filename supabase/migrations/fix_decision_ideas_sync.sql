-- ==============================================================================
-- Migration: Fix Decision Ideas Table for Couple Custom Options & Spin Sync
-- ==============================================================================

-- 1. Ensure columns couple_id and is_custom exist
ALTER TABLE public.decision_ideas 
ADD COLUMN IF NOT EXISTS couple_id UUID REFERENCES public.couples(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS is_custom BOOLEAN DEFAULT true;

-- 2. Drop category constraint so active picks ('active_movie_pick', 'active_activity_pick', 'active_food_pick') can be saved
ALTER TABLE public.decision_ideas 
DROP CONSTRAINT IF EXISTS decision_ideas_category_check;

-- 3. Create index for fast couple_id querying
CREATE INDEX IF NOT EXISTS idx_decision_ideas_couple_id ON public.decision_ideas(couple_id);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.decision_ideas ENABLE ROW LEVEL SECURITY;

-- 5. Drop any old restrictive policies and create full access policy for couple members / authenticated users
DROP POLICY IF EXISTS "Allow public read access to decision ideas" ON public.decision_ideas;
DROP POLICY IF EXISTS "Allow all access to decision ideas" ON public.decision_ideas;
DROP POLICY IF EXISTS "Allow couple access to decision ideas" ON public.decision_ideas;

CREATE POLICY "Allow all access to decision ideas"
    ON public.decision_ideas FOR ALL
    USING (true)
    WITH CHECK (true);
