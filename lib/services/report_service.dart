import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ReportKind { app, facility }

enum ReporterRole { citizen, facility, employee }

class ReportAuthor {
  final String uid, facilityId;
  final ReporterRole role;
  const ReportAuthor(this.uid, this.role, {this.facilityId = ''});
}

class ReportFacility {
  final String id, name;
  const ReportFacility(this.id, this.name);
}

class ReportDraft {
  final ReportKind kind;
  final String message;
  final bool anonymous;
  final ReportFacility? facility;
  final Uint8List? photo;
  const ReportDraft({
    required this.kind,
    required this.message,
    required this.anonymous,
    this.facility,
    this.photo,
  });
}

abstract class ReportRepository {
  Future<ReportAuthor> author();
  Future<List<ReportFacility>> facilities();
  String newId();
  Future<void> submit(String id, ReportAuthor author, ReportDraft draft);
}

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  FirebaseReportRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? authentication,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = authentication ?? FirebaseAuth.instance;
  static const maxPhotoBytes = 200000;
  @override
  Future<ReportAuthor> author() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in to send a report.');
    final profile = (await db.collection('users').doc(uid).get()).data();
    if (profile?['role'] == 'citizen')
      return ReportAuthor(uid, ReporterRole.citizen);
    if (profile?['role'] == 'facility' && profile?['status'] == 'active') {
      return ReportAuthor(
        uid,
        ReporterRole.facility,
        facilityId: profile!['facilityId'] as String,
      );
    }
    final membership = (await db.collection('staff_memberships').doc(uid).get())
        .data();
    if (membership?['state'] == 'active') {
      return ReportAuthor(
        uid,
        ReporterRole.employee,
        facilityId: membership!['facilityId'] as String,
      );
    }
    throw StateError('Your account does not currently have access to reports.');
  }

  @override
  Future<List<ReportFacility>> facilities() async {
    final result = await db
        .collection('facilities')
        .where('isActive', isEqualTo: true)
        .get();
    final list = result.docs
        .map((d) => ReportFacility(d.id, d.data()['name'] as String? ?? ''))
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  String newId() => db.collection('reports').doc().id;
  @override
  Future<void> submit(String id, ReportAuthor author, ReportDraft draft) async {
    if (auth.currentUser?.uid != author.uid)
      throw StateError('Your account changed. Reopen this screen.');
    final message = draft.message.trim();
    if (message.runes.length < 10 || message.runes.length > 500)
      throw StateError('Enter a description between 10 and 500 characters.');
    if (draft.kind == ReportKind.facility &&
        (author.role != ReporterRole.citizen || draft.facility == null)) {
      throw StateError(
        'Select a facility. Only citizens can send facility reports.',
      );
    }
    if (draft.photo != null &&
        (draft.photo!.isEmpty || draft.photo!.length > maxPhotoBytes))
      throw StateError('Choose a photo smaller than 200 KB.');
    final ref = db.collection('reports').doc(id);
    await db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        if (existing.data()?['uid'] != author.uid)
          throw StateError('Invalid report reference.');
        return; // A retry after a lost acknowledgement must not duplicate the report.
      }
      tx.set(ref, {
        'uid': author.uid,
        'reporterRole': author.role.name,
        'reporterFacilityId': author.facilityId,
        'type': draft.kind.name,
        'facilityId': draft.kind == ReportKind.facility
            ? draft.facility!.id
            : '',
        'facilityName': draft.kind == ReportKind.facility
            ? draft.facility!.name
            : '',
        'message': message,
        'anonymous': draft.anonymous,
        'hasPhoto': draft.photo != null,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (draft.photo != null)
        tx.set(ref.collection('attachments').doc('photo'), {
          'bytes': Blob(draft.photo!),
          'contentType': 'image/jpeg',
          'createdAt': FieldValue.serverTimestamp(),
        });
    });
  }
}
