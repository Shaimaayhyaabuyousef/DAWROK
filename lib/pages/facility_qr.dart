/// The facility QR shown on the facility home screen. Citizens scan it to
/// open the facility and join one of its queues. It only identifies the
/// facility; booking rules are still checked by Firestore.
String facilityQrPayload(String facilityId) =>
    'dawrok://facility/${Uri.encodeComponent(facilityId)}';

/// Returns the facility ID in a DAWROK facility QR, or null for any other
/// code. Older printed codes with extra path or query parts still work.
String? facilityIdFromQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'dawrok' || uri.host != 'facility') {
    return null;
  }
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first;
  return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ? id : null;
}
