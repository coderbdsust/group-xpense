class Category {
  final String id;
  final String name;
  final String iconCodePoint;
  final String colorValue;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      iconCodePoint: map['iconCodePoint'] as String,
      colorValue: map['colorValue'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? iconCodePoint,
    String? colorValue,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
