package store

import (
	"context"
	"strings"
	"time"
)

// PrivilegeWindow 新用户特权窗口：自注册日起 N 个上海自然日（含注册当日）
func PrivilegeWindow(quota *QuotaRepo, createdAtRaw string, days int) (active bool, daysLeft int) {
	if createdAtRaw == "" || days <= 0 {
		return false, 0
	}
	created, err := time.Parse(time.RFC3339, createdAtRaw)
	if err != nil {
		return false, 0
	}
	startDay := quota.Shanghai(created)
	startDay = time.Date(startDay.Year(), startDay.Month(), startDay.Day(), 0, 0, 0, 0, startDay.Location())
	end := startDay.AddDate(0, 0, days)
	now := quota.Now()
	if !now.Before(end) {
		return false, 0
	}
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	return true, int(end.Sub(today).Hours() / 24)
}

// QuotaSummary 对外配额摘要（次数口径；GET /api/quota、登录响应、429 共用）
type QuotaSummary struct {
	Tier      string            `json:"tier"`
	Source    string            `json:"source,omitempty"` // 429 时附耗尽来源：trial/privilege/paid + "_exhausted"
	Trial     *TrialSummary     `json:"trial,omitempty"`
	Privilege *PrivilegeSummary `json:"privilege,omitempty"`
	Paid      *PaidSummary      `json:"paid,omitempty"`
	ResetsAt  string            `json:"resetsAt"`
}

type TrialSummary struct {
	Remaining int `json:"remaining"`
	Limit     int `json:"limit"`
}

type PrivilegeSummary struct {
	Active         bool `json:"active"`
	DaysLeft       int  `json:"daysLeft"`
	RemainingToday int  `json:"remainingToday"`
	LimitToday     int  `json:"limitToday"`
}

type PaidSummary struct {
	Remaining int `json:"remaining"`
}

// BuildQuotaSummary 组装配额摘要：游客→trial；用户→privilege+paid；admin→仅 tier。
// exhaustedSrc 非空时写入 source（"{src}_exhausted"）。
func BuildQuotaSummary(ctx context.Context, quota *QuotaRepo, users *UserRepo, principal, userID, createdAtRaw string, guestTotal, privDays, privDaily int, exhaustedSrc string) QuotaSummary {
	s := QuotaSummary{ResetsAt: quota.ResetsAt().Format(time.RFC3339)}
	if exhaustedSrc != "" {
		s.Source = exhaustedSrc + "_exhausted"
	}
	if strings.HasPrefix(principal, "device:") {
		used, _ := quota.Used(ctx, principal, LifetimeBucket)
		remaining := guestTotal - used
		if remaining < 0 {
			remaining = 0
		}
		s.Tier = "guest"
		s.Trial = &TrialSummary{Remaining: remaining, Limit: guestTotal}
		return s
	}
	if userID == "" {
		s.Tier = "admin"
		return s
	}
	active, daysLeft := PrivilegeWindow(quota, createdAtRaw, privDays)
	usedToday, _ := quota.Used(ctx, principal, quota.TodayBucket())
	remainingToday := privDaily - usedToday
	if remainingToday < 0 {
		remainingToday = 0
	}
	paid, _ := users.PaidRemaining(ctx, userID)
	s.Tier = "user"
	s.Privilege = &PrivilegeSummary{
		Active:         active,
		DaysLeft:       daysLeft,
		RemainingToday: remainingToday,
		LimitToday:     privDaily,
	}
	s.Paid = &PaidSummary{Remaining: paid}
	return s
}
