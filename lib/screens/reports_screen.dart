import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/group.dart';
import '../providers/expense_provider.dart';

class ReportsScreen extends StatelessWidget {
  final Group group;

  const ReportsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CategoryReportCard(group: group),
          const SizedBox(height: 16),
          _MonthlyReportCard(group: group),
          const SizedBox(height: 16),
          _SummaryReportCard(group: group),
        ],
      ),
    );
  }
}

class _CategoryReportCard extends StatelessWidget {
  final Group group;

  const _CategoryReportCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Expenses by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, double>>(
              future: provider.getExpensesByCategory(group.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No data available');
                }

                final categoryData = snapshot.data!;
                final total = categoryData.values.fold(0.0, (a, b) => a + b);

                return Column(
                  children: categoryData.entries.map((entry) {
                    final percentage = (entry.value / total * 100);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              Text(
                                '${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            color: Colors.teal,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyReportCard extends StatelessWidget {
  final Group group;

  const _MonthlyReportCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Monthly Expenses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, double>>(
              future: provider.getExpenseAmountByMonth(group.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No data available');
                }

                final monthData = snapshot.data!;
                final sortedMonths = monthData.keys.toList()..sort();

                return Column(
                  children: sortedMonths.reversed.take(6).map((month) {
                    final amount = monthData[month]!;
                    final date = DateTime.parse('$month-01');
                    final monthName = DateFormat('MMMM yyyy').format(date);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal[100],
                        child: Text(
                          DateFormat('MMM').format(date).substring(0, 1),
                          style: const TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(monthName),
                      trailing: Text(
                        NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                            .format(amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryReportCard extends StatelessWidget {
  final Group group;

  const _SummaryReportCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                provider.getGroupExpenses(group.id),
                provider.getTotalExpenses(group.id),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final expenses = snapshot.data![0] as List;
                final total = snapshot.data![1] as double;
                final average = expenses.isEmpty ? 0.0 : total / expenses.length;

                return Column(
                  children: [
                    _SummaryRow(
                      label: 'Total Expenses',
                      value: NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                          .format(total),
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Number of Expenses',
                      value: '${expenses.length}',
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Average per Expense',
                      value: NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                          .format(average),
                    ),
                    const Divider(),
                    _SummaryRow(
                      label: 'Per Member',
                      value: NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                          .format(total / group.members.length),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}