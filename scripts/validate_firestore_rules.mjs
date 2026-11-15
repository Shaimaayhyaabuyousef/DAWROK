import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

// Intentionally loads and compiles this rules file, unlike emulator start alone.
// The project is a demo emulator project; no production data is accessible.
const testEnv = await initializeTestEnvironment({
  projectId: 'demo-dawrok',
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
  },
});
try {
  const owner = testEnv.authenticatedContext('test-owner').firestore();
  const stranger = testEnv.authenticatedContext('test-stranger').firestore();
  const anonymous = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(owner.doc('users/test-owner').get());
  await assertFails(stranger.doc('users/test-owner').get());
  await assertFails(anonymous.doc('users/test-owner').get());
  console.log('Rules compiled; owner, stranger and anonymous access smoke tests passed.');
} finally {
  await testEnv.cleanup();
}
