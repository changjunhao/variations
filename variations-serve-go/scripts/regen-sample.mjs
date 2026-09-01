#!/usr/bin/env node
// 运营脚本：带 instruction 重生成 sample.jpg（gen-samples 不支持 instruction 参数时的补位）
// 前置：Go 服务已启动（make dev，默认 8788），.env 含 REGISTER_SECRET
// 用法：node scripts/regen-sample.mjs <skillId> <源图路径> <size> <instruction>
// 例：node scripts/regen-sample.mjs photo-to-monthly-zine-postcard /path/to/photo.jpg "1200*1600" "月份为 3 月：月份数字 03，英文月份 March。"
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const [, , skill, src, size, instruction] = process.argv;
if (!skill || !src || !size || !instruction) {
  console.error('用法：node scripts/.regen-sample.mjs <skillId> <源图> <size> <instruction>');
  process.exit(1);
}
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const BASE = 'http://127.0.0.1:8788';

const envText = fs.readFileSync(path.join(root, '.env'), 'utf8');
const SECRET = envText.match(/^REGISTER_SECRET=(.+)$/m)?.[1]?.trim();
if (!SECRET) throw new Error('.env 缺少 REGISTER_SECRET');
const deviceId = `regen-${Date.now()}`;
const proof = crypto.createHmac('sha256', SECRET).update(deviceId).digest('hex');
const reg = await (await fetch(`${BASE}/api/auth/device`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ deviceId, deviceName: 'regen-sample', proof }),
})).json();
if (!reg.token) throw new Error(`设备注册失败：${JSON.stringify(reg).slice(0, 200)}`);
const H = { Authorization: `Bearer ${reg.token}`, 'Content-Type': 'application/json' };

const t0 = Date.now();
const compressed = `/tmp/regen-${skill}.jpg`;
execFileSync('sips', ['-Z', '2048', '-s', 'format', 'jpeg', '-s', 'formatOptions', '85', src, '--out', compressed], { stdio: 'ignore' });
const bytes = fs.readFileSync(compressed);
const hash = crypto.createHash('sha256').update(bytes).digest('hex');
const t = await (await fetch(`${BASE}/api/upload-ticket?ext=jpg&hash=${hash}`, { headers: H })).json();
if (!t.uploadUrl) throw new Error(`取票据失败 ${JSON.stringify(t).slice(0, 200)}`);
const put = await fetch(t.uploadUrl, { method: 'PUT', headers: { 'Content-Type': t.contentType }, body: bytes });
if (put.status !== 200) throw new Error(`PUT ${put.status}`);

const comp = await (await fetch(`${BASE}/api/compile`, {
  method: 'POST',
  headers: H,
  body: JSON.stringify({ skillId: skill, imageUrl: t.fileUrl, instruction }),
})).json();
if (!comp.prompt) throw new Error(`compile 失败 ${JSON.stringify(comp).slice(0, 300)}`);

const img = await (await fetch(`${BASE}/api/image`, {
  method: 'POST',
  headers: H,
  body: JSON.stringify({ prompt: comp.prompt, imageUrls: [t.fileUrl], size }),
})).json();
if (!img.urls?.length) throw new Error(`image 失败 ${JSON.stringify(img).slice(0, 300)}`);

const out = path.join(root, 'assets', 'skills', skill, 'assets', 'sample.jpg');
fs.mkdirSync(path.dirname(out), { recursive: true });
const res = await fetch(img.urls[0]);
fs.writeFileSync(out, Buffer.from(await res.arrayBuffer()));
execFileSync('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '85', out, '--out', out], { stdio: 'ignore' });
fs.rmSync(compressed, { force: true });
console.log(`[ok] ${skill} in ${((Date.now() - t0) / 1000).toFixed(0)}s -> ${out}`);
