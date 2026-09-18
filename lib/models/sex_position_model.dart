class SexPositionModel {
  final String name;
  final String category;
  final String imageUrl;
  final String slug;
  final String description;
  final String href;
  final String difficulty;
  final String animationUrl;

  const SexPositionModel({
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.slug,
    required this.description,
    required this.href,
    this.difficulty = '',
    this.animationUrl = '',
  });

  bool get hasAnimation => animationUrl.trim().isNotEmpty;

  factory SexPositionModel.fromJson(Map<String, dynamic> json) {
    return SexPositionModel(
      name: json['name'] as String? ?? 'Unknown Position',
      category: json['category'] as String? ?? 'Classic',
      imageUrl: json['imageUrl'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      href: json['href'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      animationUrl: json['animationUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'imageUrl': imageUrl,
      'slug': slug,
      'description': description,
      'href': href,
      'difficulty': difficulty,
      'animationUrl': animationUrl,
    };
  }

  SexPositionModel copyWith({
    String? name,
    String? category,
    String? imageUrl,
    String? slug,
    String? description,
    String? href,
    String? difficulty,
    String? animationUrl,
  }) {
    return SexPositionModel(
      name: name ?? this.name,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      href: href ?? this.href,
      difficulty: difficulty ?? this.difficulty,
      animationUrl: animationUrl ?? this.animationUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SexPositionModel &&
          runtimeType == other.runtimeType &&
          slug == other.slug;

  @override
  int get hashCode => slug.hashCode;
}
