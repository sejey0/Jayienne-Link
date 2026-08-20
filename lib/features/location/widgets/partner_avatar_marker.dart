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

  IconData _getBatteryIcon(int? level, BatteryState? state) {
    if (state == BatteryState.charging) {
      return Icons.battery_charging_full_rounded;
    }
    if (level == null) return Icons.battery_unknown_rounded;
    if (level <= 15) return Icons.battery_1_bar_rounded;
    if (level <= 45) return Icons.battery_3_bar_rounded;
    if (level <= 75) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Color _getBatteryColor(int? level, BatteryState? state) {
    if (state == BatteryState.charging) return Colors.greenAccent;
    if (level == null) return Colors.grey;
    if (level <= 20) return AppColors.error;
    if (level <= 50) return AppColors.warning;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final batteryLvlText = widget.batteryLevel != null ? '${widget.batteryLevel}%' : '--%';
    final batteryColor = _getBatteryColor(widget.batteryLevel, widget.batteryState);

    final accent = widget.accentColor ?? (widget.isSelected ? AppColors.softRose : AppColors.lavender);
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
            // Battery level badge floating on top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: batteryColor.withValues(alpha: 0.6), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getBatteryIcon(widget.batteryLevel, widget.batteryState),
                    color: batteryColor,
                    size: 11,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    batteryLvlText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Avatar Ring with Rotated Direction Arrow
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

                // Glowing animated Avatar Ring
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.25),
                      border: Border.all(
                        color: accent,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: SmartProfileImage(
                          imageUrl: widget.photoUrl,
                          width: 40,
                          height: 40,
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
              ],
            ),

            // Bottom Map Pin Triangle Indicator
            CustomPaint(
              size: const Size(10, 5),
              painter: _PinTrianglePainter(
                color: accent,
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
