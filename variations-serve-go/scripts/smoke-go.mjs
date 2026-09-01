#!/usr/bin/env node
// variations-serve-go 契约验收
// 用法：node scripts/smoke-go.mjs
// 环境变量：
//   SMOKE_BASE_URL        服务地址（默认 http://127.0.0.1:8788）
//   SMOKE_REGISTER_SECRET 设备注册 App Secret（默认从 ../.env 的 REGISTER_SECRET 读取）
//   SMOKE_ADMIN_TOKEN     可选：直接用作 Bearer token（跳过设备注册）
//   SMOKE_REAL_CALLS      1 时执行真实上游调用（compile/image 正路径，耗时较长）
//   SMOKE_IMAGE_URL       本 bucket 域名下的可访问图片 URL（compile 与参考图正路径需要）
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const BASE = (process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:8788').replace(/\/$/, '');
const REAL = process.env.SMOKE_REAL_CALLS === '1';
const IMAGE_URL = process.env.SMOKE_IMAGE_URL ?? '';

// REGISTER_SECRET：显式 env 优先，否则尝试从 variations-serve-go/.env 读取
function loadRegisterSecret() {
  if (process.env.SMOKE_REGISTER_SECRET) return process.env.SMOKE_REGISTER_SECRET;
  try {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const envFile = fs.readFileSync(path.join(here, '..', '.env'), 'utf8');
    const m = envFile.match(/^REGISTER_SECRET=(.+)$/m);
    return m ? m[1].trim() : '';
  } catch {
    return '';
  }
}
const SECRET = loadRegisterSecret();

let pass = 0, fail = 0, skip = 0;
const ok = (name) => { pass += 1; console.log(`  PASS  ${name}`); };
const no = (name, detail) => { fail += 1; console.error(`  FAIL  ${name}\n        ${detail}`); };
const sk = (name, reason) => { skip += 1; console.log(`  SKIP  ${name}（${reason}）`); };

let TOKEN = process.env.SMOKE_ADMIN_TOKEN ?? '';

async function req(method, urlPath, body) {
  const res = await fetch(`${BASE}${urlPath}`, {
    method,
    headers: {
      ...(body == null ? {} : { 'Content-Type': 'application/json' }),
      ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
    },
    body: body == null ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = undefined; }
  return { status: res.status, json, text, headers: res.headers };
}

function assertStatus(r, status, name) {
  if (r.status === status) ok(name);
  else no(name, `期望 ${status}，实际 ${r.status}：${r.text.slice(0, 200)}`);
}

console.log(`\n== 冒烟目标：${BASE} ==\n`);

// ---- healthz ----
{
  const r = await req('GET', '/healthz');
  r.status === 200 && r.json?.ok === true ? ok('healthz 200') : no('healthz 200', r.text);
}

// ---- 设备注册（公开端点 + App Secret 软门槛）----
if (!TOKEN) {
  if (!SECRET) {
    sk('设备注册', '未提供 SMOKE_REGISTER_SECRET，无法注册取 token（后续用例将跳过）');
  } else {
    const deviceId = `smoke-${crypto.randomUUID()}`;
    const proof = crypto.createHmac('sha256', SECRET).update(deviceId).digest('hex');
    // proof 错误 → 401 REGISTER_DENIED
    const bad = await req('POST', '/api/auth/device', { deviceId, proof: '0'.repeat(64) });
    bad.status === 401 && bad.json?.code === 'REGISTER_DENIED'
      ? ok('注册错误 proof -> 401 REGISTER_DENIED')
      : no('注册错误 proof -> 401 REGISTER_DENIED', bad.text);
    // 正路径
    const r = await req('POST', '/api/auth/device', { deviceId, deviceName: 'smoke', proof });
    if (r.status === 200 && typeof r.json?.token === 'string' && r.json.token.startsWith('var_')) {
      ok('设备注册正路径（token var_ 前缀）');
      TOKEN = r.json.token;
    } else {
      no('设备注册正路径', r.text);
    }
    // 幂等重注册：同 deviceId 返回新 token
    const again = await req('POST', '/api/auth/device', { deviceId, proof });
    again.status === 200 && again.json?.token !== TOKEN
      ? ok('幂等重注册（新 token）')
      : no('幂等重注册（新 token）', again.text);
    if (again.status === 200) TOKEN = again.json.token;
  }
}

if (!TOKEN) {
  console.log(`\n== 无可用 token，结束：${pass} 通过 / ${fail} 失败 / ${skip} 跳过 ==\n`);
  process.exit(fail > 0 ? 1 : 0);
}

// ---- 鉴权 ----
{
  const res = await fetch(`${BASE}/api/skills`);
  assertStatus({ status: res.status, text: '' }, 401, '无 token 访问 /api/skills -> 401');
  const fake = await fetch(`${BASE}/api/skills`, { headers: { Authorization: 'Bearer var_fake' } });
  assertStatus({ status: fake.status, text: '' }, 401, '伪造 token -> 401');
}

// ---- SIWA 用户系统错误路径（真实 SIWA 依赖真机，脚本只测 400/401/503）----
{
  const r = await req('POST', '/api/auth/apple', { identityToken: 'garbage' });
  if (r.status === 401 && r.json?.code === 'APPLE_TOKEN_INVALID') {
    ok('auth/apple 垃圾 token -> 401 APPLE_TOKEN_INVALID');
  } else if (r.status === 503) {
    sk('auth/apple 垃圾 token', 'APPLE_CLIENT_ID 未配置（503 已验证）');
  } else {
    no('auth/apple 垃圾 token -> 401/503', r.text);
  }
  assertStatus(await req('POST', '/api/auth/apple', {}), 400, 'auth/apple 缺参 -> 400');
  const q = await req('GET', '/api/quota');
  q.status === 200 && q.json?.tier === 'guest' && typeof q.json?.trial?.limit === 'number' && typeof q.json?.resetsAt === 'string'
    ? ok('quota 游客摘要（trial/limit/resetsAt）')
    : no('quota 游客摘要', q.text);
  assertStatus(await req('POST', '/api/auth/logout'), 400, 'logout 游客会话 -> 400');
  assertStatus(await req('POST', '/api/account/delete'), 400, 'account/delete 游客身份 -> 400');
}

// ---- GET /api/skills ----
{
  const r = await req('GET', '/api/skills');
  if (r.status === 503) {
    sk('skills 正路径', '服务端 assets 未就位（503 已验证）');
  } else if (r.status === 200) {
    ok('skills 200');
    const cards = r.json;
    const fieldsOk =
      Array.isArray(cards) && cards.length >= 2 &&
      cards.every((c) =>
        typeof c.id === 'string' && typeof c.name === 'string' && typeof c.description === 'string' &&
        typeof c.displayName === 'string' && typeof c.shortDescription === 'string' &&
        typeof c.defaultPrompt === 'string' && ('sampleImageUrl' in c) &&
        ('sampleImageAspect' in c) && ('size' in c) && ('instructionTemplate' in c));
    fieldsOk ? ok('skills 卡片字段齐全（含 null 语义字段）') : no('skills 卡片字段齐全', r.text);
    const leaked = r.text.includes('# 影像蒸馏') || r.text.includes('# 实景拼贴');
    leaked ? no('skills 不含 SKILL.md 正文', r.text.slice(0, 200)) : ok('skills 不含 SKILL.md 正文');
    const etag = r.headers.get('etag');
    if (etag && /^W\/"[0-9a-f]{16}"$/.test(etag)) {
      ok('skills 返回弱 ETag（内容哈希格式）');
      const r2 = await fetch(`${BASE}/api/skills`, {
        headers: { Authorization: `Bearer ${TOKEN}`, 'If-None-Match': etag },
      });
      assertStatus({ status: r2.status, text: '' }, 304, 'skills If-None-Match -> 304');
    } else {
      no('skills 返回弱 ETag（内容哈希格式）', `ETag=${etag}`);
    }
  } else {
    no('skills 200', r.text);
  }
}

// ---- GET /api/upload-ticket（hash 内容寻址）----
{
  const hash = crypto.createHash('sha256').update(`smoke-${Date.now()}`).digest('hex');
  assertStatus(await req('GET', '/api/upload-ticket?ext=gif&hash=' + hash), 400, 'upload-ticket 非法 ext -> 400');
  assertStatus(await req('GET', '/api/upload-ticket?ext=jpg&hash=ZZZ'), 400, 'upload-ticket 非法 hash -> 400');
  const r = await req('GET', `/api/upload-ticket?ext=jpg&hash=${hash}`);
  if (r.status === 503) {
    sk('upload-ticket 正路径', '服务端 OSS 未配置（503 已验证）');
  } else if (r.status === 200) {
    const t = r.json;
    const shapeOk =
      typeof t.uploadUrl === 'string' && typeof t.fileUrl === 'string' &&
      typeof t.contentType === 'string' && typeof t.expiresAt === 'string';
    shapeOk ? ok('upload-ticket 票据字段齐全') : no('upload-ticket 票据字段齐全', r.text);
    // expiresAt 为 RFC 3339
    !Number.isNaN(Date.parse(t.expiresAt)) ? ok('expiresAt RFC 3339 可解析') : no('expiresAt RFC 3339 可解析', t.expiresAt);
    // objectKey 内容寻址：URL 含 uploads/{hash}.jpg
    t.uploadUrl.includes(`uploads/${hash}.jpg`) && t.fileUrl.includes(`uploads/${hash}.jpg`)
      ? ok('objectKey 内容寻址 uploads/{hash}.{ext}')
      : no('objectKey 内容寻址 uploads/{hash}.{ext}', t.uploadUrl);
    // 真实 PUT 上传 + GET 回读（预签名 URL 有效性验证）
    const bytes = Buffer.from(`smoke-${Date.now()}`);
    const put = await fetch(t.uploadUrl, { method: 'PUT', headers: { 'Content-Type': t.contentType }, body: bytes });
    assertStatus({ status: put.status, text: '' }, 200, 'PUT 预签名上传成功');
    const get = await fetch(t.fileUrl);
    assertStatus({ status: get.status, text: '' }, 200, 'GET 预签名回读成功（≤2h 票据）');
  } else {
    no('upload-ticket 正路径', r.text);
  }
}

// ---- POST /api/compile 异常路径 ----
{
  const img = 'https://example.com/x.jpg';
  assertStatus(await req('POST', '/api/compile', {}), 400, 'compile 缺参 -> 400');
  assertStatus(await req('POST', '/api/compile', { imageUrl: img }), 400, 'compile skillId/inlineSkill 均缺 -> 400');
  assertStatus(
    await req('POST', '/api/compile', { skillId: 'a', inlineSkill: { body: 'b' }, imageUrl: img }),
    400, 'compile 二选一互斥 -> 400');
  assertStatus(
    await req('POST', '/api/compile', { skillId: 'no-such-skill', imageUrl: img }),
    400, 'compile 非法域名 imageUrl -> 400');
  // 严格类型：instruction 传数字 -> 400
  assertStatus(
    await req('POST', '/api/compile', { inlineSkill: { body: 'b' }, imageUrl: img, instruction: 123 }),
    400, 'compile instruction 数字（严格类型）-> 400');
  const r = await req('POST', '/api/compile', { skillId: 'no-such-skill', imageUrl: IMAGE_URL || img });
  if (r.status === 404) {
    r.json?.message?.includes('可用') ? ok('compile 未知 skillId -> 404 含可用列表') : no('compile 404 含可用列表', r.text);
  } else if (!IMAGE_URL) {
    sk('compile 未知 skillId -> 404', '需 SMOKE_IMAGE_URL 为本 bucket 域名才能走到 skill 查找');
  } else {
    no('compile 未知 skillId -> 404', r.text);
  }
  assertStatus(
    await req('POST', '/api/compile', { inlineSkill: { body: 'x'.repeat(101 * 1024) }, imageUrl: img }),
    400, 'compile inlineSkill 超 100KB -> 400');
  // 非法 JSON -> 400
  assertStatus(await req('POST', '/api/compile', '{bad'), 400, 'compile 非法 JSON -> 400');
}

// ---- POST /api/compile 正路径 ----
if (REAL && IMAGE_URL) {
  const r = await req('POST', '/api/compile', {
    inlineSkill: { body: '你是提示词编译器。分析照片并输出出一段中文生图提示词，用 <FINAL_PROMPT></FINAL_PROMPT> 包裹。' },
    imageUrl: IMAGE_URL,
  });
  if (r.status === 200 && typeof r.json?.prompt === 'string' && r.json.prompt.length > 0) {
    ok(`compile inlineSkill 正路径（prompt ${r.json.prompt.length} 字符）`);
  } else {
    no('compile inlineSkill 正路径', r.text.slice(0, 200));
  }
  const r2 = await req('POST', '/api/compile', { skillId: 'scene-distillation-zine', imageUrl: IMAGE_URL });
  if (r2.status === 200 && typeof r2.json?.prompt === 'string') {
    ok(`compile skillId 正路径（prompt ${r2.json.prompt.length} 字符）`);
  } else {
    no('compile skillId 正路径', r2.text.slice(0, 200));
  }
} else {
  sk('compile 正路径', '需 SMOKE_REAL_CALLS=1 且 SMOKE_IMAGE_URL 为本 bucket 可访问图片');
}

// ---- POST /api/image 异常路径 ----
{
  assertStatus(await req('POST', '/api/image', {}), 400, 'image 缺 prompt -> 400');
  assertStatus(await req('POST', '/api/image', { prompt: 'p'.repeat(16_001) }), 400, 'image prompt 超长 -> 400');
  assertStatus(
    await req('POST', '/api/image', { prompt: 'x', imageUrls: Array(4).fill('https://example.com/a.jpg') }),
    400, 'image 参考图 4 张 -> 400');
  assertStatus(
    await req('POST', '/api/image', { prompt: 'x', imageUrls: ['https://evil.com/a.jpg'] }),
    400, 'image 非法域名参考图 -> 400');
  // 严格类型：seed 传字符串 -> 400
  assertStatus(await req('POST', '/api/image', { prompt: 'x', seed: '7' }), 400, 'image seed 字符串（严格类型）-> 400');
}

// ---- POST /api/image 正路径 ----
if (REAL) {
  const r = await req('POST', '/api/image', { prompt: '一片宁静的湖面，极简插画风格', seed: 7 });
  if (r.status === 200 && Array.isArray(r.json?.urls) && r.json.urls.length > 0) {
    ok(`image 文生图正路径（${r.json.urls.length} 张）`);
  } else {
    no('image 文生图正路径', r.text.slice(0, 200));
  }
  const rs = await req('POST', '/api/image', { prompt: '一片宁静的湖面，极简插画风格', skillId: 'no-such-skill' });
  if (rs.status === 200 && Array.isArray(rs.json?.urls) && rs.json.urls.length > 0) {
    ok('image 未知 skillId 回退全局默认');
  } else {
    no('image 未知 skillId 回退全局默认', rs.text.slice(0, 200));
  }
  if (IMAGE_URL) {
    const r1 = await req('POST', '/api/image', {
      prompt: '基于参考图做同风格变奏', imageUrls: [IMAGE_URL], size: '896*1600',
    });
    if (r1.status === 200 && Array.isArray(r1.json?.urls) && r1.json.urls.length > 0) {
      ok('image 1 张参考图 + size 钳制正路径');
    } else {
      no('image 1 张参考图 + size 钳制正路径', r1.text.slice(0, 200));
    }
    const r2 = await req('POST', '/api/image', {
      prompt: '融合两张参考图生成一张新图', imageUrls: [IMAGE_URL, IMAGE_URL],
    });
    if (r2.status === 200 && Array.isArray(r2.json?.urls) && r2.json.urls.length > 0) {
      ok('image 2 张参考图（image 数组）正路径');
    } else {
      no('image 2 张参考图（image 数组）正路径', r2.text.slice(0, 200));
    }
  } else {
    sk('image 参考图正路径', '需 SMOKE_IMAGE_URL 为本 bucket 可访问图片');
  }
} else {
  sk('image 文生图正路径', '需 SMOKE_REAL_CALLS=1');
}

// ---- 404 契约（含方法不匹配）----
{
  const r = await req('GET', '/api/nope');
  r.status === 404 && r.json?.code === 'NOT_FOUND' && r.json?.message?.includes('未知路由')
    ? ok('未知路由 -> 404 NOT_FOUND')
    : no('未知路由 -> 404 NOT_FOUND', r.text);
  const m = await req('POST', '/api/skills', {});
  assertStatus(m, 404, '方法不匹配 -> 404（非 405）');
}

console.log(`\n== 结果：${pass} 通过 / ${fail} 失败 / ${skip} 跳过 ==\n`);
process.exit(fail > 0 ? 1 : 0);
