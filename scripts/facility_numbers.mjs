// Only trusted provisioning and migration scripts allocate public numbers.
export async function allocateFacilityNumber(db, tx) {
  const sequence = db.doc('admin_sequences/facility_numbers');
  const snapshot = await tx.get(sequence);
  const last = snapshot.exists ? snapshot.get('last') : 99999;
  if (!Number.isSafeInteger(last) || last < 99999) {
    throw new Error('Invalid facility number sequence.');
  }
  for (let next = last + 1; next <= 999999; next++) {
    const number = String(next);
    const candidate = await tx.get(db.collection('facilities').doc(number));
    const assigned = await tx.get(db.collection('facilities')
      .where('facilityNumber', '==', number).limit(1));
    if (!candidate.exists && assigned.empty) {
      tx.set(sequence, {last: next});
      return number;
    }
  }
  throw new Error('No six-digit facility numbers remain.');
}
