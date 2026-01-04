// lib/models/settlement.dart

import 'dart:convert';
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

  // For database storage (with JSON-encoded strings)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'from': jsonEncode(from.toMap()),
      'to': jsonEncode(to.toMap()),
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory Settlement.fromMap(Map<String, dynamic> map) {
    return Settlement(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      from: Person.fromMap(jsonDecode(map['from']) as Map<String, dynamic>),
      to: Person.fromMap(jsonDecode(map['to']) as Map<String, dynamic>),
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }

  // For JSON export/import (with plain objects)
  Map<String, dynamic> toJson() {
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

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      from: Person.fromMap(json['from'] as Map<String, dynamic>),
      to: Person.fromMap(json['to'] as Map<String, dynamic>),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
    );
  }
}
