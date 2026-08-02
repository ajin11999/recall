-- Migration number: 0004    consumables and wishlist
ALTER TABLE items ADD COLUMN is_consumable INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN min_quantity INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN is_wishlist INTEGER NOT NULL DEFAULT 0;

CREATE INDEX idx_items_consumable ON items(is_consumable);
CREATE INDEX idx_items_wishlist ON items(is_wishlist);
