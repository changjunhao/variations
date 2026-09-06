package config

// 配置解析单测：IAP 票据环境白名单的缺省与显式语义
// （缺省必须同时含 sandbox，否则 TestFlight 与 App Review 的购买全部 401）。

import "testing"

func TestParseIAPEnvironmentsDefaultsToBoth(t *testing.T) {
	envs := parseIAPEnvironments("")
	if !envs["production"] || !envs["sandbox"] {
		t.Fatalf("缺省应同时接受 production 与 sandbox: %v", envs)
	}
	if len(envs) != 2 {
		t.Fatalf("缺省集合应恰为两项: %v", envs)
	}
}

func TestParseIAPEnvironmentsExplicit(t *testing.T) {
	// 显式单值 → 只收该环境（保留收紧能力）
	only := parseIAPEnvironments("Production")
	if !only["production"] || only["sandbox"] {
		t.Fatalf("显式 Production 应只收 production: %v", only)
	}
	// 逗号分隔 + 大小写与空格容错
	both := parseIAPEnvironments(" production , SANDBOX ")
	if !both["production"] || !both["sandbox"] || len(both) != 2 {
		t.Fatalf("应容错空格与大小写: %v", both)
	}
}
