// lib/providers/expense_provider.dart

import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

class ExpenseProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Group> _groups = [];
  final Map<String, List<Expense>> _expenseCache = {};

  List<Group> get groups => _groups;

  ExpenseProvider() {
    loadGroups();
  }

  Future<void> loadGroups() async {
    _groups = await _db.getAllGroups();
    notifyListeners();
  }

  Future<void> refreshGroups() async {
    await loadGroups();
  }

  Future<void> addGroup(Group group) async {
    await _db.insertGroup(group);
    await loadGroups();
  }

  Future<void> updateGroup(Group group) async {
    await _db.updateGroup(group);
    await loadGroups();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.deleteGroup(groupId);
    _expenseCache.remove(groupId);
    await loadGroups();
  }

  Future<void> addMemberToGroup(String groupId, Person person) async {
    await _db.addMemberToGroup(groupId, person);
    await loadGroups();
  }

  Future<void> removeMemberFromGroup(String groupId, String personId) async {
    await _db.removeMemberFromGroup(groupId, personId);
    await loadGroups();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    _expenseCache.remove(expense.groupId);
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    _expenseCache.remove(expense.groupId);
    notifyListeners();
  }

  Future<void> deleteExpense(String expenseId, String groupId) async {
    await _db.deleteExpense(expenseId);
    _expenseCache.remove(groupId);
    notifyListeners();
  }

  Future<Expense?> getExpense(String expenseId) async {
    return await _db.getExpense(expenseId);
  }

  Future<List<Expense>> getGroupExpenses(String groupId) async {
    if (_expenseCache.containsKey(groupId)) {
      return _expenseCache[groupId]!;
    }

    final expenses = await _db.getGroupExpenses(groupId);
    _expenseCache[groupId] = expenses;
    return expenses;
  }

  Group? getGroup(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateMemberName(
    String groupId,
    String memberId,
    String newName,
  ) async {
    await _db.updateMemberName(groupId, memberId, newName);
    notifyListeners();
  }

  // Updated to accept groupId parameter
  Future<Map<String, Map<String, double>>> calculateBalances(
    String groupId,
  ) async {
    final groupExpenses = await getGroupExpenses(groupId);
    final balances = <String, double>{};

    final group = getGroup(groupId);
    if (group == null) return {};

    // Initialize balances for all members
    for (var member in group.members) {
      balances[member.id] = 0;
    }

    // Calculate balances from all expenses (including settlements)
    for (var expense in groupExpenses) {
      // Add amounts paid by each payer
      for (var payer in expense.payers) {
        balances[payer.person.id] =
            (balances[payer.person.id] ?? 0) + payer.amount;
      }

      // Subtract split amounts
      for (var entry in expense.splits.entries) {
        balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
      }
    }

    // Calculate optimal settlements
    final settlements = <String, Map<String, double>>{};
    final creditors = <String, double>{};
    final debtors = <String, double>{};

    balances.forEach((personId, balance) {
      if (balance > 0.01) {
        creditors[personId] = balance;
      } else if (balance < -0.01) {
        debtors[personId] = -balance;
      }
    });

    for (var debtorEntry in debtors.entries) {
      settlements[debtorEntry.key] = {};
      var remainingDebt = debtorEntry.value;

      for (var creditorEntry in creditors.entries) {
        if (remainingDebt <= 0.01) break;

        var creditorBalance = creditorEntry.value;
        if (creditorBalance <= 0.01) continue;

        var payment = remainingDebt < creditorBalance
            ? remainingDebt
            : creditorBalance;
        settlements[debtorEntry.key]![creditorEntry.key] = payment;

        creditors[creditorEntry.key] = creditorBalance - payment;
        remainingDebt -= payment;
      }
    }

    return settlements;
  }

  // UPDATED: Exclude settlements from total expenses
  Future<double> getTotalExpenses(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses
        .where((expense) => !expense.isSettlement) // Exclude settlements
        .fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getPersonTotalPaid(String groupId, String personId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.fold<double>(0.0, (sum, expense) {
      // Sum all amounts this person paid across all expenses (including settlements)
      final personPayments = expense.payers
          .where((payer) => payer.person.id == personId)
          .fold<double>(0.0, (payerSum, payer) => payerSum + payer.amount);
      return sum + personPayments;
    });
  }

  Future<double> getPersonTotalOwed(String groupId, String personId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.fold<double>(
      0.0,
      (sum, expense) => sum + (expense.splits[personId] ?? 0),
    );
  }

  Future<double> getPersonBalance(String groupId, String personId) async {
    final totalPaid = await getPersonTotalPaid(groupId, personId);
    final totalOwed = await getPersonTotalOwed(groupId, personId);
    return totalPaid - totalOwed;
  }

  // Reporting methods - UPDATED to exclude settlements
  Future<Map<String, double>> getExpensesByCategory(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final categoryTotals = <String, double>{};

    for (var expense in expenses) {
      // Don't include settlements in category breakdown
      if (expense.isSettlement) continue;

      final category = expense.category ?? 'Other';
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + expense.amount;
    }

    return categoryTotals;
  }

  // UPDATED: Exclude settlements from monthly count
  Future<Map<String, int>> getExpenseCountByMonth(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final monthCounts = <String, int>{};

    for (var expense in expenses) {
      // Skip settlements
      if (expense.isSettlement) continue;

      final monthKey =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
    }

    return monthCounts;
  }

  // UPDATED: Exclude settlements from monthly totals
  Future<Map<String, double>> getExpenseAmountByMonth(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final monthTotals = <String, double>{};

    for (var expense in expenses) {
      // Skip settlements
      if (expense.isSettlement) continue;

      final monthKey =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthTotals[monthKey] = (monthTotals[monthKey] ?? 0) + expense.amount;
    }

    return monthTotals;
  }

  // Get all settlements for a group
  Future<List<Expense>> getSettlements(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.where((e) => e.isSettlement).toList();
  }

  // Get all non-settlement expenses for a group
  Future<List<Expense>> getNormalExpenses(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.where((e) => !e.isSettlement).toList();
  }

  // Check if a group has any unsettled balances
  Future<bool> hasUnsettledBalances(String groupId) async {
    final balances = await calculateBalances(groupId);

    // Check if any settlements are needed
    for (var settlements in balances.values) {
      if (settlements.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  // Get summary of who owes whom
  Future<List<DebtSummary>> getDebtSummary(String groupId) async {
    final settlements = await calculateBalances(groupId);
    final group = getGroup(groupId);
    if (group == null) return [];

    final summaries = <DebtSummary>[];

    settlements.forEach((debtorId, creditors) {
      final debtor = group.members.firstWhere((m) => m.id == debtorId);

      creditors.forEach((creditorId, amount) {
        if (amount > 0.01) {
          final creditor = group.members.firstWhere((m) => m.id == creditorId);
          summaries.add(
            DebtSummary(from: debtor, to: creditor, amount: amount),
          );
        }
      });
    });

    return summaries;
  }

  // NEW: Get statistics excluding settlements
  Future<Map<String, dynamic>> getGroupStats(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final normalExpenses = expenses.where((e) => !e.isSettlement).toList();
    final settlements = expenses.where((e) => e.isSettlement).toList();

    return {
      'totalExpenses': normalExpenses.fold<double>(
        0.0,
        (sum, e) => sum + e.amount,
      ),
      'expenseCount': normalExpenses.length,
      'settlementCount': settlements.length,
      'averageExpense': normalExpenses.isEmpty
          ? 0.0
          : normalExpenses.fold<double>(0.0, (sum, e) => sum + e.amount) /
                normalExpenses.length,
    };
  }
}

// Helper class for debt summary
class DebtSummary {
  final Person from;
  final Person to;
  final double amount;

  DebtSummary({required this.from, required this.to, required this.amount});

  @override
  String toString() =>
      '${from.name} owes ${to.name} \$${amount.toStringAsFixed(2)}';
}
