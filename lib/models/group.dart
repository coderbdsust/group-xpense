// lib/models/group.dart

import 'dart:convert'; // Add this import
import 'person.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final List<Person> members;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.members,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'members': jsonEncode(members.map((m) => m.toMap()).toList()),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      members: (jsonDecode(map['members']) as List)
          .map((m) => Person.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    List<Person>? members,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Group(id: $id, name: $name, members: ${members.length})';
}
