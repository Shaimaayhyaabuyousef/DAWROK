import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Prepares catalog reads before the caller starts its transaction writes.
class QueueCatalog {
  QueueCatalog(
    this.serviceRef,
    this.serviceSnapshot,
    this.name,
    this.queueId,
    this.count,
    this.counters,
  );
  final DocumentReference<Map<String, dynamic>> serviceRef;
  final DocumentSnapshot<Map<String, dynamic>> serviceSnapshot;
  final String name, queueId;
  final int count;
  final List<DocumentSnapshot<Map<String, dynamic>>> counters;
  String get serviceId => serviceRef.id;

  static Future<QueueCatalog> prepare(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> facility,
    String queueId,
    String name,
    int count,
    int oldCount,
  ) async {
    final id = sha256
        .convert(utf8.encode(name.trim().toLowerCase()))
        .toString();
    final serviceRef = facility.collection('services').doc(id);
    final service = await tx.get(serviceRef);
    if (service.exists && service.data()?['isActive'] != true) {
      throw StateError('This service is inactive.');
    }
    final counters = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (var w = 1; w <= math.max(count, oldCount); w++) {
      counters.add(
        await tx.get(facility.collection('counters').doc('${queueId}_$w')),
      );
    }
    return QueueCatalog(
      serviceRef,
      service,
      service.data()?['name'] as String? ?? name.trim(),
      queueId,
      count,
      counters,
    );
  }

  void write(Transaction tx) {
    if (!serviceSnapshot.exists) {
      tx.set(serviceRef, {
        'name': name,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    for (var i = 0; i < counters.length; i++) {
      final old = counters[i];
      tx.set(old.reference, {
        'queueId': queueId,
        'windowNumber': i + 1,
        'name': old.data()?['name'] ?? 'Window ${i + 1}',
        'floor': old.data()?['floor'] ?? '',
        'isActive': i < count,
        'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
