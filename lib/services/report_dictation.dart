import 'package:speech_to_text/speech_to_text.dart';

/// Single recognizer per application; callbacks follow the current report screen.
class ReportDictation {
  ReportDictation._();
  static final instance = ReportDictation._();
  final _speech = SpeechToText();
  void Function(bool)? onListening;
  void Function(String)? onError;
  bool get listening => _speech.isListening;
  Future<void> start(void Function(String) onWords) async {
    final available = await _speech.initialize(
      onStatus: (_) => onListening?.call(_speech.isListening),
      onError: (_) => onError?.call(
        'Voice input stopped. Check microphone permission or type your description.',
      ),
    );
    if (!available)
      throw StateError(
        'Voice input is unavailable. Enable microphone and speech permissions, or type your description.',
      );
    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    onListening?.call(_speech.isListening);
  }

  Future<void> stop() => _speech.stop();
  void detach() {
    onListening = null;
    onError = null;
    _speech.cancel();
  }
}
