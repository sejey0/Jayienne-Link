-- Create decision_ideas table for dynamic date & food options (PH Edition)
CREATE TABLE IF NOT EXISTS public.decision_ideas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL CHECK (category IN ('food', 'activity')),
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.decision_ideas ENABLE ROW LEVEL SECURITY;

-- Allow public read access to decision ideas
DROP POLICY IF EXISTS "Allow public read access to decision ideas" ON public.decision_ideas;
CREATE POLICY "Allow public read access to decision ideas"
    ON public.decision_ideas FOR SELECT
    USING (true);

-- Seed initial online decision ideas (Common Philippine Couple Choices)
INSERT INTO public.decision_ideas (category, title) VALUES
('food', 'Samgyupsal / Unlimited K-BBQ'),
('food', 'Jollibee Chickenjoy & Burgers'),
('food', 'Milk Tea & Boba'),
('food', 'Coffee Shop & Pastry Date'),
('food', 'Pares & Mami Night'),
('food', 'Sisig & Inasal Grill'),
('food', 'Lechon Manok & Liempo'),
('food', 'Ramen & Japanese Bento'),
('food', 'Pizza & Pasta'),
('food', 'Cook Sinigang or Adobo Together'),
('food', 'Street Food (Fishball, Kwek-Kwek, Isaw)'),
('food', 'Dessert, Ice Cream & Halo-Halo'),
('activity', 'Mall Strolling & Window Shopping'),
('activity', 'Cinema Movie Night & Popcorn'),
('activity', 'Videoke & Karaoke Singing Session'),
('activity', 'Sunset Walk at Baywalk or Park'),
('activity', 'Arcade Games & Basketball Shootout'),
('activity', 'Night Drive & Convenience Store Tambay'),
('activity', 'Park Picnic & Photo Shoot'),
('activity', 'Food Park & Night Market Trip'),
('activity', 'Co-op Mobile Gaming Session'),
('activity', 'Coffee Shop Chitchat & Board Games'),
('activity', 'Grocery Date & Supermarket Run'),
('activity', 'Bowling & Billiards Match')
ON CONFLICT DO NOTHING;
