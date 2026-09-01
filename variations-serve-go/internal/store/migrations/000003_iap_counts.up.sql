-- 000003_iap_counts：积分包 IAP + 配额次数化
-- 购买余额挂用户行（永久不失效）；purchases 以 StoreKit transactionId 幂等落账
ALTER TABLE users ADD COLUMN paid_remaining INTEGER NOT NULL DEFAULT 0;

CREATE TABLE purchases (
  transaction_id TEXT PRIMARY KEY,   -- StoreKit transactionId，幂等键
  user_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,         -- 落账次数
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX idx_purchases_user ON purchases (user_id);

-- 积分 → 次数数据修正：旧行 used 以积分计（10 积分 = 1 次）；:compile 行 cost=1 不动
UPDATE daily_quotas SET used = used / 10 WHERE principal NOT LIKE '%:compile';
