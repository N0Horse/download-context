CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS captures (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  file_hash TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_path_at_capture TEXT NOT NULL,
  origin_title TEXT NOT NULL,
  origin_url TEXT NOT NULL,
  note TEXT,
  browser TEXT,
  source_app TEXT,
  mime_type TEXT
);

CREATE INDEX IF NOT EXISTS idx_captures_file_hash ON captures(file_hash);
CREATE INDEX IF NOT EXISTS idx_captures_created_at ON captures(created_at);
