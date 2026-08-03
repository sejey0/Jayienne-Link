-- Trigger function to automatically keep couples.partner_names in sync when a user updates display_name
CREATE OR REPLACE FUNCTION update_couple_partner_names()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.display_name IS DISTINCT FROM OLD.display_name AND NEW.couple_id IS NOT NULL THEN
        UPDATE couples
        SET partner_names = ARRAY(
            SELECT u.display_name
            FROM unnest(partner_ids) WITH ORDINALITY AS p(partner_id, ord)
            JOIN users u ON u.id = partner_id
            ORDER BY ord
        ),
        updated_at = NOW()
        WHERE id = NEW.couple_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_couple_partner_names ON users;
CREATE TRIGGER trg_update_couple_partner_names
AFTER UPDATE OF display_name ON users
FOR EACH ROW
EXECUTE FUNCTION update_couple_partner_names();
