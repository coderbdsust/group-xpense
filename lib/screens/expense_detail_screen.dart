import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../providers/expense_provider.dart';
import 'add_expense_screen.dart';
import '../widgets/currency_text.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;
  final Group group;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddExpenseScreen(group: group, expense: expense),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteExpense(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amount Card
          Card(
            color: Colors.teal[50],
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),
                  CurrencyText(
                    amount: expense.amount,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: Icons.description,
                    label: 'Description',
                    value: expense.description,
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.category,
                    label: 'Category',
                    value: expense.category ?? 'Uncategorized',
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('MMMM dd, yyyy').format(expense.date),
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.person,
                    label: 'Paid By',
                    value: expense.paidBy.name,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Participants Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        'Participants (${expense.participants.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...expense.participants.map((person) {
                    final split = expense.splits[person.id] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal[100],
                        child: Text(
                          person.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(person.name),
                      trailing: CurrencyText(
                        amount: split,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Provider.of<ExpenseProvider>(
                context,
                listen: false,
              ).deleteExpense(expense.id, group.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close detail screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
