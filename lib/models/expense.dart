import 'person.dart';

class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final Person paidBy;
  final List<Person> participants;
  final Map<String, double> splits; // personId -> amount they owe
  final DateTime date;
  final String? category;

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.participants,
    required this.splits,
    required this.date,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy.toJson(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'splits': splits,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      groupId: json['groupId'],
      description: json['description'],
      amount: json['amount'],
      paidBy: Person.fromJson(json['paidBy']),
      participants: (json['participants'] as List)
          .map((p) => Person.fromJson(p))
          .toList(),
      splits: Map<String, double>.from(json['splits']),
      date: DateTime.parse(json['date']),
      category: json['category'],
    );
  }
}
