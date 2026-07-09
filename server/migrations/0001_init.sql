-- Migration number: 0001    init schema
CREATE TABLE locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    parent_id INTEGER REFERENCES locations(id) ON DELETE SET NULL,
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE labels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    color TEXT
);

CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    location_id INTEGER REFERENCES locations(id) ON DELETE SET NULL,
    serial_number TEXT,
    purchase_price REAL,
    purchase_date TEXT,          -- ISO 8601 date
    purchased_from TEXT,
    warranty_until TEXT,         -- ISO 8601 date
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE item_labels (
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    label_id INTEGER NOT NULL REFERENCES labels(id) ON DELETE CASCADE,
    PRIMARY KEY (item_id, label_id)
);

CREATE TABLE photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    r2_key TEXT NOT NULL UNIQUE,
    content_type TEXT NOT NULL,
    size INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE maintenance_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    notes TEXT,
    interval_days INTEGER NOT NULL CHECK (interval_days > 0),
    next_due_date TEXT NOT NULL,  -- ISO 8601 date
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE maintenance_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schedule_id INTEGER NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
    completed_at TEXT NOT NULL,   -- ISO 8601 date
    notes TEXT,
    cost REAL
);

CREATE INDEX idx_items_location ON items(location_id);
CREATE INDEX idx_items_name ON items(name);
CREATE INDEX idx_item_labels_label ON item_labels(label_id);
CREATE INDEX idx_photos_item ON photos(item_id);
CREATE INDEX idx_schedules_item ON maintenance_schedules(item_id);
CREATE INDEX idx_schedules_due ON maintenance_schedules(next_due_date);
CREATE INDEX idx_logs_schedule ON maintenance_logs(schedule_id);
