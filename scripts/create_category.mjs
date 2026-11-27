import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Admin-only helper. Run with GOOGLE_APPLICATION_CREDENTIALS set locally.
// Example: node scripts/create_category.mjs medical "Medical Services"
const [id, name] = process.argv.slice(2);
if (!id || !/^[a-z0-9_-]{2,40}$/.test(id) || !name) {
  throw new Error('Usage: node scripts/create_category.mjs <slug> <display name>');
}
initializeApp({ credential: applicationDefault() });
await getFirestore().collection('facility_categories').doc(id).create({
  name: name.trim(), isActive: true, createdAt: FieldValue.serverTimestamp(),
});
console.log('Category created:', id);
