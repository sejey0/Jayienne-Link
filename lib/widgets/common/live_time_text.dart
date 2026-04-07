import 'dart:async';
import 'package:flutter/material.dart';

class LiveTimeText extends StatefulWidget {
  final String Function() textBuilder;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Duration interval;

  const LiveTimeText({
    super.key,
    required this.textBuilder,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.interval = const Duration(seconds: 1),
  });

  @override
  State<LiveTimeText> createState() => _LiveTimeTextState();
}

class _LiveTimeTextState extends State<LiveTimeText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(LiveTimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) {
        setState(() {});
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
    return Text(
      widget.textBuilder(),
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
