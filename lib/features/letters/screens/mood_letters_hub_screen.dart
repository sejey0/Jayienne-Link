import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/couple_provider.dart';
import '../../../providers/debug_provider.dart';
import '../../../providers/mood_letters_provider.dart';
import '../../../providers/user_provider.dart';
import '../widgets/compose_letter_sheet.dart';
import 'received_letters_tab.dart';
import 'sent_letters_tab.dart';

class MoodLettersHubScreen extends StatefulWidget {
  const MoodLettersHubScreen({super.key});

  @override
  State<MoodLettersHubScreen> createState() => _MoodLettersHubScreenState();
}

class _MoodLettersHubScreenState extends State<MoodLettersHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initUserContext();
    });
  }

  Future<void> _initUserContext() async {
    final userProv = context.read<UserProvider>();
    final coupleProv = context.read<CoupleProvider>();
    final coupleId = userProv.coupleId ?? coupleProv.couple?.id ?? '';
    final myUid = userProv.user?.id.isNotEmpty == true
        ? userProv.user!.id
        : (userProv.user?.uid ?? '');
    final partner = coupleProv.partner;
    String partnerUid = partner?.id.isNotEmpty == true ? partner!.id : (partner?.uid ?? '');
    if (partnerUid.isEmpty && coupleProv.couple != null) {
      final ids = coupleProv.couple!.partnerIds;
      if (ids.isNotEmpty) {
        partnerUid = ids.firstWhere((id) => id != myUid, orElse: () => '');
      }
    }
    await context.read<MoodLettersProvider>().loadAll(
      coupleId: coupleId,
      myUserId: myUid,
      partnerUserId: partnerUid,
    );
  }

  Future<void> _handleManualRefresh() async {
    HapticFeedback.lightImpact();
    setState(() => _isRefreshing = true);
    await _initUserContext();
    if (mounted) {
      setState(() => _isRefreshing = false);
      final provider = context.read<MoodLettersProvider>();
      final total = provider.allLetters.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            total > 0 ? 'Letters refreshed ($total total)' : 'Letters refreshed',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCompose() async {
    HapticFeedback.lightImpact();
    final result = await ComposeLetterSheet.show(context);
    if (result == true && mounted) {
      final provider = context.read<MoodLettersProvider>();
      // In My POV, switch to Sent tab so user immediately sees their freshly created letter
      if (!provider.isPartnerPov) {
        _tabController.animateTo(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lettersProvider = context.watch<MoodLettersProvider>();
    final userProv = context.watch<UserProvider>();
    final coupleProv = context.watch<CoupleProvider>();

    final coupleId = userProv.coupleId ?? coupleProv.couple?.id ?? '';
    final myUid = userProv.user?.id.isNotEmpty == true
        ? userProv.user!.id
        : (userProv.user?.uid ?? '');
    final partner = coupleProv.partner;
    String partnerUid = partner?.id.isNotEmpty == true ? partner!.id : (partner?.uid ?? '');
    if (partnerUid.isEmpty && coupleProv.couple != null) {
      final ids = coupleProv.couple!.partnerIds;
      if (ids.isNotEmpty) {
        partnerUid = ids.firstWhere((id) => id != myUid, orElse: () => '');
      }
    }

    // Auto-sync context to provider when UserProvider or CoupleProvider loads
    if (coupleId.isNotEmpty &&
        (lettersProvider.coupleId != coupleId ||
            lettersProvider.myUserId != myUid ||
            lettersProvider.partnerUserId != partnerUid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          lettersProvider.syncContext(
            coupleId: coupleId,
            myUserId: myUid,
            partnerUserId: partnerUid,
          );
        }
      });
    }

    final unreadCount = lettersProvider.unreadCount;
    final isDebugMode = DebugProvider.isDebug;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.warmWhite,
      appBar: AppBar(
        title: const Text(
          'Mood Letters',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Explicit Refresh Button
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF758C),
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Letters',
            onPressed: _isRefreshing ? null : _handleManualRefresh,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2B47) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF758C).withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : AppColors.deepCharcoal,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Received'),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Color(0xFFFF758C),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.outbox_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Sent & Analytics'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Dev-Only Test POV Simulation Card
          if (isDebugMode) _buildDevPovBanner(context, isDark, lettersProvider),

          // Inbox Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ReceivedLettersTab(),
                SentLettersTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF758C).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openCompose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    lettersProvider.isPartnerPov ? 'Write as Partner' : 'Write Letter',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevPovBanner(BuildContext context, bool isDark, MoodLettersProvider provider) {
    final userProv = context.watch<UserProvider>();
    final coupleProv = context.watch<CoupleProvider>();
    final myUid = userProv.user?.id.isNotEmpty == true
        ? userProv.user!.id
        : (userProv.user?.uid ?? '');
    final partner = coupleProv.partner;
    String partnerUid = partner?.id.isNotEmpty == true ? partner!.id : (partner?.uid ?? '');
    if (partnerUid.isEmpty && coupleProv.couple != null) {
      final ids = coupleProv.couple!.partnerIds;
      if (ids.isNotEmpty) {
        partnerUid = ids.firstWhere((id) => id != myUid, orElse: () => '');
      }
    }

    final isPartnerPov = provider.isPartnerPov;
    final myName = userProv.user?.displayName.isNotEmpty == true
        ? userProv.user!.displayName
        : 'Me';
    final partnerName = (partner?.displayName.isNotEmpty == true)
        ? partner!.displayName
        : 'Partner';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A2C) : const Color(0xFFFFF6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPartnerPov
              ? const Color(0xFFA18CD1).withValues(alpha: 0.6)
              : const Color(0xFFFF758C).withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 15,
            color: isPartnerPov ? const Color(0xFFA18CD1) : const Color(0xFFFF758C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dev Mode POV',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Text(
                  isPartnerPov ? 'Simulating $partnerName' : 'Simulating $myName',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.deepCharcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Segmented POV Pill Toggle
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Me POV
                GestureDetector(
                  onTap: () {
                    if (!isPartnerPov) return;
                    HapticFeedback.lightImpact();
                    provider.setPartnerPov(false, myUserId: myUid, partnerUserId: partnerUid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to Your POV ($myName)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: !isPartnerPov
                          ? const LinearGradient(
                              colors: [Color(0xFFFF758C), Color(0xFFA18CD1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Me',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !isPartnerPov
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                // Partner POV
                GestureDetector(
                  onTap: () {
                    if (isPartnerPov) return;
                    HapticFeedback.lightImpact();
                    provider.setPartnerPov(true, myUserId: myUid, partnerUserId: partnerUid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched to Partner POV ($partnerName)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isPartnerPov
                          ? const LinearGradient(
                              colors: [Color(0xFFA18CD1), Color(0xFF7B1FA2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Partner',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPartnerPov
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
