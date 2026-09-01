#!/usr/bin/env node
// 运营脚本：用产品自身链路为 skill 生成样图（票据直传 → compile → image → 落盘 sample.jpg）
// 前置：Go 服务已启动（make dev，默认 8788），.env 含 REGISTER_SECRET 与 OSS_*
// 用法：node scripts/gen-samples.mjs [--instruction '【标签】：值'] <skillId=源图路径[=auto|=x2|=src|=W:H|=W*H]> [...]
//   例：node scripts/gen-samples.mjs "scene-distillation-zine=/path/to/photo.jpg"
//   --instruction 可选：模拟客户端结构化附加指令（如城市名），格式与客户端拼装一致：
//   例：node scripts/gen-samples.mjs --instruction '【城市名】：太原' "city-ink-poster=/path/to/photo.jpg=src"
//   追加 "=auto" 则不传 size 由模型按提示词自动推荐画幅：
//   例：node scripts/gen-samples.mjs "photo-abstract-editorial=/path/to/photo.jpg=auto"
//   追加 "=x2" 则模拟客户端加倍串换算（原图短边加倍、长边 1600）：
//   例：node scripts/gen-samples.mjs "photo-abstract-editorial=/path/to/photo.jpg=x2"
//   追加 "=src" 则模拟客户端源比例串换算（画幅严格保持原图宽高比，长边 1600）：
//   例：node scripts/gen-samples.mjs "city-ink-poster=/path/to/photo.jpg=src"
//   追加 "=W:H" 则模拟客户端比例串换算（画幅跟随原图朝向，长边 1600）：
//   例：node scripts/gen-samples.mjs "scene-distillation-zine=/path/to/photo.jpg=3:5"
//   追加 "=W*H" 则直接使用固定像素串（不跟随原图朝向，用于固定画幅 skill）：
//   例：node scripts/gen-samples.mjs "travel-memory-sticker-card=/path/to/photo.jpg=1536*1024"
// 源图会先压缩为长边 ≤2048 / JPEG 85（模拟客户端行为），产物存
// assets/skills/<skillId>/assets/sample.jpg；之后用 cmd/sync-samples 同步到 OSS
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BASE = (process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:8788').replace(/\/$/, '');

// 设备注册取 Bearer token（Go 端鉴权契约：HMAC-SHA256 proof）
const envText = fs.readFileSync(path.join(root, '.env'), 'utf8');
const SECRET = envText.match(/^REGISTER_SECRET=(.+)$/m)?.[1]?.trim();
if (!SECRET) throw new Error('.env 缺少 REGISTER_SECRET');
const deviceId = `gen-samples-${Date.now()}`;
const proof = crypto.createHmac('sha256', SECRET).update(deviceId).digest('hex');
const reg = await (await fetch(`${BASE}/api/auth/device`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ deviceId, deviceName: 'gen-samples', proof }),
})).json();
if (!reg.token) throw new Error(`设备注册失败：${JSON.stringify(reg).slice(0, 200)}`);
const H = { Authorization: `Bearer ${reg.token}`, 'Content-Type': 'application/json' };

const argv = process.argv.slice(2);
let instruction;
const pairArgs = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--instruction' || a === '-i') { instruction = argv[++i]; continue; }
  if (a.startsWith('--instruction=')) { instruction = a.slice('--instruction='.length); continue; }
  pairArgs.push(a);
}
const pairs = pairArgs.map((arg) => {
  const eq = arg.indexOf('=');
  if (eq <= 0) throw new Error(`参数格式应为 skillId=源图路径[=auto]：${arg}`);
  const skill = arg.slice(0, eq);
  let src = arg.slice(eq + 1);
  // 可选尾段："=auto" 不传 size 由模型自动推荐；"=x2" 压缩后按原图短边加倍换算；
  // "=src" 压缩后严格保持原图宽高比；"=W:H" 压缩后按客户端比例串约定换算；缺省保持竖版 3:5 的 768*1280
  let size = '768*1280';
  if (src.endsWith('=auto')) {
    src = src.slice(0, -'=auto'.length);
    size = undefined;
  } else if (src.endsWith('=x2')) {
    src = src.slice(0, -'=x2'.length);
    size = 'x2'; // 占位：压缩后换算
  } else if (src.endsWith('=src')) {
    src = src.slice(0, -'=src'.length);
    size = 'src'; // 占位：压缩后换算
  } else {
    const fixed = src.match(/=(\d+\*\d+)$/);
    const ratio = src.match(/=(\d+:\d+)$/);
    if (fixed) {
      src = src.slice(0, src.length - fixed[0].length);
      size = fixed[1]; // 固定像素串：直接使用，不跟随原图朝向
    } else if (ratio) {
      src = src.slice(0, src.length - ratio[0].length);
      size = ratio[1]; // 比例串占位：压缩后按朝向换算
    }
  }
  return [skill, path.resolve(src), size];
});
if (pairs.length === 0) {
  console.error('用法：node scripts/gen-samples.mjs "skillId=/path/to/photo.jpg" ...');
  process.exit(1);
}

for (const [skill, src, pairSize] of pairs) {
  const t0 = Date.now();
  // 1. 压缩（模拟客户端：长边 ≤2048、JPEG 85；execFileSync 参数数组避免 shell 注入）
  const compressed = `/tmp/gen-samples-${skill}.jpg`;
  execFileSync('sips', ['-Z', '2048', '-s', 'format', 'jpeg', '-s', 'formatOptions', '85', src, '--out', compressed], { stdio: 'ignore' });
  // 1.5 =x2 / =src / =W:H：模拟客户端换算（探测压缩后尺寸，长边 1600）；=W*H 固定像素串跳过换算
  let size = pairSize;
  if (size === 'x2' || size === 'src' || /^\d+:\d+$/.test(size ?? '')) {
    const probe = execFileSync('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', compressed]).toString();
    const w = Number(probe.match(/pixelWidth:\s*(\d+)/)[1]);
    const h = Number(probe.match(/pixelHeight:\s*(\d+)/)[1]);
    if (size === 'src') {
      // 源比例串：画幅严格保持原图宽高比，长边 1600
      const scale = 1600 / Math.max(w, h);
      size = `${Math.round(w * scale)}*${Math.round(h * scale)}`;
    } else if (size === 'x2') {
      // 加倍串：竖版宽加倍→横版画布，横版/方图高加倍→竖版画布
      let dw = w, dh = h;
      if (w >= h) dh = h * 2; else dw = w * 2;
      const scale = 1600 / Math.max(dw, dh);
      size = `${Math.round(dw * scale)}*${Math.round(dh * scale)}`;
    } else {
      // 比例串（短:长，如 3:5）：横版 → 长*短，竖版/方图 → 短*长
      const [a, b] = size.split(':').map(Number);
      const short = Math.round((1600 * Math.min(a, b)) / Math.max(a, b));
      size = w > h ? `1600*${short}` : `${short}*1600`;
    }
  }
  // 2. 票据（内容寻址 hash 必填）+ 直传
  const bytes = fs.readFileSync(compressed);
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  const t = await (await fetch(`${BASE}/api/upload-ticket?ext=jpg&hash=${hash}`, { headers: H })).json();
  if (!t.uploadUrl) throw new Error(`${skill}: 取票据失败 ${JSON.stringify(t).slice(0, 200)}`);
  const put = await fetch(t.uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': t.contentType },
    body: bytes,
  });
  if (put.status !== 200) throw new Error(`${skill}: PUT ${put.status}`);
  // 3. compile
  const comp = await (
    await fetch(`${BASE}/api/compile`, {
      method: 'POST',
      headers: H,
      body: JSON.stringify({ skillId: skill, imageUrl: t.fileUrl, ...(instruction ? { instruction } : {}) }),
    })
  ).json();
  if (!comp.prompt) throw new Error(`${skill}: compile 失败 ${JSON.stringify(comp).slice(0, 200)}`);
  // 4. image（缺省竖版 3:5 海报；=auto 时 size 为 undefined，JSON.stringify 自动丢弃）
  const img = await (
    await fetch(`${BASE}/api/image`, {
      method: 'POST',
      headers: H,
      body: JSON.stringify({ prompt: comp.prompt, imageUrls: [t.fileUrl], size }),
    })
  ).json();
  if (!img.urls?.length) throw new Error(`${skill}: image 失败 ${JSON.stringify(img).slice(0, 200)}`);
  // 5. 落盘为 sample.jpg（生成结果 png 转 jpeg）
  const out = path.join(root, 'assets', 'skills', skill, 'assets', 'sample.jpg');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const res = await fetch(img.urls[0]);
  fs.writeFileSync(out, Buffer.from(await res.arrayBuffer()));
  execFileSync('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '85', out, '--out', out], { stdio: 'ignore' });
  fs.rmSync(compressed, { force: true });
  console.log(`[ok] ${skill} in ${((Date.now() - t0) / 1000).toFixed(0)}s -> ${out}`);
}
console.log('done');
