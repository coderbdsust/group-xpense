class Person {
  final String id;
  final String name;
  final String? email;
  final String? avatar;

  Person({required this.id, required this.name, this.email, this.avatar});

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'avatar': avatar};
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar'],
    );
  }
}
