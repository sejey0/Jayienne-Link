import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/milestone_model.dart';
import '../../../providers/anniversary_provider.dart';

/// Interactive Relationship Memory Timeline Screen
class RelationshipTimelineScreen extends StatefulWidget {
  const RelationshipTimelineScreen({super.key});

  @override
  State<RelationshipTimelineScreen> createState() =>
      _RelationshipTimelineScreenState();
}

class _RelationshipTimelineScreenState
    extends State<RelationshipTimelineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnniversaryProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnniversaryProvider>();
    final milestones = provider.milestones;
    final stats = provider.coupleStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relationship Timeline',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.softRose, AppColors.lavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.refreshAll();
            },
            tooltip: 'Refresh timeline',
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showEditAnniversaryDialog(context, provider);
              },
              tooltip: 'Edit anniversary date',
            ),
        ],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemoryBottomSheet(context, provider),
        backgroundColor: AppColors.softRose,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Add Memory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. Top Relationship Statistics Summary Dashboard
              _buildStatsDashboard(context, provider, stats),

              const SizedBox(height: 12),

              // 2. Timeline List or Empty Placeholder State
              if (provider.isLoading && milestones.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (milestones.isEmpty)
                _buildEmptyTimelineState(context, provider)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                    vertical: AppDimensions.spacingMd,
                  ),
                  itemCount: milestones.length,
                  itemBuilder: (context, index) {
                    final item = milestones[index];
                    final isFirst = index == 0;
                    final isLast = index == milestones.length - 1;

                    return _buildTimelineNodeItem(
                      context,
                      provider,
                      item,
                      isFirst,
                      isLast,
                    );
                  },
                ),
              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  /// Header Statistics Dashboard Widget
  Widget _buildStatsDashboard(
    BuildContext context,
    AnniversaryProvider provider,
    CoupleStatsModel stats,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.spacingMd),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetricItem(
                context,
                icon: Icons.auto_stories_rounded,
                value: '${provider.milestones.length}',
                label: 'Memories',
                gradientColors: const [Color(0xFFEC407A), Color(0xFF8E24AA)],
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.favorite_rounded,
                value: '${stats.totalTouches}',
                label: 'Touches Sent',
                gradientColors: const [Color(0xFFFF5252), Color(0xFFD81B60)],
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.photo_library_rounded,
                value: '${stats.photosShared}',
                label: 'Photos Shared',
                gradientColors: const [Color(0xFFF06292), Color(0xFF9C27B0)],
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.location_on_rounded,
                value: '${stats.distanceTraveledKm}',
                label: 'km Traveled',
                gradientColors: const [Color(0xFFFF4081), Color(0xFFAB47BC)],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetricItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradientColors,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  /// Vertical Timeline Item with Node Connector & Category Card
  Widget _buildTimelineNodeItem(
    BuildContext context,
    AnniversaryProvider provider,
    MilestoneModel item,
    bool isFirst,
    bool isLast,
  ) {
    final cat = item.category;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline Connector Line & Icon Node
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Top Connecting Line
                Expanded(
                  child: Container(
                    width: 3,
                    color: isFirst ? Colors.transparent : AppColors.softRose.withValues(alpha: 0.3),
                  ),
                ),
                // Category Icon Node Big Circle Dot
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: cat.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: cat.gradientColors.first.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(cat.icon, color: Colors.white, size: 20),
                ),
                // Bottom Connecting Line
                Expanded(
                  child: Container(
                    width: 3,
                    color: isLast ? Colors.transparent : AppColors.softRose.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          // Horizontal connector line: node → card (matches vertical timeline line)
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 16,
              height: 2.5,
              decoration: BoxDecoration(
                color: AppColors.softRose.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Right Card Container
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: cat.gradientColors.first.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Date Header Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cat.gradientColors.first.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 12, color: cat.gradientColors.first),
                            const SizedBox(width: 4),
                            Text(
                              item.displayCategoryLabel,
                              style: TextStyle(
                                color: cat.gradientColors.first,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.eventDate != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            DateFormat('MMM d, yyyy').format(item.eventDate!),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                        onSelected: (val) {
                          if (val == 'delete') {
                            _confirmDeleteMilestone(context, provider, item);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                SizedBox(width: 8),
                                Text('Delete Memory', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Description if present
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],

                  // Photo Thumbnail preview if attached
                  if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showImageZoomDialog(context, item.photoUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: item.photoUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTimelineState(BuildContext context, AnniversaryProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Icon(Icons.timeline_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No memories added yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture your special moments, trips, first dates, and relationship milestones together.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddMemoryBottomSheet(context, provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softRose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Memory'),
          ),
        ],
      ),
    );
  }

  /// Add Memory Modal Bottom Sheet UI
  Future<void> _showAddMemoryBottomSheet(
    BuildContext context,
    AnniversaryProvider provider,
  ) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final customCategoryController = TextEditingController();
    DateTime? selectedDate;
    MilestoneCategory selectedCategory = MilestoneCategory.specialMoment;
    File? selectedImageFile;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Relationship Memory',
                          style: Theme.of(modalCtx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title Input
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Memory Title *',
                        hintText: 'e.g. Our First Date at Sunset Park',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(modalCtx).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        // Separated Quick Custom Category Action Pill
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setModalState(() {
                              selectedCategory = MilestoneCategory.custom;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: selectedCategory == MilestoneCategory.custom
                                  ? const LinearGradient(
                                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: selectedCategory == MilestoneCategory.custom
                                  ? null
                                  : AppColors.coral.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selectedCategory == MilestoneCategory.custom
                                    ? Colors.transparent
                                    : AppColors.coral.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                              boxShadow: selectedCategory == MilestoneCategory.custom
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF758C).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_rounded,
                                  size: 15,
                                  color: selectedCategory == MilestoneCategory.custom
                                      ? Colors.white
                                      : AppColors.coral,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '+ Custom',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: selectedCategory == MilestoneCategory.custom
                                        ? Colors.white
                                        : AppColors.coral,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Big Circle Dot Category Selector (Predefined only — Custom via header pill)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Predefined Category Circle Dots
                          ...MilestoneCategory.values
                              .where((cat) => cat != MilestoneCategory.custom)
                              .map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _buildCategoryDotItem(
                                cat: cat,
                                isSelected: selectedCategory == cat,
                                onTap: () {
                                  setModalState(() {
                                    selectedCategory = cat;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Custom Category Name Input Field (Appears when Custom is selected)
                    if (selectedCategory == MilestoneCategory.custom) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customCategoryController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Custom Category Name *',
                          hintText: 'e.g. Cooking Together, First Movie, Road Trip...',
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.coral),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: AppColors.coral.withValues(alpha: 0.06),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Optional Date Picker Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(modalCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedDate != null
                              ? AppColors.softRose.withValues(alpha: 0.6)
                              : Theme.of(modalCtx).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedDate != null
                                ? Icons.calendar_today_rounded
                                : Icons.calendar_today_outlined,
                            color: selectedDate != null ? AppColors.softRose : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedDate != null
                                      ? 'Date: ${DateFormat('MMMM d, yyyy').format(selectedDate!)}'
                                      : 'Date (Optional)',
                                  style: TextStyle(
                                    fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.w500,
                                    color: selectedDate != null ? null : Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (selectedDate == null)
                                  Text(
                                    'No specific date selected',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedDate != null) ...[
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              tooltip: 'Clear Date',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setModalState(() {
                                  selectedDate = null;
                                });
                              },
                            ),
                            TextButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(1980),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) {
                                  setModalState(() {
                                    selectedDate = d;
                                  });
                                }
                              },
                              child: const Text('Change'),
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(1980),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null) {
                                  setModalState(() {
                                    selectedDate = d;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Date'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description Input
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Story (Optional)',
                        hintText: 'Write down what made this moment special...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Attachment Picker Container
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (picked != null) {
                          setModalState(() {
                            selectedImageFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(modalCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(modalCtx).dividerColor,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: selectedImageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(selectedImageFile!, fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_rounded, color: AppColors.softRose, size: 32),
                                  SizedBox(height: 6),
                                  Text(
                                    'Attach Photo (Optional)',
                                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    Consumer<AnniversaryProvider>(
                      builder: (ctx, annProvider, child) {
                        return SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.softRose,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: annProvider.isSaving
                                ? null
                                : () async {
                                     final title = titleController.text.trim();
                                     if (title.isEmpty) {
                                       SnackbarHelper.showError(
                                         modalCtx,
                                         'Please enter a memory title.',
                                       );
                                       return;
                                     }

                                     final customName = selectedCategory == MilestoneCategory.custom
                                         ? customCategoryController.text.trim()
                                         : null;
                                     if (selectedCategory == MilestoneCategory.custom && (customName == null || customName.isEmpty)) {
                                       SnackbarHelper.showError(
                                         modalCtx,
                                         'Please enter a name for your custom category.',
                                       );
                                       return;
                                     }

                                     try {
                                       final success = await annProvider.addMilestone(
                                         title: title,
                                         description: descriptionController.text.trim(),
                                         category: selectedCategory,
                                         customCategoryName: customName,
                                         eventDate: selectedDate,
                                         imageFile: selectedImageFile,
                                       );

                                       if (modalCtx.mounted && success) {
                                         Navigator.pop(modalCtx);
                                         SnackbarHelper.showSuccess(
                                           context,
                                           'Memory saved successfully!',
                                         );
                                       }
                                     } catch (e) {
                                       if (modalCtx.mounted) {
                                         SnackbarHelper.showError(
                                           modalCtx,
                                           'Failed to save memory: ${e.toString().replaceAll('Exception: ', '')}',
                                         );
                                       }
                                     }
                                   },
                            child: annProvider.isSaving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Save Memory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showImageZoomDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Zoomable image
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),

              // X close button — inside image, top-right
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditAnniversaryDialog(
    BuildContext context,
    AnniversaryProvider provider,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: provider.anniversaryDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      await provider.setAnniversaryDate(date);
    }
  }

  void _confirmDeleteMilestone(
    BuildContext context,
    AnniversaryProvider provider,
    MilestoneModel item,
  ) {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1427) : Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Memory?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.deepCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "${item.title}"? This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFD81B60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (item.id != null) {
                          await provider.deleteMilestone(item.id!);
                          if (context.mounted) {
                            SnackbarHelper.showSuccess(context, 'Memory deleted');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDotItem({
    required MilestoneCategory cat,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSelected
                        ? cat.gradientColors
                        : [
                            cat.gradientColors.first.withValues(alpha: 0.2),
                            cat.gradientColors.last.withValues(alpha: 0.2),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isSelected
                        ? cat.gradientColors.first
                        : cat.gradientColors.first.withValues(alpha: 0.35),
                    width: isSelected ? 2.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cat.gradientColors.first
                          .withValues(alpha: isSelected ? 0.5 : 0.15),
                      blurRadius: isSelected ? 10 : 4,
                      spreadRadius: isSelected ? 1 : 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    cat.icon,
                    size: 24,
                    color: isSelected ? Colors.white : cat.gradientColors.first,
                  ),
                ),
              ),
              if (isSelected)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cat.gradientColors.first,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: cat.gradientColors.first.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 66,
            child: Text(
              cat.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? cat.gradientColors.first : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
