// lib/models/settlement.dart

import 'person.dart';

class Settlement {
  final String id;
  final String groupId;
  final Person from; // Who owes money
  final Person to; // Who receives money
  final double amount;
  final DateTime date;
  final String? notes;

  Settlement({
    required this.id,
    required this.groupId,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'from': from.toMap(),
      'to': to.toMap(),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'],
      groupId: map['groupId'],
      from: Person.fromMap(map['from']),
      to: Person.fromMap(map['to']),
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      notes: map['notes'],
    );
  }
}
