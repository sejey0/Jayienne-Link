import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum SocialPlatform {
  website,
  instagram,
  tiktok,
  spotify,
  facebook,
  twitter,
  youtube,
  snapchat,
  telegram,
  discord,
  github,
  pinterest;

  static SocialPlatform fromString(String? value) {
    if (value == null) return SocialPlatform.website;
    final normalized = value.toLowerCase().trim();
    switch (normalized) {
      case 'instagram':
      case 'ig':
      case 'insta':
        return SocialPlatform.instagram;
      case 'tiktok':
      case 'tt':
        return SocialPlatform.tiktok;
      case 'spotify':
        return SocialPlatform.spotify;
      case 'facebook':
      case 'fb':
        return SocialPlatform.facebook;
      case 'twitter':
      case 'x':
        return SocialPlatform.twitter;
      case 'youtube':
      case 'yt':
        return SocialPlatform.youtube;
      case 'snapchat':
      case 'snap':
        return SocialPlatform.snapchat;
      case 'telegram':
      case 'tg':
        return SocialPlatform.telegram;
      case 'discord':
        return SocialPlatform.discord;
      case 'github':
        return SocialPlatform.github;
      case 'pinterest':
      case 'pin':
        return SocialPlatform.pinterest;
      case 'website':
      case 'custom':
      case 'link':
      case 'other':
      default:
        return SocialPlatform.website;
    }
  }

  /// Automatically detect platform from a raw URL string or username
  static SocialPlatform? detectFromUrl(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return null;

    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return SocialPlatform.instagram;
    }
    if (lower.contains('tiktok.com')) {
      return SocialPlatform.tiktok;
    }
    if (lower.contains('spotify.com')) {
      return SocialPlatform.spotify;
    }
    if (lower.contains('facebook.com') || lower.contains('fb.me') || lower.contains('fb.com')) {
      return SocialPlatform.facebook;
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return SocialPlatform.twitter;
    }
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return SocialPlatform.youtube;
    }
    if (lower.contains('snapchat.com')) {
      return SocialPlatform.snapchat;
    }
    if (lower.contains('t.me') || lower.contains('telegram.me') || lower.contains('telegram.org')) {
      return SocialPlatform.telegram;
    }
    if (lower.contains('discord.gg') || lower.contains('discord.com') || lower.contains('discordapp.com')) {
      return SocialPlatform.discord;
    }
    if (lower.contains('github.com')) {
      return SocialPlatform.github;
    }
    if (lower.contains('pinterest.com') || lower.contains('pin.it')) {
      return SocialPlatform.pinterest;
    }
    if (lower.startsWith('http://') || lower.startsWith('https://') || lower.contains('.')) {
      return SocialPlatform.website;
    }
    return null;
  }

  /// Extract clean domain/hostname from any URL for favicon loading
  static String? extractDomain(String rawUrl) {
    try {
      var clean = rawUrl.trim();
      if (clean.isEmpty) return null;
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'https://$clean';
      }
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.host.isNotEmpty) {
        return uri.host;
      }
    } catch (_) {}
    return null;
  }

  String get id => name;

  String get displayName {
    switch (this) {
      case SocialPlatform.instagram:
        return 'Instagram';
      case SocialPlatform.tiktok:
        return 'TikTok';
      case SocialPlatform.spotify:
        return 'Spotify';
      case SocialPlatform.facebook:
        return 'Facebook';
      case SocialPlatform.twitter:
        return 'X / Twitter';
      case SocialPlatform.youtube:
        return 'YouTube';
      case SocialPlatform.snapchat:
        return 'Snapchat';
      case SocialPlatform.telegram:
        return 'Telegram';
      case SocialPlatform.discord:
        return 'Discord';
      case SocialPlatform.github:
        return 'GitHub';
      case SocialPlatform.pinterest:
        return 'Pinterest';
      case SocialPlatform.website:
        return 'Custom';
    }
  }

  FaIconData get icon {
    switch (this) {
      case SocialPlatform.website:
        return FontAwesomeIcons.globe;
      case SocialPlatform.instagram:
        return FontAwesomeIcons.instagram;
      case SocialPlatform.tiktok:
        return FontAwesomeIcons.tiktok;
      case SocialPlatform.spotify:
        return FontAwesomeIcons.spotify;
      case SocialPlatform.facebook:
        return FontAwesomeIcons.facebookF;
      case SocialPlatform.twitter:
        return FontAwesomeIcons.xTwitter;
      case SocialPlatform.youtube:
        return FontAwesomeIcons.youtube;
      case SocialPlatform.snapchat:
        return FontAwesomeIcons.snapchat;
      case SocialPlatform.telegram:
        return FontAwesomeIcons.telegram;
      case SocialPlatform.discord:
        return FontAwesomeIcons.discord;
      case SocialPlatform.github:
        return FontAwesomeIcons.github;
      case SocialPlatform.pinterest:
        return FontAwesomeIcons.pinterestP;
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case SocialPlatform.instagram:
        return const [Color(0xFFE1306C), Color(0xFFC13584), Color(0xFF833AB4)];
      case SocialPlatform.tiktok:
        return const [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFF000000)];
      case SocialPlatform.spotify:
        return const [Color(0xFF1DB954), Color(0xFF191414)];
      case SocialPlatform.facebook:
        return const [Color(0xFF1877F2), Color(0xFF0C63D4)];
      case SocialPlatform.twitter:
        return const [Color(0xFF1DA1F2), Color(0xFF0C85D0)];
      case SocialPlatform.youtube:
        return const [Color(0xFFFF0000), Color(0xFFB71C1C)];
      case SocialPlatform.snapchat:
        return const [Color(0xFFFFFC00), Color(0xFFFFD600)];
      case SocialPlatform.telegram:
        return const [Color(0xFF2AABEE), Color(0xFF229ED9)];
      case SocialPlatform.discord:
        return const [Color(0xFF5865F2), Color(0xFF4752C4)];
      case SocialPlatform.github:
        return const [Color(0xFF24292E), Color(0xFF0D1117)];
      case SocialPlatform.pinterest:
        return const [Color(0xFFE60023), Color(0xFFAD081B)];
      case SocialPlatform.website:
        return const [Color(0xFFFF758C), Color(0xFFA18CD1)];
    }
  }

  Color get primaryColor => gradientColors.first;

  String get handlePrefix {
    switch (this) {
      case SocialPlatform.instagram:
      case SocialPlatform.tiktok:
      case SocialPlatform.twitter:
      case SocialPlatform.youtube:
      case SocialPlatform.pinterest:
        return '@';
      case SocialPlatform.website:
        return 'https://';
      default:
        return '';
    }
  }

  String get placeholder {
    switch (this) {
      case SocialPlatform.instagram:
        return 'username (e.g. @jayienne)';
      case SocialPlatform.tiktok:
        return 'username (e.g. @jayienne)';
      case SocialPlatform.spotify:
        return 'user/profile link or username';
      case SocialPlatform.facebook:
        return 'profile username or URL';
      case SocialPlatform.twitter:
        return 'handle (e.g. @jayienne)';
      case SocialPlatform.youtube:
        return 'channel handle (e.g. @channel)';
      case SocialPlatform.snapchat:
        return 'snapchat username';
      case SocialPlatform.telegram:
        return 'username (e.g. @username)';
      case SocialPlatform.discord:
        return 'user ID or server invite';
      case SocialPlatform.github:
        return 'github username';
      case SocialPlatform.pinterest:
        return 'pinterest username';
      case SocialPlatform.website:
        return 'https://example.com';
    }
  }

  String formatUrl(String rawInput) {
    final clean = rawInput.trim();
    if (clean.isEmpty) return '';

    // If it's already a full HTTP / HTTPS URL, clean it up and return
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    final handle = clean.startsWith('@') ? clean.substring(1) : clean;

    switch (this) {
      case SocialPlatform.instagram:
        return 'https://www.instagram.com/$handle/';
      case SocialPlatform.tiktok:
        return 'https://www.tiktok.com/@$handle';
      case SocialPlatform.spotify:
        if (clean.contains('spotify.com')) {
          return 'https://$clean';
        }
        return 'https://open.spotify.com/user/$handle';
      case SocialPlatform.facebook:
        return 'https://www.facebook.com/$handle';
      case SocialPlatform.twitter:
        return 'https://x.com/$handle';
      case SocialPlatform.youtube:
        return 'https://www.youtube.com/@$handle';
      case SocialPlatform.snapchat:
        return 'https://www.snapchat.com/add/$handle';
      case SocialPlatform.telegram:
        return 'https://t.me/$handle';
      case SocialPlatform.discord:
        if (clean.contains('discord.gg') || clean.contains('discord.com')) {
          return 'https://$clean';
        }
        return 'https://discord.com/users/$handle';
      case SocialPlatform.github:
        return 'https://github.com/$handle';
      case SocialPlatform.pinterest:
        return 'https://www.pinterest.com/$handle/';
      case SocialPlatform.website:
        return 'https://$clean';
    }
  }
}

class SocialLinkModel {
  final String id;
  final String coupleId;
  final String userId;
  final String? userDisplayName;
  final String? userPhotoUrl;
  final String platform;
  final String title;
  final String username;
  final String url;
  final String? iconKey;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SocialLinkModel({
    required this.id,
    required this.coupleId,
    required this.userId,
    this.userDisplayName,
    this.userPhotoUrl,
    required this.platform,
    required this.title,
    required this.username,
    required this.url,
    this.iconKey,
    required this.createdAt,
    this.updatedAt,
  });

  SocialPlatform get socialPlatform => SocialPlatform.fromString(platform);

  String get displayTitle =>
      title.isNotEmpty ? title : socialPlatform.displayName;

  String get displayHandle {
    if (username.isNotEmpty) {
      if (socialPlatform.handlePrefix == '@' && !username.startsWith('@')) {
        return '@$username';
      }
      return username;
    }
    // Fallback: extract from URL
    try {
      final uri = Uri.parse(url);
      return uri.host + uri.path;
    } catch (_) {
      return url;
    }
  }

  factory SocialLinkModel.fromJson(Map<String, dynamic> json) {
    return SocialLinkModel(
      id: json['id']?.toString() ?? '',
      coupleId: json['couple_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['created_by']?.toString() ?? '',
      userDisplayName: json['user_display_name'] as String?,
      userPhotoUrl: json['user_photo_url'] as String?,
      platform: json['platform']?.toString() ?? 'website',
      title: json['title']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      iconKey: json['icon_key'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'user_id': userId,
      if (userDisplayName != null) 'user_display_name': userDisplayName,
      if (userPhotoUrl != null) 'user_photo_url': userPhotoUrl,
      'platform': platform,
      'title': title,
      'username': username,
      'url': url,
      if (iconKey != null) 'icon_key': iconKey,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    // Never send 'id' — always let Supabase generate it via DEFAULT gen_random_uuid()::text
    return <String, dynamic>{
      'couple_id': coupleId,
      'user_id': userId,
      if (userDisplayName != null && userDisplayName!.isNotEmpty)
        'user_display_name': userDisplayName,
      if (userPhotoUrl != null && userPhotoUrl!.isNotEmpty)
        'user_photo_url': userPhotoUrl,
      'platform': platform,
      'title': title,
      'username': username,
      'url': url,
      if (iconKey != null) 'icon_key': iconKey,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SocialLinkModel copyWith({
    String? id,
    String? coupleId,
    String? userId,
    String? userDisplayName,
    String? userPhotoUrl,
    String? platform,
    String? title,
    String? username,
    String? url,
    String? iconKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SocialLinkModel(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      platform: platform ?? this.platform,
      title: title ?? this.title,
      username: username ?? this.username,
      url: url ?? this.url,
      iconKey: iconKey ?? this.iconKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
