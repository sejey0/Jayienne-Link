import 'package:flutter/material.dart';

class ZodiacInfo {
  final String name;
  final String symbol;
  final String dateRange;
  final Color color;

  const ZodiacInfo({
    required this.name,
    required this.symbol,
    required this.dateRange,
    required this.color,
  });
}

const List<ZodiacInfo> kZodiacSigns = [
  ZodiacInfo(name: 'Aries',       symbol: '♈', dateRange: 'Mar 21 – Apr 19', color: Color(0xFFE53935)),
  ZodiacInfo(name: 'Taurus',      symbol: '♉', dateRange: 'Apr 20 – May 20', color: Color(0xFF43A047)),
  ZodiacInfo(name: 'Gemini',      symbol: '♊', dateRange: 'May 21 – Jun 20', color: Color(0xFFFDD835)),
  ZodiacInfo(name: 'Cancer',      symbol: '♋', dateRange: 'Jun 21 – Jul 22', color: Color(0xFF1E88E5)),
  ZodiacInfo(name: 'Leo',         symbol: '♌', dateRange: 'Jul 23 – Aug 22', color: Color(0xFFFB8C00)),
  ZodiacInfo(name: 'Virgo',       symbol: '♍', dateRange: 'Aug 23 – Sep 22', color: Color(0xFF8BC34A)),
  ZodiacInfo(name: 'Libra',       symbol: '♎', dateRange: 'Sep 23 – Oct 22', color: Color(0xFFEC407A)),
  ZodiacInfo(name: 'Scorpio',     symbol: '♏', dateRange: 'Oct 23 – Nov 21', color: Color(0xFF6D4C41)),
  ZodiacInfo(name: 'Sagittarius', symbol: '♐', dateRange: 'Nov 22 – Dec 21', color: Color(0xFF7B1FA2)),
  ZodiacInfo(name: 'Capricorn',   symbol: '♑', dateRange: 'Dec 22 – Jan 19', color: Color(0xFF455A64)),
  ZodiacInfo(name: 'Aquarius',    symbol: '♒', dateRange: 'Jan 20 – Feb 18', color: Color(0xFF039BE5)),
  ZodiacInfo(name: 'Pisces',      symbol: '♓', dateRange: 'Feb 19 – Mar 20', color: Color(0xFF5C6BC0)),
];

class ZodiacHelper {
  static ZodiacInfo? getZodiac(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final lower = name.trim().toLowerCase();
    for (final z in kZodiacSigns) {
      if (z.name.toLowerCase() == lower) return z;
    }
    return null;
  }
}
