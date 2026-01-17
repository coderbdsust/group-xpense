// lib/screens/group_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/expense_provider.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../services/export_service.dart';
import 'expense_detail_screen.dart';
import 'reports_screen.dart';
import 'edit_group_screen.dart';
import 'add_expense_multi_payer_screen.dart';
import 'settle_up_screen.dart';
import '../widgets/currency_text.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Force refresh when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExpenseProvider>(context, listen: false).refreshGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index == 3) {
      // Settle Up tab - navigate to screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SettleUpScreen(group: widget.group),
        ),
      ).then((_) {
        setState(() {});
      });
      // Reset to previous tab
      _tabController.index = _tabController.previousIndex;
    } else if (index == 4) {
      // Reports tab - navigate to screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportsScreen(group: widget.group),
        ),
      );
      // Reset to previous tab
      _tabController.index = _tabController.previousIndex;
    }
  }

  void _showExportOptions() {
    // Directly export to PDF without showing options
    _exportToPdf();
  }

  Future<void> _exportToPdf() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get expenses and provider
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final expenses = await provider.getGroupExpenses(widget.group.id);

      // Generate PDF with provider
      final filePath = await ExportService.exportToPdf(
        widget.group,
        expenses,
        provider,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success and share
      if (mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('PDF Generated'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your PDF has been generated successfully.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filePath,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );

        if (result == true) {
          await Share.shareXFiles(
            [XFile(filePath)],
            subject: '${widget.group.name} - Expense Report',
          );
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Export',
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Group',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditGroupScreen(group: widget.group),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _navigateToTab,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Balances'),
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.handshake), text: 'Settle Up'),
            Tab(icon: Icon(Icons.assessment), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe for last two tabs
        children: [
          _ExpensesTab(group: widget.group),
          _BalancesTab(group: widget.group),
          _MembersTab(group: widget.group),
          Container(), // Placeholder for Settle Up
          Container(), // Placeholder for Reports
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddExpenseMultiPayerScreen(group: widget.group),
            ),
          ).then((_) {
            setState(() {});
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}

class _ExpensesTab extends StatefulWidget {
  final Group group;

  const _ExpensesTab({required this.group});

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _deleteExpense(BuildContext context, Expense expense) async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    // Check if there are any settlements in the group
    final settlements = await provider.getSettlements(widget.group.id);
    final hasSettlements = settlements.isNotEmpty;

    // Find if this expense is before the first settlement
    bool canDelete = true;
    String? blockReason;

    if (hasSettlements) {
      // Get the date of the earliest settlement
      final earliestSettlement = settlements.reduce((a, b) =>
        a.date.isBefore(b.date) ? a : b
      );

      // If the expense is before or on the settlement date, it cannot be deleted
      if (expense.date.isBefore(earliestSettlement.date) ||
          expense.date.isAtSameMomentAs(earliestSettlement.date)) {
        canDelete = false;
        blockReason = 'This expense cannot be deleted because settlements have been recorded after it. '
                      'Deleting it would affect settled balances.';
      }
    }

    if (!canDelete && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Expense'),
          content: Text(blockReason ?? 'This expense cannot be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete "${expense.description}"?\n\n'
          'Amount: ${expense.amount.toStringAsFixed(2)}\n'
          'Date: ${DateFormat('MMM dd, yyyy').format(expense.date)}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await provider.deleteExpense(expense.id, widget.group.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete expense: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<ExpenseProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<List<Expense>>(
          future: provider.getGroupExpenses(widget.group.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading expenses',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No expenses yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add an expense',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            final expenses = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return _ExpenseCard(
                    expense: expense,
                    group: widget.group,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseDetailScreen(
                            expense: expense,
                            group: widget.group,
                          ),
                        ),
                      ).then((_) {
                        setState(() {});
                      });
                    },
                    onDelete: () => _deleteExpense(context, expense),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final Group group;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.group,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSettlement = expense.isSettlement;
    final displayIcon = isSettlement
        ? Icons.handshake
        : _getCategoryIcon(expense.category);
    final displayColor = isSettlement ? Colors.purple : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: displayColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(displayIcon, color: displayColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expense.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isSettlement)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple[200]!,
                                  ),
                                ),
                                child: Text(
                                  'SETTLEMENT',
                                  style: TextStyle(
                                    color: Colors.purple[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, yyyy').format(expense.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CurrencyText(
                        amount: expense.amount,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: displayColor,
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: Colors.red[400],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  if (expense.payers.isEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'No payer info',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else if (expense.payers.length == 1) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.green[100],
                      child: Text(
                        expense.payers.first.person.name[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${expense.payers.first.person.name} paid',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: (expense.payers.length.clamp(0, 3) * 20.0) + 16,
                      height: 32,
                      child: Stack(
                        children: [
                          for (
                            var i = 0;
                            i < expense.payers.length.clamp(0, 3);
                            i++
                          )
                            Positioned(
                              left: i * 20.0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green[100],
                                child: Text(
                                  expense.payers[i].person.name[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${expense.payers.length} payer${expense.payers.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ),
                  ],
                  Text(
                    '${expense.participants.length} participant${expense.participants.length > 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Food & Drinks':
        return Icons.restaurant;
      case 'Transportation':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Utilities':
        return Icons.electrical_services;
      case 'Rent':
        return Icons.home;
      case 'Settlement':
        return Icons.handshake;
      default:
        return Icons.receipt;
    }
  }
}

class _BalancesTab extends StatelessWidget {
  final Group group;

  const _BalancesTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        provider.calculateBalances(group.id),
        provider.getTotalExpenses(group.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading balances',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No balances to show',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final settlements =
            snapshot.data![0] as Map<String, Map<String, double>>;
        final totalExpenses = snapshot.data![1] as double;

        bool hasSettlements = false;
        for (var creditors in settlements.values) {
          for (var amount in creditors.values) {
            if (amount > 0.01) {
              hasSettlements = true;
              break;
            }
          }
          if (hasSettlements) break;
        }

        return RefreshIndicator(
          onRefresh: () async {
            final expenseProvider = Provider.of<ExpenseProvider>(
              context,
              listen: false,
            );
            await expenseProvider.refreshGroups();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.teal[50],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Total Group Expenses',
                        style: TextStyle(fontSize: 16, color: Colors.teal),
                      ),
                      const SizedBox(height: 8),
                      CurrencyText(
                        amount: totalExpenses,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!hasSettlements) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'All Settled Up!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No pending settlements',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Who Owes Whom',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...settlements.entries.expand((debtorEntry) {
                  final debtorId = debtorEntry.key;
                  final debtor = group.members.firstWhere(
                    (m) => m.id == debtorId,
                  );

                  return debtorEntry.value.entries
                      .where((e) => e.value > 0.01)
                      .map((creditorEntry) {
                        final creditorId = creditorEntry.key;
                        final amount = creditorEntry.value;
                        final creditor = group.members.firstWhere(
                          (m) => m.id == creditorId,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red[100],
                                  child: Text(
                                    debtor.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        debtor.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'owes',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        creditor.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      CurrencyText(
                                        amount: amount,
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Text(
                                    creditor.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  final Group group;

  const _MembersTab({required this.group});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.members.length,
      itemBuilder: (context, index) {
        final member = group.members[index];
        return _MemberCard(group: group, member: member);
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Group group;
  final member;

  const _MemberCard({required this.group, required this.member});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return FutureBuilder<List<double>>(
      future: Future.wait([
        provider.getPersonTotalPaid(group.id, member.id),
        provider.getPersonTotalOwed(group.id, member.id),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.teal[100],
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        final totalPaid = snapshot.data![0];
        final totalOwed = snapshot.data![1];
        final balance = totalPaid - totalOwed;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal[100],
                  child: Text(
                    member.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Paid: ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          CurrencyText(
                            amount: totalPaid,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Owes: ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          CurrencyText(
                            amount: totalOwed,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: balance >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        balance >= 0 ? '+' : '',
                        style: TextStyle(
                          color: balance >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      CurrencyText(
                        amount: balance.abs(),
                        style: TextStyle(
                          color: balance >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
