-- Migration number: 0002 photo sort
ALTER TABLE photos ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;
