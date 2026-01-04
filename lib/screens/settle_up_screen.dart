// lib/screens/settle_up_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';

class SettleUpScreen extends StatefulWidget {
  final Group group;

  const SettleUpScreen({super.key, required this.group});

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  Map<String, Map<String, double>> settlements = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _calculateSettlements();
  }

  Future<void> _calculateSettlements() async {
    setState(() => _loading = true);

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final calculated = await provider.calculateBalances(widget.group.id);

    setState(() {
      settlements = calculated;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settle Up - ${widget.group.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _calculateSettlements,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : settlements.isEmpty || _hasNoSettlements()
          ? _buildNoSettlementsView()
          : _buildSettlementsList(),
    );
  }

  bool _hasNoSettlements() {
    for (var creditors in settlements.values) {
      for (var amount in creditors.values) {
        if (amount > 0.01) return false;
      }
    }
    return true;
  }

  Widget _buildNoSettlementsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text(
            'All Settled Up!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending settlements',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsList() {
    final List<Widget> settlementWidgets = [];

    settlements.forEach((debtorId, creditors) {
      final debtor = widget.group.members.firstWhere((m) => m.id == debtorId);

      creditors.forEach((creditorId, amount) {
        if (amount > 0.01) {
          final creditor = widget.group.members.firstWhere(
            (m) => m.id == creditorId,
          );
          settlementWidgets.add(_buildSettlementCard(debtor, creditor, amount));
        }
      });
    });

    if (settlementWidgets.isEmpty) {
      return _buildNoSettlementsView();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.teal[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.teal[700]),
                    const SizedBox(width: 8),
                    const Text(
                      'How to Settle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap "Record Settlement" to mark a payment as completed. '
                  'This will create a settlement expense in the group.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...settlementWidgets,
      ],
    );
  }

  Widget _buildSettlementCard(Person from, Person to, double amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: Text(
                    from.name[0].toUpperCase(),
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        from.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'owes',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        to.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'receives',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(
                    to.name[0].toUpperCase(),
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    amount.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _recordSettlement(from, to, amount),
                icon: const Icon(Icons.check_circle),
                label: const Text('Record Settlement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordSettlement(Person from, Person to, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Settlement'),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            children: [
              TextSpan(
                text: from.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' paid '),
              TextSpan(
                text: to.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const TextSpan(
                text: '?\n\nThis will create a settlement record.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);

      // Create settlement expense
      final settlement = Expense(
        id: const Uuid().v4(),
        groupId: widget.group.id,
        description: 'Settlement: ${from.name} → ${to.name}',
        amount: amount,
        payers: [PayerShare(person: from, amount: amount)],
        participants: [from, to],
        splits: {
          from.id: 0.0, // From pays 0 (they're settling debt)
          to.id: amount, // To receives the amount
        },
        date: DateTime.now(),
        category: 'Settlement',
        isSettlement: true,
        notes: 'Settlement payment from ${from.name} to ${to.name}',
      );

      await provider.addExpense(settlement);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Settlement recorded successfully'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _calculateSettlements();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record settlement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
