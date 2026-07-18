import 'dart:async';

import 'package:flutter/material.dart';

class IpodStatusBar extends StatefulWidget {
  const IpodStatusBar({super.key});

  @override
  State<IpodStatusBar> createState() => _IpodStatusBarState();
}

class _IpodStatusBarState extends State<IpodStatusBar> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return IgnorePointer(
      child: SizedBox(
        height: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.wifi_rounded, color: Color(0xD9FFFFFF), size: 15),
                  SizedBox(width: 5),
                  Icon(
                    Icons.battery_5_bar_rounded,
                    color: Color(0xD9FFFFFF),
                    size: 17,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
