import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

class SpeechHelper {
  static final SpeechHelper _instance = SpeechHelper._internal();
  factory SpeechHelper() => _instance;
  SpeechHelper._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInit = false;
  bool _isAvailable = false;

  Future<bool> initialize() async {
    if (_isInit) return _isAvailable;

    try {
      // Permission check
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          developer.log('Microphone permission denied', name: 'SpeechHelper');
          return false;
        }
      }

      _isAvailable = await _speech.initialize(
        onError: (e) => developer.log('Speech Error: $e', name: 'SpeechHelper', error: e),
        onStatus: (s) => developer.log('Speech Status: $s', name: 'SpeechHelper'),
      );
      _isInit = true;
      return _isAvailable;
    } catch (e) {
      developer.log('Speech Initialization Error: $e', name: 'SpeechHelper', error: e);
      return false;
    }
  }

  Future<void> toggleListening({
    required Function(String) onResult,
    required Function(bool) onListeningStateChanged,
  }) async {
    // If already listening, stop
    if (_speech.isListening) {
      await _speech.stop();
      onListeningStateChanged(false);
      return;
    }

    // Initialize if needed
    if (!_isInit) {
      final available = await initialize();
      if (!available) {
        onListeningStateChanged(false);
        return;
      }
    }

    // Start listening
    if (!_speech.isListening) {
      try {
        onListeningStateChanged(true);
        await _speech.listen(
          onResult: (result) {
            if (result.recognizedWords.isNotEmpty) {
              onResult(result.recognizedWords);
            }
            // If final result, stop listening state
            if (result.finalResult) {
               onListeningStateChanged(false);
            }
          },
          localeId: 'en_US',
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        );
      } catch (e) {
        developer.log('Error starting speech listen: $e', name: 'SpeechHelper', error: e);
        onListeningStateChanged(false);
      }
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
  
  bool get isListening => _speech.isListening;
}
