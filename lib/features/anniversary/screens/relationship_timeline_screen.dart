import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
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
        title: const Text('Relationship Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.refreshAll(),
            tooltip: 'Refresh timeline',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _showEditAnniversaryDialog(context, provider),
            tooltip: 'Edit anniversary date',
          ),
        ],
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
                icon: Icons.auto_awesome_rounded,
                value: '${provider.milestones.length}',
                label: 'Memories',
                color: AppColors.softRose,
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.favorite_rounded,
                value: '${stats.totalTouches}',
                label: 'Touches Sent',
                color: AppColors.lavender,
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.photo_library_rounded,
                value: '${stats.photosShared}',
                label: 'Photos Shared',
                color: Colors.amber.shade700,
              ),
              _buildStatMetricItem(
                context,
                icon: Icons.map_rounded,
                value: '${stats.distanceTraveledKm}',
                label: 'km Traveled',
                color: Colors.teal,
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
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
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
                // Category Icon Node Circle
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cat.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cat.color.withValues(alpha: 0.4),
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
          const SizedBox(width: 12),

          // Right Card Container
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
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
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(item.eventDate),
                          style: TextStyle(
                            color: cat.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
    DateTime selectedDate = DateTime.now();
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
                    const SizedBox(height: 12),

                    // Category Selection Chips
                    Text(
                      'Category',
                      style: Theme.of(modalCtx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: MilestoneCategory.values.map((cat) {
                        final isSelected = selectedCategory == cat;
                        final textColor = isSelected
                            ? Colors.white
                            : (Theme.of(modalCtx).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87);

                        return ChoiceChip(
                          avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                          label: Text(cat.label),
                          selected: isSelected,
                          selectedColor: cat.color,
                          backgroundColor: Theme.of(modalCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          labelStyle: TextStyle(
                            color: textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              selectedCategory = cat;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Trigger
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.softRose),
                        const SizedBox(width: 10),
                        Text(
                          'Date: ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: modalCtx,
                              initialDate: selectedDate,
                              firstDate: DateTime(1980),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) {
                              setModalState(() {
                                selectedDate = d;
                              });
                            }
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
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
                                      ScaffoldMessenger.of(modalCtx).showSnackBar(
                                        const SnackBar(content: Text('Please enter a memory title.')),
                                      );
                                      return;
                                    }

                                    try {
                                      final success = await annProvider.addMilestone(
                                        title: title,
                                        description: descriptionController.text.trim(),
                                        category: selectedCategory,
                                        eventDate: selectedDate,
                                        imageFile: selectedImageFile,
                                      );

                                      if (modalCtx.mounted && success) {
                                        Navigator.pop(modalCtx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Memory saved successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (modalCtx.mounted) {
                                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to save memory: ${e.toString().replaceAll('Exception: ', '')}'),
                                            backgroundColor: Colors.red.shade700,
                                            duration: const Duration(seconds: 4),
                                          ),
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
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Memory?'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.id != null) {
                await provider.deleteMilestone(item.id!);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
