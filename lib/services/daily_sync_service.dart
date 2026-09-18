import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synced Daily Love Note Model
class DailyQuoteItem {
  final String text;
  final String? author;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime updatedAt;

  const DailyQuoteItem({
    required this.text,
    this.author,
    this.updatedBy,
    this.updatedByName,
    required this.updatedAt,
  });

  factory DailyQuoteItem.fromMap(Map<dynamic, dynamic> map) {
    return DailyQuoteItem(
      text: map['text'] as String? ?? '',
      author: map['author'] as String?,
      updatedBy: map['updated_by'] as String?,
      updatedByName: map['updated_by_name'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      if (author != null) 'author': author,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// Synced Daily Bible Verse Model
class DailyBibleVerseItem {
  final String text;
  final String reference;
  final String theme;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime updatedAt;

  const DailyBibleVerseItem({
    required this.text,
    required this.reference,
    required this.theme,
    this.updatedBy,
    this.updatedByName,
    required this.updatedAt,
  });

  factory DailyBibleVerseItem.fromMap(Map<dynamic, dynamic> map) {
    return DailyBibleVerseItem(
      text: map['text'] as String? ?? '',
      reference: map['reference'] as String? ?? '',
      theme: map['theme'] as String? ?? 'Faith & Love',
      updatedBy: map['updated_by'] as String?,
      updatedByName: map['updated_by_name'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'reference': reference,
      'theme': theme,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// Service providing online-synced, super-random, non-repeating, unlimited
/// sweet daily notes & Bible verses for couples via Firebase Realtime Database.
class DailySyncService {
  static final DailySyncService instance = DailySyncService._();
  DailySyncService._();

  static const String _defaultUrl =
      'https://jayienne-link-51c81-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _rootNode = 'daily_sync';

  FirebaseDatabase? _database;
  final Random _random = Random();

  FirebaseDatabase get _db {
    if (_database != null) return _database!;
    try {
      if (Firebase.apps.isNotEmpty) {
        _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: _defaultUrl,
        );
      } else {
        _database = FirebaseDatabase.instance;
      }
    } catch (e) {
      _database = FirebaseDatabase.instance;
    }
    return _database!;
  }

  // ==========================================
  // REAL-TIME STREAMS
  // ==========================================

  /// Stream synced sweet daily quote for the given couple
  Stream<DailyQuoteItem> streamSweetQuote(String? coupleId) {
    if (coupleId == null || coupleId.isEmpty) {
      return Stream.fromFuture(_loadLocalQuote());
    }

    final quoteRef = _db.ref('$_rootNode/$coupleId/sweet_quote');

    return quoteRef.onValue.asyncMap((event) async {
      final val = event.snapshot.value;
      if (val != null && val is Map) {
        final item = DailyQuoteItem.fromMap(val);
        _saveLocalQuote(item);
        return item;
      }
      // If nothing in Firebase yet, pick an initial random quote and save it
      final initial = _generateNextQuote();
      await quoteRef.set(initial.toMap());
      _saveLocalQuote(initial);
      return initial;
    }).handleError((err) {
      debugPrint('⚠️ [DailySyncService] Quote stream fallback: $err');
      return _loadLocalQuote();
    });
  }

  /// Stream synced daily Bible verse for the given couple
  Stream<DailyBibleVerseItem> streamBibleVerse(String? coupleId) {
    if (coupleId == null || coupleId.isEmpty) {
      return Stream.fromFuture(_loadLocalVerse());
    }

    final verseRef = _db.ref('$_rootNode/$coupleId/bible_verse');

    return verseRef.onValue.asyncMap((event) async {
      final val = event.snapshot.value;
      if (val != null && val is Map) {
        final item = DailyBibleVerseItem.fromMap(val);
        _saveLocalVerse(item);
        return item;
      }
      // If nothing in Firebase yet, pick an initial random verse and save it
      final initial = _generateNextVerse();
      await verseRef.set(initial.toMap());
      _saveLocalVerse(initial);
      return initial;
    }).handleError((err) {
      debugPrint('⚠️ [DailySyncService] Verse stream fallback: $err');
      return _loadLocalVerse();
    });
  }

  // ==========================================
  // REROLL / SHUFFLE ACTIONS (SYNCED ONLINE)
  // ==========================================

  /// Reroll sweet daily note: picks an unrepeated random quote, writes to Firebase
  Future<DailyQuoteItem> rerollSweetQuote({
    String? coupleId,
    String? userId,
    String? userName,
  }) async {
    final nextQuote = _generateNextQuote(
      updatedBy: userId,
      updatedByName: userName,
    );

    // Save locally
    await _saveLocalQuote(nextQuote);

    // Sync online to Firebase if coupleId is valid
    if (coupleId != null && coupleId.isNotEmpty) {
      try {
        final quoteRef = _db.ref('$_rootNode/$coupleId/sweet_quote');
        await quoteRef.set(nextQuote.toMap());

        // Update history in Firebase to avoid repeats across devices
        final historyRef = _db.ref('$_rootNode/$coupleId/quote_history');
        final snap = await historyRef.get();
        List<String> history = [];
        if (snap.exists && snap.value is List) {
          history = List<String>.from(snap.value as List);
        }
        history.add(nextQuote.text);
        if (history.length > 50) history.removeRange(0, history.length - 50);
        await historyRef.set(history);
      } catch (e) {
        debugPrint('⚠️ [DailySyncService] Online quote sync notice: $e');
      }
    }

    return nextQuote;
  }

  /// Reroll daily Bible verse: picks an unrepeated random scripture, writes to Firebase
  Future<DailyBibleVerseItem> rerollBibleVerse({
    String? coupleId,
    String? userId,
    String? userName,
  }) async {
    final nextVerse = _generateNextVerse(
      updatedBy: userId,
      updatedByName: userName,
    );

    // Save locally
    await _saveLocalVerse(nextVerse);

    // Sync online to Firebase if coupleId is valid
    if (coupleId != null && coupleId.isNotEmpty) {
      try {
        final verseRef = _db.ref('$_rootNode/$coupleId/bible_verse');
        await verseRef.set(nextVerse.toMap());

        // Update history in Firebase
        final historyRef = _db.ref('$_rootNode/$coupleId/verse_history');
        final snap = await historyRef.get();
        List<String> history = [];
        if (snap.exists && snap.value is List) {
          history = List<String>.from(snap.value as List);
        }
        history.add(nextVerse.reference);
        if (history.length > 50) history.removeRange(0, history.length - 50);
        await historyRef.set(history);
      } catch (e) {
        debugPrint('⚠️ [DailySyncService] Online verse sync notice: $e');
      }
    }

    return nextVerse;
  }

  // ==========================================
  // UNLIMITED NO-REPEAT RANDOM GENERATION
  // ==========================================

  static final List<String> _recentQuoteHistory = [];
  static final List<String> _recentVerseHistory = [];

  DailyQuoteItem _generateNextQuote({String? updatedBy, String? updatedByName}) {
    // 30% chance to generate a procedural dynamic romantic quote for infinite variety
    final isProcedural = _random.nextInt(100) < 30;

    String selectedText;
    if (isProcedural) {
      selectedText = _generateProceduralQuote();
    } else {
      // Pick from curated list excluding recently shown quotes
      final available = _curatedRomanticQuotes
          .where((q) => !_recentQuoteHistory.contains(q))
          .toList();

      if (available.isEmpty) {
        // Clear history if exhausted to allow continuous cycling
        _recentQuoteHistory.clear();
        selectedText = _curatedRomanticQuotes[_random.nextInt(_curatedRomanticQuotes.length)];
      } else {
        selectedText = available[_random.nextInt(available.length)];
      }
    }

    // Keep history ring buffer of 45 items
    _recentQuoteHistory.add(selectedText);
    if (_recentQuoteHistory.length > 45) {
      _recentQuoteHistory.removeAt(0);
    }

    return DailyQuoteItem(
      text: selectedText,
      updatedBy: updatedBy,
      updatedByName: updatedByName,
      updatedAt: DateTime.now(),
    );
  }

  DailyBibleVerseItem _generateNextVerse({String? updatedBy, String? updatedByName}) {
    final available = _curatedBibleVerses
        .where((v) => !_recentVerseHistory.contains(v.reference))
        .toList();

    _CuratedVerse chosen;
    if (available.isEmpty) {
      _recentVerseHistory.clear();
      chosen = _curatedBibleVerses[_random.nextInt(_curatedBibleVerses.length)];
    } else {
      chosen = available[_random.nextInt(available.length)];
    }

    _recentVerseHistory.add(chosen.reference);
    if (_recentVerseHistory.length > 45) {
      _recentVerseHistory.removeAt(0);
    }

    return DailyBibleVerseItem(
      text: chosen.text,
      reference: chosen.reference,
      theme: chosen.theme,
      updatedBy: updatedBy,
      updatedByName: updatedByName,
      updatedAt: DateTime.now(),
    );
  }

  // ==========================================
  // PROCEDURAL ROMANTIC QUOTE GENERATOR
  // ==========================================

  static const List<String> _openers = [
    'Every time I look at you,',
    'No matter how far we are,',
    'In a world full of noise,',
    'From our very first sunrise together,',
    'When I think about our future,',
    'With every quiet moment we share,',
    'Every beat of my heart',
    'Loving you is like',
    'In your gentle smile,',
    'Whatever life throws our way,',
    'Whenever I close my eyes,',
    'Underneath all the stars in the night sky,',
    'Through every season of our lives,',
    'You walked into my life and',
    'Forever felt like just a word until',
  ];

  static const List<String> _middles = [
    'I am reminded that you are my greatest blessing and home.',
    'I see the kind of love people write poetry about.',
    'my heart finds its calm and my soul finds its peace.',
    'I realize our journey is the sweetest adventure ever told.',
    'every day is filled with warmth, laughter, and unbreakable devotion.',
    'your presence makes every ordinary day feel extraordinary.',
    'I know without doubt that we were meant to find each other.',
    'holding your hand is all the strength I will ever need.',
    'you turn all my doubts into peace and all my hopes into reality.',
    'our love only grows deeper, gentler, and more resilient.',
    'I find comfort knowing our two hearts beat to the exact same melody.',
    'you make this world a much softer and happier place to be.',
  ];

  static const List<String> _closers = [
    'I love you more than words could ever say.',
    'You are my today, my tomorrow, and my forever.',
    'My heart belongs to you, always and endlessly.',
    'Thank you for being my soulmate and my best friend.',
    'With you is where I always want to be.',
    'I would choose you all over again in every lifetime.',
    'You and me, together against the whole world.',
    'Always yours, in every single heartbeat.',
  ];

  String _generateProceduralQuote() {
    final o = _openers[_random.nextInt(_openers.length)];
    final m = _middles[_random.nextInt(_middles.length)];
    final c = _closers[_random.nextInt(_closers.length)];
    return '$o $m $c';
  }

  // ==========================================
  // LOCAL CACHING
  // ==========================================

  Future<void> _saveLocalQuote(DailyQuoteItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_sync_sweet_quote_cached', jsonEncode(item.toMap()));
    } catch (_) {}
  }

  Future<DailyQuoteItem> _loadLocalQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('daily_sync_sweet_quote_cached');
      if (str != null) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return DailyQuoteItem.fromMap(map);
      }
    } catch (_) {}
    return _generateNextQuote();
  }

  Future<void> _saveLocalVerse(DailyBibleVerseItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('daily_sync_bible_verse_cached', jsonEncode(item.toMap()));
    } catch (_) {}
  }

  Future<DailyBibleVerseItem> _loadLocalVerse() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('daily_sync_bible_verse_cached');
      if (str != null) {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return DailyBibleVerseItem.fromMap(map);
      }
    } catch (_) {}
    return _generateNextVerse();
  }

  // ==========================================
  // MASSIVE CURATED ROMANTIC QUOTE CATALOGUE
  // ==========================================

  static const List<String> _curatedRomanticQuotes = [
    'Every love story is beautiful, but ours is my favorite.',
    'Together is my favorite place in the whole world to be.',
    'In our shared world, love grows stronger and gentler every single day.',
    'You are my today, my tomorrow, and all of my forever.',
    'I loved you yesterday, love you still, always have, and always will.',
    'My heart is, and will forever remain, completely yours.',
    'Whatever our souls are made of, yours and mine are woven from the exact same thread.',
    'Distance means so little when someone means the whole universe to you.',
    'Two souls with but a single thought, two hearts that beat as one.',
    'Home isn\'t a place anymore; it is wherever you are.',
    'With you, every little moment becomes a beautiful lifelong memory in the making.',
    'You are my morning sun, my midnight moon, and every star in my sky.',
    'I look at you and see the rest of my life unfolding peacefully before my eyes.',
    'The best thing to hold onto in this unpredictable world is each other.',
    'Loving you is the easiest, sweetest, and most natural choice I make each morning.',
    'You are my favorite notification, my dearest thought, and my sweetest dream.',
    'Side by side or miles apart, we remain invisibly and unbreakably connected at heart.',
    'In your smile, I see something far more captivating and radiant than all the constellations.',
    'I never knew what true peace felt like until your hand found its way into mine.',
    'You make me fall in love with living all over again every single day.',
    'If I had a flower for every time I thought of you, I could walk through an eternal garden.',
    'You are the reason my heart feels so safe, so cherished, and so full of joy.',
    'I look at you and wonder what wonderful thing I did in life to deserve someone so pure.',
    'No matter how hectic life gets, one quiet hug from you resets my whole universe.',
    'You are my anchor in stormy waters and my sunshine on cloudy mornings.',
    'Forever is a very long time, but I wouldn\'t mind spending every single second with you.',
    'I love the way we laugh together over things that nobody else would understand.',
    'Your voice is my favorite sound, and your laughter is my favorite melody.',
    'Because of you, I laugh a little harder, cry a little less, and smile so much more.',
    'You don\'t just hold my hand; you hold my whole heart and every dream I have.',
    'I love you not only for who you are, but for who I am when I am with you.',
    'You are the sweetest chapter in my book of life, and I never want to finish reading.',
    'My favorite place to fall asleep is inside your thoughts and right next to your heart.',
    'You are my greatest prayer answered in the sweetest, most unexpected way.',
    'Every day spent with you is another reason to be thankful for life.',
    'We may not have it all together, but together we have everything that truly matters.',
    'You are the melody that plays softly in my heart all day long.',
    'I love you in the morning, in the afternoon, and all through the starlit night.',
    'Your love feels like coming home after the longest journey.',
    'There is nobody in this wide world I would rather share my days and dreams with.',
    'You are the poem my heart had been trying to write its entire existence.',
    'With every passing sunset, I love you more than the day before.',
    'You are the calm in my storm and the sweetest song in my heart.',
    'I found in you my lover, my best friend, my confidant, and my safe haven.',
    'Just knowing you exist in my corner makes the whole world feel lighter and kinder.',
    'Your happiness is my favorite mission, and your smile is my greatest reward.',
    'I never want to stop making memories, laughing at silly jokes, and holding hands with you.',
    'In a sea of people, my eyes will always search for you and only you.',
    'To the world you might just be one person, but to me, you are the entire world.',
    'You make me want to be the best version of myself, just so I can give you the love you deserve.',
    'I love how we can do absolutely nothing together and still have the best time.',
    'You are the missing puzzle piece that made my entire life make sense.',
    'Everything I never knew I needed in a partner, I found completely in you.',
    'Your love is a gentle reminder that true miracles still happen in this world.',
    'My heart knew it belonged to you long before my mind could catch up.',
    'I love you without knowing how, or when, or from where; I love you simply and completely.',
    'When you wrap your arms around me, everything in the world feels right again.',
    'You are my greatest comfort, my dearest friend, and my endless love.',
    'Every single day with you is a gift I promise to cherish with all my heart.',
    'No matter how far the road takes us, my heart will always point straight to you.',
  ];

  // ==========================================
  // MASSIVE CURATED BIBLE VERSE CATALOGUE
  // ==========================================

  static const List<_CuratedVerse> _curatedBibleVerses = [
    _CuratedVerse(
      reference: '1 Corinthians 13:4-7',
      theme: 'Love & Patience',
      text: 'Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs. Love does not delight in evil but rejoices with the truth. It always protects, always trusts, always hopes, always perseveres.',
    ),
    _CuratedVerse(
      reference: '1 Corinthians 13:13',
      theme: 'Eternal Love',
      text: 'And now these three remain: faith, hope, and love. But the greatest of these is love.',
    ),
    _CuratedVerse(
      reference: 'Song of Solomon 8:7',
      theme: 'Unquenchable Love',
      text: 'Many waters cannot quench love; rivers cannot sweep it away.',
    ),
    _CuratedVerse(
      reference: 'Colossians 3:14',
      theme: 'Bond of Unity',
      text: 'And over all these virtues put on love, which binds them all together in perfect unity.',
    ),
    _CuratedVerse(
      reference: 'Ecclesiastes 4:9-10',
      theme: 'Partnership',
      text: 'Two are better than one, because they have a good return for their labor: If either of them falls down, one can help the other up.',
    ),
    _CuratedVerse(
      reference: 'Ecclesiastes 4:12',
      theme: 'Unbreakable Bond',
      text: 'Though one may be overpowered, two can defend themselves. A cord of three strands is not quickly broken.',
    ),
    _CuratedVerse(
      reference: '1 John 4:19',
      theme: 'Source of Love',
      text: 'We love because He first loved us.',
    ),
    _CuratedVerse(
      reference: '1 John 4:12',
      theme: 'God\'s Love in Us',
      text: 'No one has ever seen God; but if we love one another, God lives in us and His love is made complete in us.',
    ),
    _CuratedVerse(
      reference: 'Ephesians 4:2-3',
      theme: 'Gentleness & Peace',
      text: 'Be completely humble and gentle; be patient, bearing with one another in love. Make every effort to keep the unity of the Spirit through the bond of peace.',
    ),
    _CuratedVerse(
      reference: 'Philippians 4:6-7',
      theme: 'Peace of God',
      text: 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.',
    ),
    _CuratedVerse(
      reference: 'Philippians 4:13',
      theme: 'Strength in Christ',
      text: 'I can do all this through Him who gives me strength.',
    ),
    _CuratedVerse(
      reference: 'Jeremiah 29:11',
      theme: 'Hope & Future',
      text: '\'For I know the plans I have for you,\' declares the Lord, \'plans to prosper you and not to harm you, plans to give you hope and a future.\'',
    ),
    _CuratedVerse(
      reference: 'Proverbs 3:5-6',
      theme: 'Trust in God',
      text: 'Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to Him, and He will make your paths straight.',
    ),
    _CuratedVerse(
      reference: 'Ruth 1:16-17',
      theme: 'Devotion',
      text: 'Where you go I will go, and where you stay I will stay. Your people will be my people and your God my God.',
    ),
    _CuratedVerse(
      reference: '1 Peter 4:8',
      theme: 'Deep Love',
      text: 'Above all, love each other deeply, because love covers over a multitude of sins.',
    ),
    _CuratedVerse(
      reference: 'Romans 12:10',
      theme: 'Honoring One Another',
      text: 'Be devoted to one another in love. Honor one another above yourselves.',
    ),
    _CuratedVerse(
      reference: 'Numbers 6:24-26',
      theme: 'God\'s Blessing',
      text: 'The Lord bless you and keep you; the Lord make His face shine on you and be gracious to you; the Lord turn His face toward you and give you peace.',
    ),
    _CuratedVerse(
      reference: 'Psalm 23:1-3',
      theme: 'The Lord My Shepherd',
      text: 'The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, He leads me beside quiet waters, He refreshes my soul.',
    ),
    _CuratedVerse(
      reference: 'Psalm 46:1',
      theme: 'Refuge & Strength',
      text: 'God is our refuge and strength, an ever-present help in trouble.',
    ),
    _CuratedVerse(
      reference: 'Joshua 1:9',
      theme: 'Courage',
      text: 'Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.',
    ),
    _CuratedVerse(
      reference: 'Isaiah 40:31',
      theme: 'Renewed Strength',
      text: 'Those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.',
    ),
    _CuratedVerse(
      reference: 'Romans 15:13',
      theme: 'Joy & Hope',
      text: 'May the God of hope fill you with all joy and peace as you trust in Him, so that you may overflow with hope by the power of the Holy Spirit.',
    ),
    _CuratedVerse(
      reference: 'Galatians 5:22-23',
      theme: 'Fruit of the Spirit',
      text: 'The fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control.',
    ),
    _CuratedVerse(
      reference: 'Psalm 118:24',
      theme: 'Rejoicing',
      text: 'This is the day the Lord has made; let us rejoice and be glad in it.',
    ),
    _CuratedVerse(
      reference: '1 Thessalonians 5:16-18',
      theme: 'Gratitude',
      text: 'Rejoice always, pray continually, give thanks in all circumstances; for this is God\'s will for you in Christ Jesus.',
    ),
    _CuratedVerse(
      reference: 'Proverbs 31:29',
      theme: 'Treasured Partner',
      text: 'Many women do noble things, but you surpass them all.',
    ),
    _CuratedVerse(
      reference: 'Psalm 37:4',
      theme: 'Desires of the Heart',
      text: 'Take delight in the Lord, and He will give you the desires of your heart.',
    ),
    _CuratedVerse(
      reference: 'Song of Solomon 3:4',
      theme: 'Finding My Love',
      text: 'I have found the one whom my soul loves.',
    ),
    _CuratedVerse(
      reference: 'Hebrews 10:24',
      theme: 'Spurring to Love',
      text: 'And let us consider how we may spur one another on toward love and good deeds.',
    ),
    _CuratedVerse(
      reference: 'Matthew 19:6',
      theme: 'Joined by God',
      text: 'So they are no longer two, but one flesh. Therefore what God has joined together, let no one separate.',
    ),
    _CuratedVerse(
      reference: 'Ephesians 5:25',
      theme: 'Selfless Love',
      text: 'Husbands, love your wives, just as Christ loved the church and gave Himself up for her.',
    ),
    _CuratedVerse(
      reference: 'Romans 8:38-39',
      theme: 'Inseparable Love',
      text: 'For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future... will be able to separate us from the love of God.',
    ),
    _CuratedVerse(
      reference: 'Lamentations 3:22-23',
      theme: 'New Mercies',
      text: 'Because of the Lord\'s great love we are not consumed, for His compassions never fail. They are new every morning; great is Your faithfulness.',
    ),
    _CuratedVerse(
      reference: 'Psalm 103:8',
      theme: 'Compassion & Grace',
      text: 'The Lord is compassionate and gracious, slow to anger, abounding in love.',
    ),
    _CuratedVerse(
      reference: 'Proverbs 17:17',
      theme: 'Loyalty',
      text: 'A friend loves at all times, and a brother is born for a time of adversity.',
    ),
    _CuratedVerse(
      reference: '2 Timothy 1:7',
      theme: 'Spirit of Power & Love',
      text: 'For God has not given us a spirit of fear, but of power and of love and of a sound mind.',
    ),
  ];
}

class _CuratedVerse {
  final String reference;
  final String theme;
  final String text;

  const _CuratedVerse({
    required this.reference,
    required this.theme,
    required this.text,
  });
}
