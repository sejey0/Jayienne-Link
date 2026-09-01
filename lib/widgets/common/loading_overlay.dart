import 'dart:ui';
import 'package:flutter/material.dart';
import 'romantic_loading_indicator.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message = 'Please wait...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
                child: Center(
                  child: RomanticLoadingIndicator(
                    size: 64,
                    message: message,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
