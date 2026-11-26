import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/report_service.dart';
import '../services/report_photo.dart';
import '../services/report_dictation.dart';
import 'package:first_project/l10n/app_language.dart';

const _blue = Color(0xFF03A9F4);
const _ink = Color(0xFF202C3E);
const _muted = Color(0xFF94A5BF);
const _line = Color(0xFFDDF2FF);

/// Shared by citizens, facility owners and employees; permissions come from Firebase.
class ReportScreen extends StatefulWidget {
  final ReportRepository? repository;
  final Future<Uint8List?> Function(ImageSource)? photoPicker;
  const ReportScreen({super.key, this.repository, this.photoPicker});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

// Preserve old routes and callers, including points/restriction review.
class CitizenReportScreen extends ReportScreen {
  const CitizenReportScreen({super.key});
}

class _ReportScreenState extends State<ReportScreen> {
  late final ReportRepository _repository;
  final _description = TextEditingController();
  ReportAuthor? _author;
  ReportKind? _kind;
  ReportFacility? _facility;
  Uint8List? _photo;
  String? _loadError, _error, _sent, _submissionId;
  bool _busy = false, _picking = false, _anonymous = true, _listening = false;
  bool get _locked => _busy || _picking;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseReportRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final author = await _repository.author();
      if (!mounted) return;
      setState(() {
        _author = author;
        _kind = author.role == ReporterRole.citizen ? null : ReportKind.app;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _loadError =
              'Unable to load your account. Please sign in and try again.',
        );
    }
  }

  @override
  void dispose() {
    ReportDictation.instance.detach();
    _description.dispose();
    super.dispose();
  }

  String get _label => switch (_kind) {
    ReportKind.app => 'Report an issue with the app',
    ReportKind.facility => 'Facility Report',
    null => 'Select the type of report',
  };
  void _showError(Object error) {
    if (mounted)
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
  }

  Future<void> _chooseKind() async {
    final result = await showModalBottomSheet<ReportKind>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                tr('Select the type of report'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: _blue),
              title: Text(tr('Report an issue with the app')),
              onTap: () => Navigator.pop(context, ReportKind.app),
            ),
            if (_author!.role == ReporterRole.citizen)
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: _blue),
                title: Text(tr('Facility Report')),
                onTap: () => Navigator.pop(context, ReportKind.facility),
              ),
          ],
        ),
      ),
    );
    if (result != null && mounted)
      setState(() {
        _kind = result;
        _error = null;
        if (result == ReportKind.app) _facility = null;
      });
  }

  Future<void> _chooseFacility() async {
    final selected = await showModalBottomSheet<ReportFacility>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _FacilityPicker(repository: _repository),
    );
    if (selected != null && mounted) setState(() => _facility = selected);
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(tr('Take a photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await (widget.photoPicker ?? pickReportPhoto)(source);
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (_) {
      _showError(
        'Could not add this photo. Choose a JPEG or PNG, and check photo/camera permissions.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _dictate() async {
    final speech = ReportDictation.instance;
    if (_listening) {
      await speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final before = _description.text.trim();
    speech.onListening = (value) {
      if (mounted) setState(() => _listening = value);
    };
    speech.onError = _showError;
    try {
      await speech.start((words) {
        if (!mounted || _busy) return;
        final text = String.fromCharCodes(
          '${before.isEmpty ? '' : '$before '}$words'.runes.take(500),
        );
        _description.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        setState(() {});
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _send() async {
    if (_locked || _author == null) return;
    if (_kind == null) {
      _showError('Select the type of report.');
      return;
    }
    if (_kind == ReportKind.facility && _facility == null) {
      _showError('Select the facility you want to report.');
      return;
    }
    if (_description.text.trim().runes.length < 10) {
      _showError('Please enter at least 10 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ReportDictation.instance.stop();
      final id = _submissionId ??= _repository.newId();
      await _repository.submit(
        id,
        _author!,
        ReportDraft(
          kind: _kind!,
          message: _description.text,
          anonymous: _anonymous,
          facility: _facility,
          photo: _photo,
        ),
      );
      if (mounted)
        setState(() {
          _sent = id;
          _listening = false;
        });
    } catch (_) {
      _showError(
        'Your report could not be confirmed. Check your connection and try again; your description and photo are kept.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BoxDecoration _panel({
    double radius = 16,
    Color color = Colors.white,
    bool shadow = false,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _line),
    boxShadow: shadow
        ? const [
            BoxShadow(
              color: Color(0x0D03A9F4),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ]
        : null,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      leading: IconButton(
        tooltip: tr('Back'),
        onPressed: _busy ? null : () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 24,
        ),
      ),
      title: Text(
        tr('Report'),
        style: TextStyle(
          color: Color(0xFF64B9FA),
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(_loadError!), textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: Text(tr('Retry'))),
                    ],
                  ),
                )
              : _author == null
              ? const Center(child: CircularProgressIndicator())
              : _sent != null
              ? _success()
              : _form(),
        ),
      ),
    ),
  );
  Widget _form() => ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 45, 12, 30),
    children: [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _locked ? null : _chooseKind,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _panel(shadow: true),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: _panel(
                    radius: 12,
                    color: const Color(0xFFF0FAFF),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF008FD4),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    tr(_label),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFF7F9FB),
                  child: Icon(Icons.keyboard_arrow_down, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_kind == ReportKind.facility) ...[
        const SizedBox(height: 9),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            tr('FACILITY NAME'),
            style: TextStyle(
              color: Color(0xFF39485F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: InkWell(
            onTap: _locked ? null : _chooseFacility,
            child: Container(
              height: 65,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: AlignmentDirectional.centerStart,
              decoration: _panel(shadow: true),
              child: Text(
                tr(_facility?.name ?? 'facility name'),
                style: TextStyle(
                  color: _facility == null ? Colors.grey : _ink,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
      ] else
        const SizedBox(height: 42),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr('DESCRIPTION'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF39485F),
                ),
              ),
            ),
            Text(
              tr('${_description.text.runes.length} / 500'),
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 7),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 10),
        decoration: _panel(),
        child: Column(
          children: [
            SizedBox(
              height: 154,
              child: TextField(
                key: const ValueKey('report-description'),
                controller: _description,
                enabled: !_locked && !_listening,
                expands: true,
                maxLines: null,
                minLines: null,
                maxLength: 500,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = String.fromCharCodes(
                      newValue.text.runes.take(500),
                    );
                    return text == newValue.text
                        ? newValue
                        : TextEditingValue(
                            text: text,
                            selection: TextSelection.collapsed(
                              offset: text.length,
                            ),
                          );
                  }),
                ],
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: _ink, fontSize: 15, height: 1.5),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  hintText: _kind == ReportKind.app
                      ? 'Please describe the issue you experienced with the app in detail...'
                      : 'Please describe the incident, distribution delay, or facility irregularity in detail...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9DAEC7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            if (_photo != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _photo!,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    child: IconButton(
                      tooltip: tr('Remove photo'),
                      onPressed: _locked
                          ? null
                          : () => setState(() => _photo = null),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            const Divider(color: Color(0xFFEDF3F9), height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _locked ? null : _addPhoto,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    tr(_picking
                        ? 'Adding…'
                        : _photo == null
                        ? 'Add Photo'
                        : 'Change Photo'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF008FD4),
                    backgroundColor: const Color(0xFFF0FAFF),
                    side: const BorderSide(color: _line),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _listening
                      ? 'Stop voice input'
                      : 'Dictate description',
                  onPressed: _locked ? null : _dictate,
                  icon: Icon(
                    _listening ? Icons.stop_circle_outlined : Icons.mic_none,
                    color: _listening ? _blue : _muted,
                    size: 20,
                  ),
                ),
              ],
            ),
            if (_listening)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  tr('Listening… tap stop when finished.'),
                  style: TextStyle(color: _blue, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 46),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: _panel(radius: 12),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.visibility_off_outlined,
                color: Color(0xFF008FD4),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('Report Anonymously'),
                style: TextStyle(
                  color: Color(0xFF39485F),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              height: 30,
              child: Switch(
                value: _anonymous,
                activeTrackColor: _blue,
                activeThumbColor: Colors.white,
                onChanged: _locked
                    ? null
                    : (value) => setState(() => _anonymous = value),
              ),
            ),
          ],
        ),
      ),
      if (_anonymous)
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(18, 8, 18, 0),
          child: Text(
            tr('Your identity is hidden from the facility. Administration can access your account to follow up.'),
            style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 0),
          child: Text(
            tr(_error!),
            style: const TextStyle(color: Color(0xFFB42318), fontSize: 12),
          ),
        ),
      SizedBox(height: _anonymous ? 10 : 40),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4003A9F4),
              offset: Offset(0, 7),
              blurRadius: 12,
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _locked ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF49AAF2),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(53),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tr(_busy ? 'Sending…' : 'Send Report'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.send_outlined, size: 23),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _success() => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 56, color: _blue),
        const SizedBox(height: 20),
        Text(
          tr('Report sent successfully'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr('Administration will review your report.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 10),
        SelectableText(tr('Reference: $_sent'), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.maybePop(context),
          style: FilledButton.styleFrom(backgroundColor: _blue),
          child: Text(tr('Done')),
        ),
      ],
    ),
  );
}

class _FacilityPicker extends StatefulWidget {
  final ReportRepository repository;
  const _FacilityPicker({required this.repository});
  @override
  State<_FacilityPicker> createState() => _FacilityPickerState();
}

class _FacilityPickerState extends State<_FacilityPicker> {
  late Future<List<ReportFacility>> _facilities;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _facilities = widget.repository.facilities();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 10,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: tr('Search facilities'),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase().trim()),
            ),
            Expanded(
              child: FutureBuilder<List<ReportFacility>>(
                future: _facilities,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(
                          () => _facilities = widget.repository.facilities(),
                        ),
                        child: Text(tr('Unable to load facilities. Retry')),
                      ),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final rows = snapshot.data!
                      .where((f) => f.name.toLowerCase().contains(_query))
                      .toList();
                  if (rows.isEmpty)
                    return Center(child: Text(tr('No matching facilities.')));
                  return ListView(
                    children: rows
                        .map(
                          (f) => ListTile(
                            title: Text(tr(f.name)),
                            onTap: () => Navigator.pop(context, f),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
