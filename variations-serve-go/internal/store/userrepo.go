package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// User SIWA 用户档案（Apple sub 为主键）
type User struct {
	ID             string
	Email          string
	IsPrivateEmail bool
	FullName       string
}

// UserRepo 用户档案与会话令牌持久化（会话令牌复用 auth_tokens，user_id 列启用）
type UserRepo struct {
	db *sql.DB
}

func NewUserRepo(db *sql.DB) *UserRepo {
	return &UserRepo{db: db}
}

// UpsertUser 登录即注册：已存在则刷新邮箱/活跃时间；full_name 仅首次授权可得，空值不覆盖。
// 已注销账号以同一 Apple sub 再次登录时复活（清 deleted_at），但 created_at 保持首次注册时间——
// 特权窗口不随注销重开，杜绝「注销→重登」反复刷新用户特权；paid_remaining 一并留存（已购次数不没收）。
func (r *UserRepo) UpsertUser(ctx context.Context, id, email string, isPrivateEmail bool, fullName string) (*User, error) {
	now := utcNow()
	// 单语句原子 upsert：ON CONFLICT 不触碰 created_at，故复活不重置注册时间
	if _, err := r.db.ExecContext(ctx,
		`INSERT INTO users (id, email, is_private_email, full_name, created_at, last_login_at)
		 VALUES (?, ?, ?, ?, ?, ?)
		 ON CONFLICT(id) DO UPDATE SET
		   email = excluded.email,
		   is_private_email = excluded.is_private_email,
		   last_login_at = excluded.last_login_at,
		   deleted_at = NULL,
		   full_name = CASE WHEN users.full_name IS NULL OR users.full_name = ''
		                    THEN excluded.full_name ELSE users.full_name END`,
		id, email, boolInt(isPrivateEmail), fullName, now, now,
	); err != nil {
		return nil, fmt.Errorf("写入用户失败: %w", err)
	}
	// 回读权威行：full_name 可能是首次授权留下的历史值，用入参回填会让再次登录昵称丢失
	user, err := r.GetUser(ctx, id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, fmt.Errorf("用户 upsert 后回读为空: %s", id)
	}
	return user, nil
}

// GetUser 读取用户档案（不存在返回 nil, nil）
func (r *UserRepo) GetUser(ctx context.Context, id string) (*User, error) {
	var u User
	var email, name sql.NullString
	var priv int
	err := r.db.QueryRowContext(ctx,
		`SELECT id, email, is_private_email, full_name FROM users WHERE id = ?`, id,
	).Scan(&u.ID, &email, &priv, &name)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("查询用户失败: %w", err)
	}
	u.Email = email.String
	u.IsPrivateEmail = priv != 0
	u.FullName = name.String
	return &u, nil
}

// IssueSessionToken 签发用户会话令牌（token 仅存哈希；expires_at 由调用方给定 30 天）
func (r *UserRepo) IssueSessionToken(ctx context.Context, tokenHash, userID, expiresAt string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO auth_tokens (token_hash, device_id, user_id, created_at, expires_at)
		 VALUES (?, ?, ?, ?, ?)`,
		tokenHash, "", userID, utcNow(), expiresAt)
	if err != nil {
		return fmt.Errorf("写入会话令牌失败: %w", err)
	}
	return nil
}

// RevokeToken 吊销单个令牌（退出登录；只影响当前设备，其他设备保持在线）
func (r *UserRepo) RevokeToken(ctx context.Context, tokenHash string) error {
	if _, err := r.db.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL`,
		utcNow(), tokenHash); err != nil {
		return fmt.Errorf("吊销令牌失败: %w", err)
	}
	return nil
}

// DeleteUser 账号注销（Guideline 5.1.1(v)）：清除个人信息（邮箱/昵称/Apple refresh token）
// + 打注销标记 + 吊销全部会话令牌（同一事务）。
// 保留 id（Apple sub 为应用内定向标识，不含个人信息）、created_at 与 paid_remaining 作墓碑：
// 同一 Apple ID 重新登录可复活，特权窗口不重开、已购次数不丢失。
func (r *UserRepo) DeleteUser(ctx context.Context, userID string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	now := utcNow()
	if _, err := tx.ExecContext(ctx,
		`UPDATE users SET deleted_at = ?, email = NULL, full_name = NULL,
		 is_private_email = 0, apple_refresh_token = NULL WHERE id = ?`,
		now, userID); err != nil {
		return fmt.Errorf("清除用户个人信息失败: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL`, now, userID); err != nil {
		return fmt.Errorf("吊销会话令牌失败: %w", err)
	}
	return tx.Commit()
}

// ============================== Apple 授权撤销凭据 ==============================

// StoreAppleRefreshToken 落库登录时以 authorizationCode 换得的 refresh_token（注销时撤销授权用）
func (r *UserRepo) StoreAppleRefreshToken(ctx context.Context, userID, refreshToken string) error {
	if _, err := r.db.ExecContext(ctx,
		`UPDATE users SET apple_refresh_token = ? WHERE id = ?`, refreshToken, userID); err != nil {
		return fmt.Errorf("写入 Apple refresh token 失败: %w", err)
	}
	return nil
}

// AppleRefreshToken 读取 Apple refresh token（空 = 未换取或已随注销清除）
func (r *UserRepo) AppleRefreshToken(ctx context.Context, userID string) (string, error) {
	var token sql.NullString
	if err := r.db.QueryRowContext(ctx,
		`SELECT apple_refresh_token FROM users WHERE id = ?`, userID).Scan(&token); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", nil
		}
		return "", fmt.Errorf("查询 Apple refresh token 失败: %w", err)
	}
	return token.String, nil
}

// ============================== 购买余额（次数，永久不失效） ==============================

// PaidRemaining 已购剩余次数
func (r *UserRepo) PaidRemaining(ctx context.Context, userID string) (int, error) {
	var n int
	if err := r.db.QueryRowContext(ctx,
		`SELECT paid_remaining FROM users WHERE id = ?`, userID).Scan(&n); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, nil
		}
		return 0, fmt.Errorf("查询购买余额失败: %w", err)
	}
	return n, nil
}

// DeductPaid 原子扣 1 次已购余额；余额 0 → ErrQuotaExceeded
func (r *UserRepo) DeductPaid(ctx context.Context, userID string) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE users SET paid_remaining = paid_remaining - 1
		 WHERE id = ? AND paid_remaining > 0`, userID)
	if err != nil {
		return fmt.Errorf("扣减购买余额失败: %w", err)
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrQuotaExceeded
	}
	return nil
}

// RefundPaid 退还 1 次已购余额（仅失败路径调用）
func (r *UserRepo) RefundPaid(ctx context.Context, userID string) error {
	if _, err := r.db.ExecContext(ctx,
		`UPDATE users SET paid_remaining = paid_remaining + 1 WHERE id = ?`, userID); err != nil {
		return fmt.Errorf("退还购买余额失败: %w", err)
	}
	return nil
}

// CreditPurchase 幂等落账：transactionId 主键冲突视为重复票据，不重复加余额。
// 返回 (remaining, alreadyApplied)
func (r *UserRepo) CreditPurchase(ctx context.Context, transactionID, userID, productID string, quantity int) (int, bool, error) {
	if _, err := r.db.ExecContext(ctx,
		`INSERT INTO purchases (transaction_id, user_id, product_id, quantity) VALUES (?, ?, ?, ?)`,
		transactionID, userID, productID, quantity); err != nil {
		if isUniqueViolation(err) {
			remaining, rerr := r.PaidRemaining(ctx, userID)
			if rerr != nil {
				return 0, true, rerr
			}
			return remaining, true, nil
		}
		return 0, false, fmt.Errorf("落账票据失败: %w", err)
	}
	if _, err := r.db.ExecContext(ctx,
		`UPDATE users SET paid_remaining = paid_remaining + ? WHERE id = ?`, quantity, userID); err != nil {
		return 0, false, fmt.Errorf("加购买余额失败: %w", err)
	}
	remaining, err := r.PaidRemaining(ctx, userID)
	if err != nil {
		return 0, false, err
	}
	return remaining, false, nil
}

// CreatedAt 用户注册时间（特权窗口起点；不存在返回零值）
func (r *UserRepo) CreatedAt(ctx context.Context, userID string) (time.Time, error) {
	var raw sql.NullString
	if err := r.db.QueryRowContext(ctx,
		`SELECT created_at FROM users WHERE id = ?`, userID).Scan(&raw); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return time.Time{}, nil
		}
		return time.Time{}, fmt.Errorf("查询注册时间失败: %w", err)
	}
	if !raw.Valid {
		return time.Time{}, nil
	}
	t, err := time.Parse(time.RFC3339, raw.String)
	if err != nil {
		return time.Time{}, nil
	}
	return t, nil
}

// isUniqueViolation SQLite UNIQUE 冲突判定（modernc 驱动错误文本含 UNIQUE constraint failed）
func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "UNIQUE constraint failed")
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
