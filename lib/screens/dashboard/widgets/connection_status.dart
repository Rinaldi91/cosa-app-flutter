import 'package:flutter/material.dart';
import 'dart:async';

class ConnectionStatus extends StatefulWidget {
  final bool isConnected;
  final String deviceName;

  const ConnectionStatus(
      {super.key, required this.isConnected, required this.deviceName});

  @override
  _ConnectionStatusState createState() => _ConnectionStatusState();
}

class _ConnectionStatusState extends State<ConnectionStatus> {
  bool _isVisible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.isConnected) {
      _startBlinking();
    }
  }

  void _startBlinking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _isVisible = !_isVisible;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ConnectionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && _timer != null) {
      _timer!.cancel();
      setState(() {
        _isVisible = true;
      });
    } else if (!widget.isConnected && _timer == null) {
      _startBlinking();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedOpacity(
          opacity: widget.isConnected ? 1.0 : (_isVisible ? 1.0 : 0.3),
          duration: const Duration(milliseconds: 500),
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isConnected ? Colors.green : Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedOpacity(
          opacity: widget.isConnected ? 1.0 : (_isVisible ? 1.0 : 0.3),
          duration: const Duration(milliseconds: 500),
          child: Text(
            widget.isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: widget.isConnected ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }
}
