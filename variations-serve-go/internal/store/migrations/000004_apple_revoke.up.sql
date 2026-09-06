-- 000004_apple_revoke：注销账号时撤销 Apple 授权（App Store Guideline 5.1.1(v)）
-- 登录时以 authorizationCode 换取的 refresh_token 必须可逆使用（撤销接口要原值，故不哈希）；
-- 仅存服务器本地 SQLite，注销时随个人信息一并清空。
ALTER TABLE users ADD COLUMN apple_refresh_token TEXT;
