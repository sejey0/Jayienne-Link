import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/smart_profile_image.dart';

/// Reusable partner map marker widget featuring partner photo, glowing accent border,
/// accuracy pulse ring, and a mini battery status badge.
class PartnerAvatarMarker extends StatefulWidget {
  final String? photoUrl;
  final String partnerName;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final bool isSelected;
  final VoidCallback? onTap;

  const PartnerAvatarMarker({
    super.key,
    this.photoUrl,
    required this.partnerName,
    this.batteryLevel,
    this.batteryState,
    this.isSelected = false,
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
    final batteryLvl = widget.batteryLevel ?? 100;
    final batteryColor = _getBatteryColor(widget.batteryLevel, widget.batteryState);

    return GestureDetector(
      onTap: widget.onTap,
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
                  size: 12,
                ),
                const SizedBox(width: 3),
                Text(
                  '$batteryLvl%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          // Glowing animated Avatar Ring
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lavender.withValues(alpha: 0.25),
                border: Border.all(
                  color: widget.isSelected ? AppColors.softRose : AppColors.lavender,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lavender.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: SmartProfileImage(
                    imageUrl: widget.photoUrl,
                    width: 44,
                    height: 44,
                    placeholder: Container(
                      color: AppColors.lavender.withValues(alpha: 0.3),
                      child: const Icon(Icons.person, color: AppColors.lavender, size: 24),
                    ),
                    errorWidget: Container(
                      color: AppColors.lavender.withValues(alpha: 0.3),
                      child: const Icon(Icons.person, color: AppColors.lavender, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Map Pin Triangle Indicator
          CustomPaint(
            size: const Size(12, 6),
            painter: _PinTrianglePainter(
              color: widget.isSelected ? AppColors.softRose : AppColors.lavender,
            ),
          ),
        ],
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
