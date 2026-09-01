package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// ErrQuotaExceeded 配额不足 → 429 QUOTA_EXCEEDED
var ErrQuotaExceeded = errors.New("配额不足")

// LifetimeBucket 终身桶哨兵日串（游客体验额度，不随日重置）
const LifetimeBucket = "LIFETIME"

// principal 前缀：配额归属维度（设备/用户），防刷上限追加 ":compile" 后缀
const (
	principalDevicePrefix = "device:"
	principalUserPrefix   = "user:"
	compileSuffix         = ":compile"
)

// DevicePrincipal 设备主体配额键
func DevicePrincipal(deviceID string) string { return principalDevicePrefix + deviceID }

// UserPrincipal 用户主体配额键
func UserPrincipal(userID string) string { return principalUserPrefix + userID }

// CompilePrincipal 编译防刷上限键（复用日配额表，独立计数）
func CompilePrincipal(principal string) string { return principal + compileSuffix }

// QuotaRepo 次数配额：principal+bucket 复合主键；bucket 为日串（每日重置）或
// LifetimeBucket（终身不重置）。扣减恒 1 次，条件原子更新防并发超扣，失败可原路退还。
type QuotaRepo struct {
	db  *sql.DB
	loc *time.Location
}

func NewQuotaRepo(db *sql.DB) *QuotaRepo {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		loc = time.FixedZone("CST", 8*3600) // tzdata 缺失时回退固定 UTC+8
	}
	return &QuotaRepo{db: db, loc: loc}
}

// TodayBucket 当日日串（Asia/Shanghai），每日零点刷新语义
func (r *QuotaRepo) TodayBucket() string {
	return time.Now().In(r.loc).Format("2006-01-02")
}

// Now 上海当前时间（特权窗口判定共用口径）
func (r *QuotaRepo) Now() time.Time { return time.Now().In(r.loc) }

// Shanghai 任意时间点换算到上海时区
func (r *QuotaRepo) Shanghai(t time.Time) time.Time { return t.In(r.loc) }

// ResetsAt 次日北京时间零点（供客户端展示「每日零点刷新」）
func (r *QuotaRepo) ResetsAt() time.Time {
	now := r.Now()
	return time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, r.loc)
}

// DayBucketFor 任意时间点的日串（特权起点换算用）
func (r *QuotaRepo) DayBucketFor(t time.Time) string { return t.In(r.loc).Format("2006-01-02") }

// ensure 惰性建行（日串变化即新行，天然重置；LIFETIME 桶仅建一次）
func (r *QuotaRepo) ensure(ctx context.Context, principal, bucket string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO daily_quotas (principal, day, used) VALUES (?, ?, 0)
		 ON CONFLICT(principal, day) DO NOTHING`, principal, bucket)
	if err != nil {
		return fmt.Errorf("初始化配额行失败: %w", err)
	}
	return nil
}

// Used 指定桶已用次数（无行视为 0）
func (r *QuotaRepo) Used(ctx context.Context, principal, bucket string) (int, error) {
	var used int
	err := r.db.QueryRowContext(ctx,
		`SELECT used FROM daily_quotas WHERE principal = ? AND day = ?`,
		principal, bucket).Scan(&used)
	if errors.Is(err, sql.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("查询配额失败: %w", err)
	}
	return used, nil
}

// Deduct 原子扣 1 次：used+1 超 limit 即拒绝（affected rows=0）
func (r *QuotaRepo) Deduct(ctx context.Context, principal, bucket string, limit int) error {
	if err := r.ensure(ctx, principal, bucket); err != nil {
		return err
	}
	res, err := r.db.ExecContext(ctx,
		`UPDATE daily_quotas SET used = used + 1
		 WHERE principal = ? AND day = ? AND used + 1 <= ?`,
		principal, bucket, limit)
	if err != nil {
		return fmt.Errorf("扣减配额失败: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("读取扣减结果失败: %w", err)
	}
	if n == 0 {
		return ErrQuotaExceeded
	}
	return nil
}

// Refund 退还 1 次（仅失败路径调用；下限 0 防负数）
func (r *QuotaRepo) Refund(ctx context.Context, principal, bucket string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE daily_quotas SET used = MAX(0, used - 1) WHERE principal = ? AND day = ?`,
		principal, bucket)
	if err != nil {
		return fmt.Errorf("退还配额失败: %w", err)
	}
	return nil
}
