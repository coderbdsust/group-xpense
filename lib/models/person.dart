// lib/models/person.dart

class Person {
  final String id;
  final String name;
  final String? email;
  final String? avatar;

  Person({required this.id, required this.name, this.email, this.avatar});

  // Add toMap method
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'email': email, 'avatar': avatar};
  }

  // Add fromMap factory
  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      avatar: map['avatar'] as String?,
    );
  }

  // For JSON export/import (same as toMap for Person since it's simple)
  Map<String, dynamic> toJson() => toMap();

  factory Person.fromJson(Map<String, dynamic> json) => Person.fromMap(json);

  // Add copyWith method (useful for editing)
  Person copyWith({String? id, String? name, String? email, String? avatar}) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Person && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Person(id: $id, name: $name, email: $email)';
}
