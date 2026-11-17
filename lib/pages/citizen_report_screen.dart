import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'citizen_ui.dart';

class CitizenReportScreen extends StatefulWidget {
  const CitizenReportScreen({super.key});
  @override
  State<CitizenReportScreen> createState() => _CitizenReportScreenState();
}

class _CitizenReportScreenState extends State<CitizenReportScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _sent;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = _message.text.trim();
    if (uid == null || text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 10 characters.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final ref = await FirebaseFirestore.instance.collection('reports').add({
        'uid': uid,
        'message': text,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _sent = ref.id);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report could not be sent. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        'Contact administration',
        style: TextStyle(color: citizenSoftBlue, fontSize: 20),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_sent != null) ...[
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your report was submitted successfully.',
                textAlign: TextAlign.center,
              ),
              Text('Reference: $_sent', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                'Administration will review your request. Submitting a report does not automatically remove a booking restriction.',
              ),
            ] else ...[
              const Text(
                'Describe your issue or request a review of your booking restriction.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _message,
                minLines: 5,
                maxLines: 9,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Your message',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: citizenBlue),
                onPressed: _busy ? null : _send,
                child: Text(_busy ? 'Sending…' : 'Submit report'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
