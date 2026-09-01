-- 000001_init：设备身份令牌鉴权体系 + generations 骨架
CREATE TABLE devices (
  id TEXT PRIMARY KEY,                -- 客户端生成的稳定 UUID
  name TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_seen_at TEXT,
  revoked_at TEXT
);
CREATE TABLE auth_tokens (
  token_hash TEXT PRIMARY KEY,        -- SHA-256 hex，永不存明文
  device_id TEXT NOT NULL REFERENCES devices(id),
  user_id TEXT,                       -- 用户系统预留扩展位，当前恒 NULL
  label TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_used_at TEXT,
  expires_at TEXT,                    -- NULL = 长期有效
  revoked_at TEXT
);
CREATE INDEX idx_auth_tokens_device ON auth_tokens (device_id);
CREATE INDEX idx_devices_last_seen ON devices (last_seen_at);
-- generations 占位表（骨架保留，端点未接入）
CREATE TABLE generations (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('compile','image','upload')),
  device_id TEXT, provider TEXT, model TEXT, skill_id TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  detail TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX idx_generations_created_at ON generations (created_at);
