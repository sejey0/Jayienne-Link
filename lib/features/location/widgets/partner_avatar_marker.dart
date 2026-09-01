import 'dart:math' as math;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/smart_profile_image.dart';

/// Reusable partner map marker widget featuring partner photo, glowing accent border,
/// accuracy pulse ring, direction arrow indicator, and a mini battery status badge.
class PartnerAvatarMarker extends StatefulWidget {
  final String? photoUrl;
  final String partnerName;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final bool isCharging;
  final bool isOnline;
  final double? heading;
  final double? speed;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback? onTap;

  const PartnerAvatarMarker({
    super.key,
    this.photoUrl,
    required this.partnerName,
    this.batteryLevel,
    this.batteryState,
    this.isCharging = false,
    this.isOnline = true,
    this.heading,
    this.speed,
    this.isSelected = false,
    this.accentColor,
    this.onTap,
  });

  @override
  State<PartnerAvatarMarker> createState() => _PartnerAvatarMarkerState();
}

class _PartnerAvatarMarkerState extends State<PartnerAvatarMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getBatteryIcon(int? level, bool isCharging) {
    if (isCharging) {
      return Icons.battery_charging_full_rounded;
    }
    if (level == null) return Icons.battery_unknown_rounded;
    if (level <= 15) return Icons.battery_alert_rounded;
    if (level <= 40) return Icons.battery_2_bar_rounded;
    if (level <= 75) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Color _getBatteryColor(int? level, bool isCharging) {
    if (isCharging) return const Color(0xFF69F0AE);
    if (level == null) return Colors.grey;
    if (level <= 20) return AppColors.error;
    if (level <= 50) return AppColors.warning;
    return const Color(0xFF69F0AE);
  }

  @override
  Widget build(BuildContext context) {
    final isCharging = widget.isCharging || widget.batteryState == BatteryState.charging;
    final showBattery = widget.isOnline && widget.batteryLevel != null;
    final batteryLvlText = widget.batteryLevel != null
        ? '${widget.batteryLevel}%${isCharging ? ' ⚡' : ''}'
        : '';
    final batteryColor = _getBatteryColor(widget.batteryLevel, isCharging);

    final accent = widget.accentColor ??
        (widget.isSelected ? AppColors.softRose : AppColors.lavender);
    final bool showHeading = widget.heading != null &&
        widget.heading! >= 0 &&
        (widget.speed == null || widget.speed! > 0.5);

    return GestureDetector(
      onTap: widget.onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Live Battery Badge floating on top (Only rendered when online)
            if (showBattery) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E142B).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCharging
                        ? const Color(0xFF69F0AE)
                        : accent.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getBatteryIcon(widget.batteryLevel, isCharging),
                      color: batteryColor,
                      size: 11.5,
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      batteryLvlText,
                      style: TextStyle(
                        color: isCharging ? const Color(0xFF69F0AE) : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
            ],

            // 2. Avatar Profile Ring with Direction Arrow & Online Status Dot
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Direction Arrow Indicator (Rotated to match heading)
                if (showHeading)
                  Transform.rotate(
                    angle: (widget.heading! * (math.pi / 180)),
                    child: Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 15,
                        color: accent,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Glowing Animated Avatar Ring (Matches Profile Style)
                ScaleTransition(
                  scale: (widget.isSelected || widget.isOnline)
                      ? _pulseAnimation
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.isOnline
                            ? [
                                accent,
                                accent.withValues(alpha: 0.7),
                              ]
                            : [
                                Colors.grey.shade400,
                                Colors.grey.shade600,
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isOnline
                              ? accent.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: widget.isOnline ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: SmartProfileImage(
                          imageUrl: widget.photoUrl,
                          width: 42,
                          height: 42,
                          placeholder: Container(
                            color: accent.withValues(alpha: 0.3),
                            child: Icon(Icons.person, color: accent, size: 22),
                          ),
                          errorWidget: Container(
                            color: accent.withValues(alpha: 0.3),
                            child: Icon(Icons.person, color: accent, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Status Indicator Dot on bottom-right of avatar
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: widget.isOnline
                          ? const Color(0xFF00E676)
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      boxShadow: [
                        if (widget.isOnline)
                          BoxShadow(
                            color: const Color(0xFF00E676).withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 3. Bottom Map Pin Triangle Indicator
            CustomPaint(
              size: const Size(10, 5),
              painter: _PinTrianglePainter(
                color: widget.isOnline ? accent : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTrianglePainter extends CustomPainter {
  final Color color;

  _PinTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
