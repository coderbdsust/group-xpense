// lib/screens/expense_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../providers/expense_provider.dart';
import 'add_expense_multi_payer_screen.dart';
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
    final isSettlement = expense.isSettlement;
    final hasMultiplePayers = expense.payers.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (!isSettlement) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseMultiPayerScreen(
                      group: group,
                      expense: expense,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteExpense(context),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settlement expenses cannot be edited'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Settlement Badge (if applicable)
          if (isSettlement)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake, color: Colors.purple[700], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settlement Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This is a settlement record',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Amount Card
          Card(
            color: isSettlement ? Colors.purple[50] : Colors.teal[50],
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    isSettlement ? 'Settlement Amount' : 'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      color: isSettlement ? Colors.purple : Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CurrencyText(
                    amount: expense.amount,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: isSettlement ? Colors.purple : Colors.teal,
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
                  if (!isSettlement) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.category,
                      label: 'Category',
                      value: expense.category ?? 'Uncategorized',
                    ),
                  ],
                  const Divider(height: 24),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateFormat('MMMM dd, yyyy').format(expense.date),
                  ),
                  if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      icon: Icons.note,
                      label: 'Notes',
                      value: expense.notes!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payers Card (Multiple Payers Support)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasMultiplePayers ? Icons.groups : Icons.person,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasMultiplePayers
                            ? 'Paid By (${expense.payers.length} people)'
                            : 'Paid By',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...expense.payers.map((payer) {
                    final percentage = (payer.amount / expense.amount) * 100;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(
                            payer.person.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          payer.person.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: hasMultiplePayers
                            ? Text(
                                '${percentage.toStringAsFixed(1)}% of total',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: CurrencyText(
                          amount: payer.amount,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Participants/Split Card
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
                        isSettlement
                            ? 'Involved'
                            : 'Split Between (${expense.participants.length})',
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
                    final percentage = expense.amount > 0
                        ? (split / expense.amount) * 100
                        : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
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
                        title: Text(
                          person.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: !isSettlement && split > 0
                            ? Text(
                                '${percentage.toStringAsFixed(1)}% of total',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: split > 0
                            ? CurrencyText(
                                amount: split,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                  fontSize: 16,
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isSettlement ? 'Receiver' : 'Not split',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Summary Card
          if (!isSettlement)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SummaryRow(label: 'Total Expense', value: expense.amount),
                    _SummaryRow(
                      label: 'Total Paid',
                      value: expense.totalPaidAmount,
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              (expense.totalPaidAmount - expense.amount).abs() <
                                      0.01
                                  ? Icons.check_circle
                                  : Icons.warning,
                              size: 16,
                              color:
                                  (expense.totalPaidAmount - expense.amount)
                                          .abs() <
                                      0.01
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (expense.totalPaidAmount - expense.amount).abs() <
                                      0.01
                                  ? 'Balanced'
                                  : 'Imbalanced',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color:
                                    (expense.totalPaidAmount - expense.amount)
                                            .abs() <
                                        0.01
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Delete Button for Settlements
          if (isSettlement)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _deleteExpense(context),
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Delete Settlement',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
        title: Text(
          expense.isSettlement ? 'Delete Settlement' : 'Delete Expense',
        ),
        content: Text(
          expense.isSettlement
              ? 'Are you sure you want to delete this settlement? This will affect the group balances.'
              : 'Are you sure you want to delete this expense?',
        ),
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
                  SnackBar(
                    content: Text(
                      expense.isSettlement
                          ? 'Settlement deleted successfully'
                          : 'Expense deleted successfully',
                    ),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          CurrencyText(
            amount: value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
