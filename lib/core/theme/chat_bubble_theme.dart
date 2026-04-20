import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ChatBubbleThemeStyle {
  final String key;
  final String label;
  final Color lightBubble;
  final Color darkBubble;
  final Color accentColor;

  const ChatBubbleThemeStyle({
    required this.key,
    required this.label,
    required this.lightBubble,
    required this.darkBubble,
    required this.accentColor,
  });

  Color bubbleColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBubble : lightBubble;
  }

  Color textColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.deepCharcoal;
  }
}

class ChatBubbleThemes {
  static const String capybara = 'capybara';
  static const String qoobee = 'qoobee';
  static const String panda = 'panda';

  static const List<ChatBubbleThemeStyle> all = [
    ChatBubbleThemeStyle(
      key: capybara,
      label: 'Capybara',
      lightBubble: Color(0xFFF6E3D3),
      darkBubble: Color(0xFF5C463A),
      accentColor: Color(0xFFB07B55),
    ),
    ChatBubbleThemeStyle(
      key: qoobee,
      label: 'Qoobee',
      lightBubble: Color(0xFFFFE1C7),
      darkBubble: Color(0xFF8C5A2B),
      accentColor: Color(0xFFFFB26B),
    ),
    ChatBubbleThemeStyle(
      key: panda,
      label: 'Panda',
      lightBubble: Color(0xFFE5E7EB),
      darkBubble: Color(0xFF3B3D42),
      accentColor: Color(0xFF8A8D93),
    ),
  ];

  static ChatBubbleThemeStyle resolve(String? key) {
    return all.firstWhere(
      (theme) => theme.key == key,
      orElse: () => all.first,
    );
  }
}
