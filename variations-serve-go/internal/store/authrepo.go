package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// AuthRepo 设备与令牌的持久化（token 永不存明文，仅 SHA-256 哈希）
type AuthRepo struct {
	db *sql.DB
}

func NewAuthRepo(db *sql.DB) *AuthRepo {
	return &AuthRepo{db: db}
}

var ErrTokenInvalid = errors.New("token 不存在或已失效")

// TokenKind 令牌主体类型：设备（游客）/ 用户（SIWA 会话）
type TokenKind string

const (
	KindDevice TokenKind = "device"
	KindUser   TokenKind = "user"
)

// TokenInfo 鉴权通过后的主体信息（principal 由调用方按 kind 拼装）
type TokenInfo struct {
	Kind          TokenKind
	DeviceID      string // kind=device 时非空
	UserID        string // kind=user 时非空
	UserCreatedAt string // kind=user 时用户注册时间（RFC3339，特权窗口判定）
}

// RegisterDevice 幂等设备注册：同 deviceId 再注册时吊销旧 token，签发新 token。
// 返回新 token 的哈希（明文由调用方持有并一次性下发）。
func (r *AuthRepo) RegisterDevice(ctx context.Context, deviceID, deviceName, tokenHash string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("开启事务失败: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	now := utcNow()
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO devices (id, name, created_at, last_seen_at) VALUES (?, ?, ?, ?)
		 ON CONFLICT(id) DO UPDATE SET name = excluded.name, last_seen_at = excluded.last_seen_at`,
		deviceID, deviceName, now, now,
	); err != nil {
		return fmt.Errorf("写入设备失败: %w", err)
	}
	// 吊销该设备全部旧 token（软删，保留审计链）
	if _, err := tx.ExecContext(ctx,
		`UPDATE auth_tokens SET revoked_at = ? WHERE device_id = ? AND revoked_at IS NULL`,
		now, deviceID,
	); err != nil {
		return fmt.Errorf("吊销旧 token 失败: %w", err)
	}
	if _, err := tx.ExecContext(ctx,
		`INSERT INTO auth_tokens (token_hash, device_id, created_at) VALUES (?, ?, ?)`,
		tokenHash, deviceID, now,
	); err != nil {
		return fmt.Errorf("写入 token 失败: %w", err)
	}
	return tx.Commit()
}

// ValidateToken 按哈希校验 token：存在、未吊销、未过期、所属设备/用户未吊销注销。
// LEFT JOIN 兼容两类主体：用户会话令牌 device_id 为空串哨兵，设备令牌 user_id 为 NULL。
func (r *AuthRepo) ValidateToken(ctx context.Context, tokenHash string) (TokenInfo, error) {
	var deviceID string
	var userID sql.NullString
	var deviceRevoked sql.NullString
	var userDeleted sql.NullString
	var userCreatedAt sql.NullString
	var expiresAt sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT t.device_id, t.user_id, d.revoked_at, u.deleted_at, u.created_at, t.expires_at
		 FROM auth_tokens t
		 LEFT JOIN devices d ON d.id = t.device_id
		 LEFT JOIN users u ON u.id = t.user_id
		 WHERE t.token_hash = ? AND t.revoked_at IS NULL`,
		tokenHash,
	).Scan(&deviceID, &userID, &deviceRevoked, &userDeleted, &userCreatedAt, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return TokenInfo{}, ErrTokenInvalid
	}
	if err != nil {
		return TokenInfo{}, fmt.Errorf("查询 token 失败: %w", err)
	}
	if expiresAt.Valid {
		if t, perr := time.Parse(time.RFC3339, expiresAt.String); perr == nil && time.Now().After(t) {
			return TokenInfo{}, ErrTokenInvalid
		}
	}
	if userID.Valid {
		if userDeleted.Valid {
			return TokenInfo{}, ErrTokenInvalid
		}
		return TokenInfo{Kind: KindUser, UserID: userID.String, UserCreatedAt: userCreatedAt.String}, nil
	}
	if deviceRevoked.Valid {
		return TokenInfo{}, ErrTokenInvalid
	}
	return TokenInfo{Kind: KindDevice, DeviceID: deviceID}, nil
}

// TouchLastSeen 回写设备活跃时间（鉴权通过后调用，失败仅影响审计不影响请求）
func (r *AuthRepo) TouchLastSeen(ctx context.Context, deviceID string) {
	_, _ = r.db.ExecContext(ctx,
		`UPDATE devices SET last_seen_at = ? WHERE id = ?`, utcNow(), deviceID)
}

func utcNow() string {
	return time.Now().UTC().Format(time.RFC3339)
}
