import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../providers/anniversary_provider.dart';

/// Senior Collapsible Anniversary & Love Counter Glassmorphism Card
class CollapsibleAnniversaryCard extends StatefulWidget {
  final bool initialExpanded;

  const CollapsibleAnniversaryCard({
    super.key,
    this.initialExpanded = false,
  });

  @override
  State<CollapsibleAnniversaryCard> createState() =>
      _CollapsibleAnniversaryCardState();
}

class _CollapsibleAnniversaryCardState
    extends State<CollapsibleAnniversaryCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnniversaryProvider>();
    final hasDate = provider.hasAnniversaryDate;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.softRose.withValues(alpha: 0.88),
            AppColors.lavender.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.softRose.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: hasDate ? _toggleExpanded : () => _showDatePickerDialog(context, provider),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row (Visible in both Collapsed and Expanded states)
                  _buildHeaderRow(context, provider, hasDate),

                  if (!hasDate) ...[
                    const SizedBox(height: 14),
                    _buildSetDatePrompt(context, provider),
                  ] else if (_isExpanded) ...[
                    const SizedBox(height: 16),
                    _buildExpandedContent(context, provider),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Single-line Header Row
  Widget _buildHeaderRow(
    BuildContext context,
    AnniversaryProvider provider,
    bool hasDate,
  ) {
    return Row(
      children: [
        // Heart Icon Badge
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),

        // Title / Counter Text in Header (Expanded to consume remaining middle space)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Love Counter',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              if (hasDate)
                Selector<AnniversaryProvider, int>(
                  selector: (_, p) => p.totalDaysTogether,
                  builder: (context, totalDays, _) {
                    return Text(
                      '$totalDays Days Together',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              else
                const Text(
                  'Set Anniversary Date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Live Ticking Seconds Pill
        if (hasDate)
          Selector<AnniversaryProvider, int>(
            selector: (_, p) => p.secondsTogetherRemainder,
            builder: (context, seconds, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${seconds.toString().padLeft(2, '0')}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Expand / Collapse Arrow Toggle
        if (hasDate) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: _toggleExpanded,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: _isExpanded ? 'Collapse' : 'Expand details',
          ),
        ],
      ],
    );
  }

  /// Detailed View shown when Expanded
  Widget _buildExpandedContent(
    BuildContext context,
    AnniversaryProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),

        // Official Anniversary Date Row
        if (provider.anniversaryDate != null) ...[
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Anniversary: ${DateFormat('MMMM d, yyyy').format(provider.anniversaryDate!)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Detailed Duration Breakdown
        Selector<AnniversaryProvider, String>(
          selector: (_, p) =>
              '${p.yearsTogether}y ${p.monthsTogether}m ${p.daysTogetherRemainder}d ${p.hoursTogetherRemainder}h ${p.minutesTogetherRemainder}m ${p.secondsTogetherRemainder}s',
          builder: (context, durationString, _) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                durationString,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Progress Bar toward Next Anniversary
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${provider.daysUntilNextAnniversary} days until ${provider.nextAnniversaryYearNumber}${_getOrdinalSuffix(provider.nextAnniversaryYearNumber)} Anniversary',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(provider.progressToNextAnniversary * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: provider.progressToNextAnniversary,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap card header to collapse',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetDatePrompt(BuildContext context, AnniversaryProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When did your love story begin?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set your official anniversary date to unlock live relationship counter & milestone timeline.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showDatePickerDialog(context, provider);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.softRose,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text(
            'Set Anniversary Date',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePickerDialog(
    BuildContext context,
    AnniversaryProvider provider,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      await provider.setAnniversaryDate(picked);
    }
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
