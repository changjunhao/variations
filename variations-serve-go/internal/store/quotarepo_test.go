package store

import (
	"context"
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func openQuotaTestDB(t *testing.T) *QuotaRepo {
	t.Helper()
	db, err := Open(filepath.Join(t.TempDir(), "quota.db"))
	if err != nil {
		t.Fatalf("打开测试库失败: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return NewQuotaRepo(db)
}

func TestQuotaDeductAndExceed(t *testing.T) {
	repo := openQuotaTestDB(t)
	ctx := context.Background()

	// 扣满 limit（终身桶）
	for i := 0; i < 3; i++ {
		if err := repo.Deduct(ctx, "device:x", LifetimeBucket, 3); err != nil {
			t.Fatalf("第 %d 次扣减应成功: %v", i+1, err)
		}
	}
	if err := repo.Deduct(ctx, "device:x", LifetimeBucket, 3); !errors.Is(err, ErrQuotaExceeded) {
		t.Fatalf("超限额应 ErrQuotaExceeded: %v", err)
	}

	used, err := repo.Used(ctx, "device:x", LifetimeBucket)
	if err != nil || used != 3 {
		t.Fatalf("used 应为 3: %v %d", err, used)
	}
	// 日桶独立计数
	if err := repo.Deduct(ctx, "device:x", repo.TodayBucket(), 1); err != nil {
		t.Fatalf("日桶应独立: %v", err)
	}
}

func TestQuotaRefund(t *testing.T) {
	repo := openQuotaTestDB(t)
	ctx := context.Background()

	if err := repo.Deduct(ctx, "device:r", LifetimeBucket, 1); err != nil {
		t.Fatal(err)
	}
	if err := repo.Refund(ctx, "device:r", LifetimeBucket); err != nil {
		t.Fatal(err)
	}
	used, _ := repo.Used(ctx, "device:r", LifetimeBucket)
	if used != 0 {
		t.Fatalf("退还后 used 应为 0: %d", used)
	}
	// 超额退还不产生负数
	if err := repo.Refund(ctx, "device:r", LifetimeBucket); err != nil {
		t.Fatal(err)
	}
	used, _ = repo.Used(ctx, "device:r", LifetimeBucket)
	if used != 0 {
		t.Fatalf("退还下限 0: %d", used)
	}
}

func TestQuotaConcurrentNoOverdraw(t *testing.T) {
	repo := openQuotaTestDB(t)
	ctx := context.Background()

	// 20 并发各扣 1，limit 10 → 恰好 10 次成功
	var wg sync.WaitGroup
	ok := make(chan struct{}, 20)
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := repo.Deduct(ctx, "device:c", repo.TodayBucket(), 10); err == nil {
				ok <- struct{}{}
			}
		}()
	}
	wg.Wait()
	close(ok)
	n := 0
	for range ok {
		n++
	}
	if n != 10 {
		t.Fatalf("并发扣减应恰好 10 次成功: %d", n)
	}
}

func TestQuotaPrincipalIsolation(t *testing.T) {
	repo := openQuotaTestDB(t)
	ctx := context.Background()

	if err := repo.Deduct(ctx, DevicePrincipal("d1"), LifetimeBucket, 1); err != nil {
		t.Fatal(err)
	}
	// 设备配额满不影响用户主体与编译计数
	if err := repo.Deduct(ctx, UserPrincipal("u1"), repo.TodayBucket(), 100); err != nil {
		t.Fatalf("用户主体应独立: %v", err)
	}
	if err := repo.Deduct(ctx, CompilePrincipal(DevicePrincipal("d1")), repo.TodayBucket(), 20); err != nil {
		t.Fatalf("编译计数应独立: %v", err)
	}
}

func TestQuotaResetsAt(t *testing.T) {
	repo := openQuotaTestDB(t)
	r := repo.ResetsAt()
	if r.IsZero() {
		t.Fatal("resetsAt 不应为零值")
	}
	h, m, s := r.Clock()
	if h != 0 || m != 0 || s != 0 {
		t.Fatalf("resetsAt 应为零点: %v", r)
	}
}

func TestPrivilegeWindow(t *testing.T) {
	repo := openQuotaTestDB(t)
	now := repo.Now()

	// 刚注册 → 激活且 daysLeft = 7
	active, daysLeft := PrivilegeWindow(repo, now.Add(-time.Minute).Format("2006-01-02T15:04:05Z07:00"), 7)
	if !active || daysLeft != 7 {
		t.Fatalf("刚注册应激活 7 天: %v %d", active, daysLeft)
	}
	// 8 天前注册 → 过期
	active, _ = PrivilegeWindow(repo, now.AddDate(0, 0, -8).Format("2006-01-02T15:04:05Z07:00"), 7)
	if active {
		t.Fatal("8 天前注册应过期")
	}
	// 空串 → 不激活
	active, _ = PrivilegeWindow(repo, "", 7)
	if active {
		t.Fatal("空注册时间应不激活")
	}
}
