package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// ErrUserDeleted 账号已注销 → 403 ACCOUNT_DELETED
var ErrUserDeleted = errors.New("账号已注销")

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
// 已注销账号（deleted_at 非空）返回 ErrUserDeleted，不允许复活。
func (r *UserRepo) UpsertUser(ctx context.Context, id, email string, isPrivateEmail bool, fullName string) (*User, error) {
	now := utcNow()
	var deleted sql.NullString
	err := r.db.QueryRowContext(ctx, `SELECT deleted_at FROM users WHERE id = ?`, id).Scan(&deleted)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		if _, err := r.db.ExecContext(ctx,
			`INSERT INTO users (id, email, is_private_email, full_name, created_at, last_login_at)
			 VALUES (?, ?, ?, ?, ?, ?)`,
			id, email, boolInt(isPrivateEmail), fullName, now, now,
		); err != nil {
			return nil, fmt.Errorf("写入用户失败: %w", err)
		}
	case err != nil:
		return nil, fmt.Errorf("查询用户失败: %w", err)
	case deleted.Valid:
		return nil, ErrUserDeleted
	default:
		if _, err := r.db.ExecContext(ctx,
			`UPDATE users SET email = ?, is_private_email = ?, last_login_at = ?,
			 full_name = CASE WHEN full_name IS NULL OR full_name = '' THEN ? ELSE full_name END
			 WHERE id = ?`,
			email, boolInt(isPrivateEmail), now, fullName, id,
		); err != nil {
			return nil, fmt.Errorf("更新用户失败: %w", err)
		}
	}
	return &User{ID: id, Email: email, IsPrivateEmail: isPrivateEmail, FullName: fullName}, nil
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

// RevokeUserTokens 吊销该用户全部会话令牌（登录换发/注销时调用）
func (r *UserRepo) RevokeUserTokens(ctx context.Context, userID string) error {
	if _, err := r.db.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL`,
		utcNow(), userID); err != nil {
		return fmt.Errorf("吊销会话令牌失败: %w", err)
	}
	return nil
}

// RevokeToken 吊销单个令牌（退出登录）
func (r *UserRepo) RevokeToken(ctx context.Context, tokenHash string) error {
	if _, err := r.db.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL`,
		utcNow(), tokenHash); err != nil {
		return fmt.Errorf("吊销令牌失败: %w", err)
	}
	return nil
}

// DeleteUser 账号注销：软删用户 + 吊销其全部会话令牌（同一事务）
func (r *UserRepo) DeleteUser(ctx context.Context, userID string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer func() { _ = tx.Rollback() }()
	now := utcNow()
	if _, err := tx.ExecContext(ctx, `UPDATE users SET deleted_at = ? WHERE id = ?`, now, userID); err != nil {
		return fmt.Errorf("软删用户失败: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL`, now, userID); err != nil {
		return fmt.Errorf("吊销会话令牌失败: %w", err)
	}
	return tx.Commit()
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
