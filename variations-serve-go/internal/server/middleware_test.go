package server

import "testing"

// 固定分钟窗口语义：恰好放行 max 次，第 max+1 次拒绝
func TestMinuteLimiterBoundary(t *testing.T) {
	l := NewMinuteLimiter(3)
	key := "dev-1"
	for i := 1; i <= 3; i++ {
		if !l.Allow(key) {
			t.Fatalf("第 %d 次应放行", i)
		}
	}
	if l.Allow(key) {
		t.Fatal("第 4 次应拒绝")
	}
	// 不同 key 互不影响
	if !l.Allow("dev-2") {
		t.Fatal("其他 key 应放行")
	}
}

// 跨分钟重置（直接操作桶模拟时间推进）
func TestMinuteLimiterMinuteReset(t *testing.T) {
	l := NewMinuteLimiter(1)
	if !l.Allow("k") {
		t.Fatal("首次应放行")
	}
	if l.Allow("k") {
		t.Fatal("同分钟第 2 次应拒绝")
	}
	// 手工把桶的分钟戳改为过去，模拟跨分钟
	l.mu.Lock()
	b := l.buckets["k"]
	b.minute -= 1
	l.buckets["k"] = b
	l.mu.Unlock()
	if !l.Allow("k") {
		t.Fatal("跨分钟后应重新放行")
	}
}
