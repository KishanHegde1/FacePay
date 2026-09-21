import 'package:flutter_tts/flutter_tts.dart';

abstract interface class PaymentFeedbackService {
  Future<void> speakThanks();
  Future<void> stop();
}

/// Uses the phone's text-to-speech engine. Speech is deliberately best-effort:
/// a missing/disabled voice engine must never change payment state or navigation.
class DevicePaymentFeedbackService implements PaymentFeedbackService {
  DevicePaymentFeedbackService({FlutterTts? textToSpeech})
    : _textToSpeech = textToSpeech ?? FlutterTts();

  final FlutterTts _textToSpeech;

  @override
  Future<void> speakThanks() async {
    try {
      await _textToSpeech.stop();
      await _textToSpeech.setLanguage('en-IN');
      await _textToSpeech.setSpeechRate(0.45);
      await _textToSpeech.setPitch(1.0);
      await _textToSpeech.setVolume(1.0);
      await _textToSpeech.speak('Thanks, bro.');
    } catch (_) {
      // The visual confirmation remains available when TTS is unavailable.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _textToSpeech.stop();
    } catch (_) {
      // Nothing to recover: this only releases optional audio feedback.
    }
  }
}
