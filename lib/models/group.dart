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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'members': members.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      members: (json['members'] as List)
          .map((m) => Person.fromJson(m))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
