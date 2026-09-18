import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/sex_position_model.dart';
import '../../../services/sex_positions_service.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/common/timed_confirm_dialog.dart';

class SexPositionPickerModal extends StatefulWidget {
  final ValueChanged<SexPositionModel>? onPositionSelected;
  final String initialCategory;

  const SexPositionPickerModal({
    super.key,
    this.onPositionSelected,
    this.initialCategory = 'All',
  });

  static Future<SexPositionModel?> show(
    BuildContext context, {
    ValueChanged<SexPositionModel>? onPositionSelected,
    String initialCategory = 'All',
  }) {
    return showModalBottomSheet<SexPositionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SexPositionPickerModal(
        onPositionSelected: onPositionSelected,
        initialCategory: initialCategory,
      ),
    );
  }

  static Future<void> showPositionDetails(
    BuildContext context,
    SexPositionModel position, {
    ValueChanged<SexPositionModel>? onPositionSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181222) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag indicator
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFFF758C)),
                          const SizedBox(width: 5),
                          Text(
                            position.category,
                            style: const TextStyle(
                              color: Color(0xFFFF758C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable position content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Illustration Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF261D33) : const Color(0xFFF9F6FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: position.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: position.imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF758C),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(
                                      Icons.favorite_outline_rounded,
                                      size: 48,
                                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.favorite_outline_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        position.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        position.description,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tips Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFA18CD1).withValues(alpha: 0.1)
                              : const Color(0xFFFF758C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Explore and communicate with your partner. Adjust angles, pacing, and support pillows for optimal comfort and pleasure.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions: [Cancel] + [Pick This Position]
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 48,
                        borderRadius: 16,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
                          label: const Text(
                            'Pick This Position',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(ctx);
                            if (onPositionSelected != null) {
                              onPositionSelected(position);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  State<SexPositionPickerModal> createState() => _SexPositionPickerModalState();
}

class _SexPositionPickerModalState extends State<SexPositionPickerModal> {
  final SexPositionsService _service = SexPositionsService();
  final TextEditingController _searchController = TextEditingController();

  late String _selectedCategory;
  List<SexPositionModel> _filteredPositions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadData() async {
    await _service.loadPositions();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final results = _service.searchPositions(
      _searchController.text,
      category: _selectedCategory,
    );
    setState(() {
      _filteredPositions = results;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showPositionDetails(SexPositionModel position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181222) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag indicator
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_rounded, size: 13, color: Color(0xFFFF758C)),
                          const SizedBox(width: 5),
                          Text(
                            position.category,
                            style: const TextStyle(
                              color: Color(0xFFFF758C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable position content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Illustration Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF261D33) : const Color(0xFFF9F6FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFFF758C).withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: position.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: position.imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF758C),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(
                                      Icons.favorite_outline_rounded,
                                      size: 48,
                                      color: isDark ? Colors.white30 : Colors.grey.shade400,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.favorite_outline_rounded,
                                    size: 48,
                                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        position.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        position.description,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.55,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tips Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFA18CD1).withValues(alpha: 0.1)
                              : const Color(0xFFFF758C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF758C).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: Color(0xFFFF758C),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Explore and communicate with your partner. Adjust angles, pacing, and support pillows for optimal comfort and pleasure.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions: [Cancel] + [Pick This Position]
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SecondaryCancelButton(
                        label: 'Cancel',
                        height: 48,
                        borderRadius: 16,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
                          label: const Text(
                            'Pick This Position',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(ctx);
                            if (widget.onPositionSelected != null) {
                              widget.onPositionSelected!(position);
                            }
                            Navigator.pop(context, position);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _service.getCategories();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181222) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sex Position Picker',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.deepCharcoal,
                        ),
                      ),
                      Text(
                        '${_filteredPositions.length} positions available',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: AppTextField(
              controller: _searchController,
              hintText: 'Search positions by name or style...',
              prefixIcon: Icons.search_rounded,
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                      child: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                    )
                  : null,
              isDark: isDark,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips Row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = categories[idx];
                final isSelected = _selectedCategory == cat;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategory = cat;
                    });
                    _applyFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.deepCharcoal),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Positions Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF758C)),
                  )
                : _filteredPositions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: isDark ? Colors.white30 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No positions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.deepCharcoal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing your search or choosing a different category.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _filteredPositions.length,
                        itemBuilder: (ctx, idx) {
                          final position = _filteredPositions[idx];
                          return _buildPositionCard(position, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(SexPositionModel position, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPositionDetails(position);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF221A2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? const Color(0xFFA18CD1).withValues(alpha: 0.2)
                : const Color(0xFFFF758C).withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Illustration
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  width: double.infinity,
                  color: isDark ? const Color(0xFF2B2039) : const Color(0xFFFAF7FB),
                  padding: const EdgeInsets.all(6),
                  child: position.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: position.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Color(0xFFFF758C),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.favorite_outline_rounded,
                            size: 30,
                            color: isDark ? Colors.white30 : Colors.grey.shade400,
                          ),
                        )
                      : Icon(
                          Icons.favorite_outline_rounded,
                          size: 30,
                          color: isDark ? Colors.white30 : Colors.grey.shade400,
                        ),
                ),
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF758C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      position.category,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF758C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Position Name
                  Text(
                    position.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.deepCharcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
