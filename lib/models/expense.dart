// lib/models/expense.dart

import 'dart:convert'; // Add this import
import 'person.dart';

class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;

  // Changed from single payer to multiple payers
  final List<PayerShare> payers; // Multiple people can pay

  final List<Person> participants;
  final Map<String, double> splits;
  final DateTime date;
  final String? category;
  final String? notes;
  final bool isSettlement; // New field to mark settlement expenses

  Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.payers,
    required this.participants,
    required this.splits,
    required this.date,
    this.category,
    this.notes,
    this.isSettlement = false,
  });

  // Backward compatibility - get primary payer
  Person get paidBy =>
      payers.isNotEmpty ? payers.first.person : participants.first;

  // Get total paid amount
  double get totalPaidAmount {
    return payers.fold(0.0, (sum, payer) => sum + payer.amount);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'payers': jsonEncode(payers.map((p) => p.toMap()).toList()),
      'participants': jsonEncode(participants.map((p) => p.toMap()).toList()),
      'splits': jsonEncode(splits),
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
      'isSettlement': isSettlement ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    // Handle backward compatibility
    List<PayerShare> payers;

    if (map.containsKey('payers') &&
        map['payers'] != null &&
        map['payers'].toString().isNotEmpty &&
        map['payers'] != 'null') {
      try {
        final payersData = jsonDecode(map['payers']) as List;
        payers = payersData.map((p) => PayerShare.fromMap(p)).toList();
      } catch (e) {
        // Fallback if payers parsing fails
        print('Error parsing payers: $e');
        final paidByData = jsonDecode(map['paidBy']) as Map<String, dynamic>;
        payers = [
          PayerShare(
            person: Person.fromMap(paidByData),
            amount: (map['amount'] as num).toDouble(),
          ),
        ];
      }
    } else if (map.containsKey('paidBy') && map['paidBy'] != null) {
      // Fallback to old single paidBy format
      final paidByData = jsonDecode(map['paidBy']) as Map<String, dynamic>;
      payers = [
        PayerShare(
          person: Person.fromMap(paidByData),
          amount: (map['amount'] as num).toDouble(),
        ),
      ];
    } else {
      // Ultimate fallback - create empty list
      payers = [];
    }

    return Expense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      payers: payers,
      participants: (jsonDecode(map['participants']) as List)
          .map((p) => Person.fromMap(p as Map<String, dynamic>))
          .toList(),
      splits: Map<String, double>.from(jsonDecode(map['splits'])),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      isSettlement: map['isSettlement'] == 1,
    );
  }

  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    List<PayerShare>? payers,
    List<Person>? participants,
    Map<String, double>? splits,
    DateTime? date,
    String? category,
    String? notes,
    bool? isSettlement,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      payers: payers ?? this.payers,
      participants: participants ?? this.participants,
      splits: splits ?? this.splits,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isSettlement: isSettlement ?? this.isSettlement,
    );
  }

  @override
  String toString() =>
      'Expense(id: $id, description: $description, amount: $amount)';
}

// New class to represent who paid and how much
class PayerShare {
  final Person person;
  final double amount;

  PayerShare({required this.person, required this.amount});

  Map<String, dynamic> toMap() {
    return {'person': person.toMap(), 'amount': amount};
  }

  factory PayerShare.fromMap(Map<String, dynamic> map) {
    return PayerShare(
      person: Person.fromMap(map['person'] as Map<String, dynamic>),
      amount: (map['amount'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'PayerShare(person: ${person.name}, amount: $amount)';
}
