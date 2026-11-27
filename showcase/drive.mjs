// Seeds the emulators, then opens each screen of the showcase build and
// captures it at phone size. Run inside `firebase emulators:exec`.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { chromium } from 'playwright';

const ROOT = path.resolve('build/web');
const OUT = path.resolve('shots');
fs.mkdirSync(OUT, { recursive: true });
const log = fs.createWriteStream(path.join(OUT, 'console.txt'));

initializeApp({ projectId: 'demo-dawrok' });
const db = getFirestore();
const PASS = 'Showcase-Pass-2026';
const login = p => 'p970' + p.slice(1) + '@login.dawrok.invalid';

// Trusted provisioning, as scripts/provision_facility.mjs does.
await db.collection('facility_categories').doc('banks').set({ name: 'البنوك', isActive: true, createdAt: FieldValue.serverTimestamp() });
const owner = await getAuth().createUser({ email: login('0599100001'), password: PASS, displayName: 'بنك فلسطين' });
const number = '100245';
await db.doc('admin_sequences/facility_numbers').set({ last: 100245 });
await db.collection('facilities').doc(number).set({
  facilityNumber: number, ownerUid: owner.uid, name: 'بنك فلسطين — فرع الرمال', categoryId: 'banks',
  phone: '0599100001', address: 'غزة، الرمال، شارع عمر المختار', isActive: true, isOnline: false,
  nextWindowNumber: 0, createdAt: FieldValue.serverTimestamp(),
});
await db.collection('users').doc(owner.uid).set({
  uid: owner.uid, email: login('0599100001'), phone: '0599100001', role: 'facility', status: 'active',
  facilityId: number, displayName: 'بنك فلسطين — فرع الرمال', createdAt: FieldValue.serverTimestamp(),
});

// static server for the web build
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.svg': 'image/svg+xml', '.css': 'text/css' };
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let f = path.join(ROOT, p);
  if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(ROOT, 'index.html');
  res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
}).listen(8080);

const browser = await chromium.launch({ args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] });
async function open(query, name) {
  const ctx = await browser.newContext({ viewport: { width: 393, height: 852 }, deviceScaleFactor: 2, locale: 'ar', permissions: ['camera'] });
  const page = await ctx.newPage();
  page.on('console', m => log.write(`[${name}] ${m.text()}\n`));
  page.on('pageerror', e => log.write(`[${name}] ERROR ${e.message}\n`));
  await page.goto(`http://127.0.0.1:8080/?${query}`);
  await page.addStyleTag({ content: '.firebase-emulator-warning{display:none!important}' });
  return { ctx, page };
}
async function until(page, ok, ms) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const t = await page.title();
    if (ok(t)) return t;
    if (t.startsWith('failed')) return t;
    await page.waitForTimeout(500);
  }
  return 'timeout:' + (await page.title());
}

const seed = await open('seed=1', 'seed');
const s = await until(seed.page, t => t === 'seed-done' || t.startsWith('seed-failed'), 240000);
log.write(`SEED RESULT: ${s}\n`);
await seed.ctx.close();
for (const a of ['serve', 'callnext']) {
  const x = await open(`role=stf&action=${a}`, a);
  log.write(`${a}: ${await until(x.page, t => t === 'action-done', 60000)}\n`);
  await x.ctx.close();
}

const screens = [
  ['cit', 'home_screen', 'c_home'], ['cit', 'facilities_screen', 'c_facilities'], ['cit', 'details', 'c_details'],
  ['cit', 'active_queues_screen', 'c_queues'], ['cit', 'ticket', 'c_ticket'], ['cit', 'citizen_notifications', 'c_notifications'],
  ['cit', 'citizen_points', 'c_points'], ['cit', 'profile_screen', 'c_profile'], ['cit', 'citizen_settings', 'c_settings'],
  ['cit', 'citizen_report', 'c_report'], ['cit', 'who_we_are', 'c_who'],
  ['fac', 'facility_home_screen', 'f_home'], ['fac', 'facility_queues_screen', 'f_queues'], ['fac', 'facility_staff_screen', 'f_staff'],
  ['fac', 'facility_search_screen', 'f_search'], ['fac', 'facility_profile_screen', 'f_profile'],
  ['stf', 'employee_home_screen', 's_home'], ['stf', 'scanner', 's_scanner'], ['stf', 'employee_profile_screen', 's_profile'],
];
for (const [role, screen, name] of screens) {
  const { ctx, page } = await open(`role=${role}&screen=${screen}`, name);
  const r = await until(page, t => t === 'ready', 60000);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: path.join(OUT, name + '.png') });
  log.write(`${name}: ${r}\n`);
  await ctx.close();
}

// Screens before signing in.
{
  const { ctx, page } = await open('screen=splash', 'e_splash');
  await page.waitForTimeout(2200);
  await page.screenshot({ path: path.join(OUT, 'e_splash.png') });
  await ctx.close();
}
{
  const { ctx, page } = await open('screen=onboarding', 'e_onb');
  await until(page, t => t === 'ready', 60000);
  await page.waitForTimeout(1000);
  for (const n of [1, 2, 3]) {
    if (n > 1) {
      await page.mouse.move(60, 300); await page.mouse.down();
      await page.mouse.move(340, 300, { steps: 14 }); await page.mouse.up();
      await page.waitForTimeout(1800);
    }
    await page.screenshot({ path: path.join(OUT, `e_onb${n}.png`) });
  }
  await ctx.close();
}
for (const [screen, name] of [['login', 'e_login'], ['signup', 'e_signup'], ['citizen_id_verification', 'e_idv'], ['employee_login_screen', 'e_staff_login'], ['employee_join_screen', 'e_staff_join']]) {
  const { ctx, page } = await open(`screen=${screen}`, name);
  await until(page, t => t === 'ready', 60000);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, name + '.png') });
  await ctx.close();
}

// The window officer types turn numbers: a wrong one, then the called one.
{
  const { ctx, page } = await open('role=stf&screen=scanner', 's_typed');
  await until(page, t => t === 'ready', 60000);
  await page.waitForTimeout(1500);
  for (const [num, name] of [['3', 's_wrong'], ['2', 's_verified']]) {
    await page.mouse.click(196, 175);
    await page.waitForTimeout(500);
    await page.keyboard.press('Control+A');
    await page.keyboard.type(num);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3500);
    await page.screenshot({ path: path.join(OUT, name + '.png') });
  }
  await ctx.close();
}

// The turn alert: Sara watches her home while the window calls her.
const sara = await open('role=cit&screen=home_screen', 'alert');
await until(sara.page, t => t === 'ready', 60000);
await sara.page.waitForTimeout(1500);
const call = await open('role=stf&action=callnext', 'callnext');
log.write(`callnext: ${await until(call.page, t => t === 'action-done', 60000)}\n`);
await call.ctx.close();
await sara.page.waitForTimeout(3000);
await sara.page.screenshot({ path: path.join(OUT, 'c_alert.png') });
await sara.ctx.close();
for (const [screen, name] of [['active_queues_screen', 'c_queues_called'], ['home_screen', 'c_home_called'], ['ticket', 'c_ticket_called'], ['facility_search_screen', 'f_search_after'], ['facility_home_screen', 'f_home_after']]) {
  const role = name.startsWith('f_') ? 'fac' : 'cit';
  const after = await open(`role=${role}&screen=${screen}`, name);
  await until(after.page, t => t === 'ready', 60000);
  await after.page.waitForTimeout(2500);
  await after.page.screenshot({ path: path.join(OUT, name + '.png') });
  await after.ctx.close();
}

await browser.close();
server.close();
log.end();
