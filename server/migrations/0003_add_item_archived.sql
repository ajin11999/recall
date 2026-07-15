-- Migration number: 0003    add item archived
ALTER TABLE items ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_items_archived ON items(is_archived);
