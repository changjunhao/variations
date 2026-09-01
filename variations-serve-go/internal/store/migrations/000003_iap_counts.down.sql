UPDATE daily_quotas SET used = used * 10 WHERE principal NOT LIKE '%:compile';
DROP INDEX idx_purchases_user;
DROP TABLE purchases;
ALTER TABLE users DROP COLUMN paid_remaining;
