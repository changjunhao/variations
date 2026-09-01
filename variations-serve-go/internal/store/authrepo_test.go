package store

import (
	"context"
	"path/filepath"
	"testing"
)

func openTestDB(t *testing.T) *AuthRepo {
	t.Helper()
	db, err := Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("打开测试库失败: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return NewAuthRepo(db)
}

func TestRegisterAndValidate(t *testing.T) {
	repo := openTestDB(t)
	ctx := context.Background()

	if err := repo.RegisterDevice(ctx, "dev-1", "iPhone", "hash-1"); err != nil {
		t.Fatal(err)
	}
	deviceID, err := repo.ValidateToken(ctx, "hash-1")
	if err != nil || deviceID.Kind != KindDevice || deviceID.DeviceID != "dev-1" {
		t.Fatalf("token 校验失败: %v %+v", err, deviceID)
	}

	// 幂等重注册：旧 token 吊销，新 token 生效
	if err := repo.RegisterDevice(ctx, "dev-1", "iPhone 16", "hash-2"); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.ValidateToken(ctx, "hash-1"); err != ErrTokenInvalid {
		t.Fatalf("旧 token 应已吊销: %v", err)
	}
	if _, err := repo.ValidateToken(ctx, "hash-2"); err != nil {
		t.Fatalf("新 token 应有效: %v", err)
	}

	// 不存在的 token
	if _, err := repo.ValidateToken(ctx, "hash-none"); err != ErrTokenInvalid {
		t.Fatalf("未知 token 应无效: %v", err)
	}
}
