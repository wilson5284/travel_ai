// lib/widgets/typing_indicator.dart
import 'package:flutter/material.dart';
import 'dart:async'; // Import for Timer

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  int _dotCount = 0;
  String _message = 'AI is thinking'; // Initial message
  Timer? _dotAnimationTimer;
  Timer? _messageRotationTimer;

  // List of messages to cycle through
  final List<String> _loadingMessages = [
    'AI is thinking',
    'Planning your adventure',
    'Checking destinations',
    'Gathering travel tips',
    'Composing a thoughtful response',
  ];
  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();
    _startMessageRotation();
  }

  void _startDotAnimation() {
    _dotAnimationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4; // Cycles from 0 to 3 dots
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startMessageRotation() {
    _messageRotationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
          _message = _loadingMessages[_messageIndex];
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _dotAnimationTimer?.cancel(); // Cancel the dot animation timer
    _messageRotationTimer?.cancel(); // Cancel the message rotation timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dots = '.' * _dotCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(), // Keep the standard spinner for primary loading indication
        const SizedBox(height: 8),
        Text(
          '$_message$dots',
          style: const TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}