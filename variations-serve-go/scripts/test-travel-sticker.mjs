#!/usr/bin/env node
// travel-memory-sticker-card 在 Go 端的端到端效果验证
// 流程：设备注册 → 上传测试照片 → compile → image → 下载结果
// 用法：node scripts/test-travel-sticker.mjs [测试照片路径] [size 像素串，默认 1600*1067]
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE = (process.env.BASE_URL ?? 'http://127.0.0.1:8788').replace(/\/$/, '');
const here = path.dirname(fileURLToPath(import.meta.url));

// 从 .env 读 REGISTER_SECRET
const envText = fs.readFileSync(path.join(here, '..', '.env'), 'utf8');
const SECRET = envText.match(/^REGISTER_SECRET=(.+)$/m)?.[1]?.trim();
if (!SECRET) throw new Error('.env 缺少 REGISTER_SECRET');

// 测试照片：默认用 scenic-postcard-editorial 的旅行样图
const photoPath = process.argv[2] ?? path.join(
  here, '..', 'assets', 'skills',
  'scenic-postcard-editorial', 'assets', 'sample.jpg',
);
const photo = fs.readFileSync(photoPath);
const hash = crypto.createHash('sha256').update(photo).digest('hex');
console.log(`测试照片：${photoPath}（${photo.length} bytes）`);

async function req(method, urlPath, body, token) {
  const res = await fetch(`${BASE}${urlPath}`, {
    method,
    headers: {
      ...(body == null ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = undefined; }
  return { status: res.status, json, text };
}

// 1. 设备注册
const deviceId = `sticker-test-${Date.now()}`;
const proof = crypto.createHmac('sha256', SECRET).update(deviceId).digest('hex');
const reg = await req('POST', '/api/auth/device', { deviceId, deviceName: 'sticker-test', proof });
if (reg.status !== 200 || !reg.json?.token) throw new Error(`注册失败: ${reg.text}`);
const TOKEN = reg.json.token;
console.log(`token 获取成功：${TOKEN.slice(0, 12)}…`);

// 2. skills 列表确认新 skill 已被发现
const skills = await req('GET', '/api/skills', null, TOKEN);
const card = skills.json?.find?.((c) => c.id === 'travel-memory-sticker-card');
console.log(`skills 列表：${skills.json?.length ?? '?'} 个；新 skill ${card ? `已发现（displayName=${card.displayName}）` : '未发现！'}`);

// 3. 上传测试照片（内容寻址）
const ticket = await req('GET', `/api/upload-ticket?ext=jpg&hash=${hash}`, null, TOKEN);
if (ticket.status !== 200) throw new Error(`upload-ticket 失败: ${ticket.text}`);
const put = await fetch(ticket.json.uploadUrl, {
  method: 'PUT',
  headers: { 'Content-Type': ticket.json.contentType },
  body: photo,
});
if (put.status !== 200) throw new Error(`PUT 上传失败: ${put.status}`);
const imageUrl = ticket.json.fileUrl;
console.log(`照片已上传：uploads/${hash}.jpg`);

// 4. compile
console.log('\n== 编译中（qwen VL）… ==');
const t0 = Date.now();
const comp = await req('POST', '/api/compile', { skillId: 'travel-memory-sticker-card', imageUrl }, TOKEN);
if (comp.status !== 200) throw new Error(`compile 失败: ${comp.text}`);
const prompt = comp.json.prompt;
console.log(`编译成功（${Date.now() - t0}ms，${prompt.length} 字符）\n`);
console.log('----- 编译产物 -----');
console.log(prompt);
console.log('--------------------\n');
fs.writeFileSync(path.join(here, '..', 'data', 'test-sticker-prompt.txt'), prompt);

// 5. image（参考图 + 客户端 3:2 换算像素串；size 不被接受时回退不传）
const SIZE = process.argv[3] ?? '1600*1067';
console.log('== 生图中（qwen-image）… ==');
const t1 = Date.now();
let img = await req('POST', '/api/image', { prompt, imageUrls: [imageUrl], size: SIZE }, TOKEN);
let usedSize = SIZE;
if (img.status !== 200) {
  console.log(`size=${SIZE} 失败（${img.text.slice(0, 200)}），回退不传 size 重试…`);
  img = await req('POST', '/api/image', { prompt, imageUrls: [imageUrl] }, TOKEN);
  usedSize = 'auto';
}
if (img.status !== 200) throw new Error(`image 失败: ${img.text}`);
const outUrl = img.json.urls[0];
console.log(`生图成功（${Date.now() - t1}ms，size=${usedSize}）：${outUrl}`);

// 6. 下载结果
const outPath = path.join(here, '..', 'data', 'test-sticker-result.jpg');
const buf = Buffer.from(await (await fetch(outUrl)).arrayBuffer());
fs.writeFileSync(outPath, buf);
console.log(`结果已保存：${outPath}`);
