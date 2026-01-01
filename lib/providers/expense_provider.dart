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

  // Add after updateGroup method
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

  Future<Expense?> getExpense(String expenseId, String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    try {
      return expenses.firstWhere((e) => e.id == expenseId);
    } catch (e) {
      return null;
    }
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

  Future<Map<String, Map<String, double>>> calculateBalances(
      String groupId,
      ) async {
    final groupExpenses = await getGroupExpenses(groupId);
    final balances = <String, double>{};

    final group = getGroup(groupId);
    if (group == null) return {};

    for (var member in group.members) {
      balances[member.id] = 0;
    }

    for (var expense in groupExpenses) {
      balances[expense.paidBy.id] =
          (balances[expense.paidBy.id] ?? 0) + expense.amount;

      for (var entry in expense.splits.entries) {
        balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
      }
    }

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

  Future<double> getTotalExpenses(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getPersonTotalPaid(String groupId, String personId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses
        .where((e) => e.paidBy.id == personId)
        .fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  Future<double> getPersonTotalOwed(String groupId, String personId) async {
    final expenses = await getGroupExpenses(groupId);
    return expenses.fold<double>(
      0.0,
          (sum, expense) => sum + (expense.splits[personId] ?? 0),
    );
  }

  // Reporting methods
  Future<Map<String, double>> getExpensesByCategory(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final categoryTotals = <String, double>{};

    for (var expense in expenses) {
      final category = expense.category ?? 'Other';
      categoryTotals[category] = (categoryTotals[category] ?? 0) + expense.amount;
    }

    return categoryTotals;
  }

  Future<Map<String, int>> getExpenseCountByMonth(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final monthCounts = <String, int>{};

    for (var expense in expenses) {
      final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
    }

    return monthCounts;
  }

  Future<Map<String, double>> getExpenseAmountByMonth(String groupId) async {
    final expenses = await getGroupExpenses(groupId);
    final monthTotals = <String, double>{};

    for (var expense in expenses) {
      final monthKey = '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      monthTotals[monthKey] = (monthTotals[monthKey] ?? 0) + expense.amount;
    }

    return monthTotals;
  }
}