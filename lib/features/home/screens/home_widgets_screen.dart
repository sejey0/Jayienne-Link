import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/home_widget_service.dart';
import '../widgets/couple_hero_card.dart';

class HomeWidgetsScreen extends StatefulWidget {
  const HomeWidgetsScreen({super.key});

  @override
  State<HomeWidgetsScreen> createState() => _HomeWidgetsScreenState();
}

class _HomeWidgetsScreenState extends State<HomeWidgetsScreen> {
  bool _selectedExpandedMode = false;
  int _pinnedCount = 0;
  bool _isPinning = false;

  @override
  void initState() {
    super.initState();
    _loadWidgetState();
  }

  Future<void> _loadWidgetState() async {
    final isExpanded = await HomeWidgetService.instance.getWidgetExpanded();
    final count = await HomeWidgetService.instance.getPinnedWidgetCount();
    if (!mounted) return;
    setState(() {
      _selectedExpandedMode = isExpanded;
      _pinnedCount = count;
    });
    await HomeWidgetService.instance.syncFromContext(context);
  }

  Future<void> _selectMode(bool expanded) async {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedExpandedMode = expanded;
    });
    await HomeWidgetService.instance.setWidgetExpanded(expanded);
    if (!mounted) return;
    await HomeWidgetService.instance.syncFromContext(
      context,
      overrideExpanded: expanded,
      forceCapture: true,
    );
  }

  Future<void> _handleAddOrUpdateWidget() async {
    if (_isPinning) return;
    HapticFeedback.mediumImpact();
    setState(() => _isPinning = true);

    try {
      await HomeWidgetService.instance.syncFromContext(
        context,
        overrideExpanded: _selectedExpandedMode,
        forceCapture: true,
      );

      final countBefore =
          await HomeWidgetService.instance.getPinnedWidgetCount();

      if (!mounted) return;
      if (countBefore > 0) {
        await HomeWidgetService.instance.setWidgetExpanded(
          _selectedExpandedMode,
        );
        if (!mounted) return;
        SnackbarHelper.showSuccess(
          context,
          _selectedExpandedMode
              ? 'Home screen widget updated to Unhidden (Expanded) card!'
              : 'Home screen widget updated to Hidden (Compact) card!',
        );
      } else {
        final pinned = await HomeWidgetService.instance.requestPinWidget(
          context,
          isExpanded: _selectedExpandedMode,
        );
        if (!mounted) return;
        if (pinned) {
          SnackbarHelper.showSuccess(
            context,
            'Confirm in the system prompt to place the Couple Card on your Home Screen.',
          );
        } else {
          _showManualWidgetGuideDialog();
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      final updatedCount =
          await HomeWidgetService.instance.getPinnedWidgetCount();
      if (mounted) {
        setState(() => _pinnedCount = updatedCount);
      }
    } finally {
      if (mounted) {
        setState(() => _isPinning = false);
      }
    }
  }

  Future<void> _handleForcePinDialog() async {
    HapticFeedback.mediumImpact();
    final pinned = await HomeWidgetService.instance.requestPinWidget(
      context,
      isExpanded: _selectedExpandedMode,
    );
    if (!mounted) return;
    if (pinned) {
      SnackbarHelper.showSuccess(
        context,
        'Confirm in the system prompt to pin the Couple Card widget.',
      );
    } else {
      _showManualWidgetGuideDialog();
    }
  }

  void _showManualWidgetGuideDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1F162B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softRose.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.widgets_rounded,
                  color: AppColors.softRose,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add Widget to Home Screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your widget data is synced for offline use. If the system pin prompt did not appear automatically on your launcher:\n\n'
                '1. Go to your phone Home Screen and long-press an empty space.\n'
                '2. Tap Widgets and select Jayienne Link.\n'
                '3. Drag the Couple Hero Card onto your Home Screen.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text(
                      'Got It',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.widgets_rounded,
              color: AppColors.softRose,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Home Screen Widgets',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_pinnedCount > 0)
            IconButton(
              tooltip: 'Pin another widget',
              onPressed: _handleForcePinDialog,
              icon: const Icon(Icons.add_to_home_screen_rounded),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Select Widget Card Style',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // Style Selector Cards (Compact/Hidden vs Expanded/Unhidden)
            Row(
              children: [
                Expanded(
                  child: _WidgetModeOptionCard(
                    title: 'Compact Card',
                    subtitle: 'Hidden details (Default)',
                    icon: Icons.unfold_less_rounded,
                    isSelected: !_selectedExpandedMode,
                    onTap: () => _selectMode(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WidgetModeOptionCard(
                    title: 'Full Card',
                    subtitle: 'Unhidden full breakdown',
                    icon: Icons.unfold_more_rounded,
                    isSelected: _selectedExpandedMode,
                    onTap: () => _selectMode(true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Live Widget Preview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softRose.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedExpandedMode
                        ? 'Unhidden Mode'
                        : 'Hidden (Compact) Mode',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.softRose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live Interactive CoupleHeroCard Preview (Keyed by mode so selecting switches immediately)
            IgnorePointer(
              ignoring: false,
              child: CoupleHeroCard(
                key: ValueKey<bool>(_selectedExpandedMode),
                initialExpanded: _selectedExpandedMode,
              ),
            ),
            const SizedBox(height: 22),

            // Primary Action Button: Add / Apply to Home Screen
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isPinning ? null : _handleAddOrUpdateWidget,
                  icon: Icon(
                    _pinnedCount > 0
                        ? Icons.sync_rounded
                        : Icons.add_to_home_screen_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _pinnedCount > 0
                        ? 'Apply Selected Card to Home Screen'
                        : 'Show Selected Widget on Home Screen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _WidgetModeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WidgetModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.softRose.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.45)
                : AppColors.softRose.withValues(alpha: 0.25),
            width: 1.4,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.softRose,
                  size: 22,
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.grey.shade500),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : (isDark ? Colors.white70 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

