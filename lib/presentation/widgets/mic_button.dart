import 'package:flutter/material.dart';
import '../../utils/speech_helper.dart';

class MicButton extends StatefulWidget {
  final Function(String) onResult;
  final VoidCallback? onListeningStart;
  final VoidCallback? onListeningEnd;

  const MicButton({
    super.key, 
    required this.onResult,
    this.onListeningStart,
    this.onListeningEnd,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool _isListening = false;
  final SpeechHelper _speechHelper = SpeechHelper();

  void _handleMicPress() async {
    await _speechHelper.toggleListening(
      onResult: (text) {
        widget.onResult(text);
      },
      onListeningStateChanged: (listening) {
        if (mounted) {
          setState(() => _isListening = listening);
          if (listening) {
             widget.onListeningStart?.call();
          } else {
             widget.onListeningEnd?.call();
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: _isListening ? Colors.red : Colors.grey,
      ),
      onPressed: _handleMicPress,
      tooltip: 'Tap to speak',
    );
  }
}
