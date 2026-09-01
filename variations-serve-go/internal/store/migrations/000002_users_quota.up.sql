-- 000002_users_quota：SIWA 用户系统 + 每日积分配额
-- 会话令牌复用 auth_tokens：user_id 填 Apple sub，device_id 用空串哨兵（FK pragma 未启用）；
-- ValidateToken 以 LEFT JOIN 兼容两类主体。
CREATE TABLE users (
  id TEXT PRIMARY KEY,                -- Apple sub（稳定用户标识，直接作主键）
  email TEXT,
  is_private_email INTEGER NOT NULL DEFAULT 0,
  full_name TEXT,                     -- 仅首次授权可得，可能为空
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  last_login_at TEXT,
  deleted_at TEXT                     -- 账号注销软删（审计保留）
);
CREATE INDEX idx_users_deleted ON users (deleted_at);

CREATE TABLE daily_quotas (
  principal TEXT NOT NULL,            -- 'device:'||device_id / 'user:'||user_id；防刷上限追加 ':compile' 后缀
  day TEXT NOT NULL,                  -- Asia/Shanghai 日期串 'YYYY-MM-DD'（日串变化即天然重置）
  used INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (principal, day)
);
