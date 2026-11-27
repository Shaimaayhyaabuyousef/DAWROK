// Use trusted Admin credentials. Input is a privately reviewed UID-to-phone list.
import { readFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { loginId } from './phone_login.mjs';

const args = process.argv.slice(2);
const inventory = args.includes('--inventory');
const apply = args.includes('--apply');
const file = args.find(a => !a.startsWith('--'));
if (inventory ? apply || file : !file) throw Error('Use --inventory, <mapping.json>, or <mapping.json> --apply');
if (Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST) !== Boolean(process.env.FIRESTORE_EMULATOR_HOST)) {
  throw Error('Configure both emulators together.');
}
initializeApp({projectId: process.env.FIREBASE_AUTH_EMULATOR_HOST ? 'demo-dawrok' : 'dawrok-f908e'});
const auth = getAuth(), db = getFirestore();
const accounts = new Map();
let token;
do {
  const page = await auth.listUsers(1000, token);
  for (const user of page.users) accounts.set(user.uid, user);
  token = page.pageToken;
} while (token);

if (inventory) {
  const rows = [];
  for (const user of accounts.values()) {
    const profile = (await db.collection('users').doc(user.uid).get()).data() ?? {};
    const staff = (await db.collection('staff_profiles').doc(user.uid).get()).data();
    const facility = profile.role === 'facility' && profile.facilityId
      ? (await db.collection('facilities').doc(profile.facilityId).get()).data() : null;
    rows.push({uid:user.uid, role:profile.role ?? (staff ? 'staff' : 'review'), phone: user.phoneNumber || profile.phone || staff?.phone || facility?.phone || '', reviewed:false});
  }
  console.log(JSON.stringify(rows, null, 2));
} else {
  const raw = await readFile(file);
  // Windows PowerShell 5 redirects to UTF-16 by default.
  const rows = JSON.parse(raw.toString(raw[0] === 255 && raw[1] === 254 ? 'utf16le' : 'utf8').replace(/^\uFEFF/, ''));
  if (!Array.isArray(rows)) throw Error('Expected an array of records');
  const owners = new Map(), seen = new Set(), plan = [];
  for (const row of rows) {
    const user = accounts.get(row.uid);
    if (!user || seen.has(row.uid) || row.reviewed !== true) throw Error('Unknown, duplicate or unreviewed uid: ' + row.uid);
    seen.add(row.uid);
    const alias = loginId(row.phone);
    if (owners.has(alias)) throw Error('Duplicate phone on UIDs ' + owners.get(alias) + ' and ' + row.uid);
    owners.set(alias, row.uid);
    let owner;
    try { owner = await auth.getUserByEmail(alias); } catch(e) { if (e.code !== 'auth/user-not-found') throw e; }
    if (owner && owner.uid !== row.uid) throw Error('Phone login already assigned to another UID: ' + row.uid);
    const needsPassword = !user.providerData.some(p => p.providerId === 'password');
    const password = needsPassword && row.passwordEnv ? process.env[row.passwordEnv] : undefined;
    if (needsPassword && (!password || password.length < 12)) throw Error('Provision an individual password through passwordEnv for UID ' + row.uid);
    plan.push({user, alias, password});
  }
  for (const uid of accounts.keys()) if (!seen.has(uid)) throw Error('Missing mapping for UID ' + uid);
  console.log('Validated accounts:', plan.length, apply ? '(apply)' : '(preview only)');
  if (apply) for (const {user, alias, password} of plan) {
    if (user.email !== alias || password) {
      await auth.updateUser(user.uid, {email:alias, emailVerified:false, ...(password ? {password} : {})});
      await auth.revokeRefreshTokens(user.uid);
    }
  }
}
