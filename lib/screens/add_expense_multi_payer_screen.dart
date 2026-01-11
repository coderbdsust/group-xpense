// lib/screens/add_expense_multi_payer_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';

class AddExpenseMultiPayerScreen extends StatefulWidget {
  final Group group;
  final Expense? expense; // For editing

  const AddExpenseMultiPayerScreen({
    super.key,
    required this.group,
    this.expense,
  });

  @override
  State<AddExpenseMultiPayerScreen> createState() =>
      _AddExpenseMultiPayerScreenState();
}

class _AddExpenseMultiPayerScreenState
    extends State<AddExpenseMultiPayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  // Multiple payers
  final Map<String, TextEditingController> _payerAmountControllers = {};
  final Set<String> _selectedPayers = {};

  // Participants
  final Set<String> _selectedParticipants = {};
  SplitType _splitType = SplitType.equal;
  final Map<String, TextEditingController> _splitControllers = {};

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'Food & Drinks',
    'Transportation',
    'Entertainment',
    'Shopping',
    'Utilities',
    'Rent',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExpenseData();
  }

  void _initializeControllers() {
    for (var member in widget.group.members) {
      _payerAmountControllers[member.id] = TextEditingController(text: '0.00');
      _splitControllers[member.id] = TextEditingController(text: '0.00');
    }
  }

  void _loadExpenseData() {
    if (widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _notesController.text = widget.expense!.notes ?? '';
      _selectedDate = widget.expense!.date;
      _selectedCategory = widget.expense!.category;

      // Load payers
      for (var payer in widget.expense!.payers) {
        _selectedPayers.add(payer.person.id);
        _payerAmountControllers[payer.person.id]!.text = payer.amount
            .toStringAsFixed(2);
      }

      // Load participants and splits
      for (var participant in widget.expense!.participants) {
        _selectedParticipants.add(participant.id);
        final split = widget.expense!.splits[participant.id] ?? 0.0;
        _splitControllers[participant.id]!.text = split.toStringAsFixed(2);
      }
    } else {
      // Default: select all members as participants
      _selectedParticipants.addAll(widget.group.members.map((m) => m.id));
    }
  }

  double _calculateTotalPaidAmount() {
    return _selectedPayers.fold<double>(
      0.0,
      (sum, id) =>
          sum + (double.tryParse(_payerAmountControllers[id]!.text) ?? 0.0),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _payerAmountControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _splitControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveExpense,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildPayersSection(),
            const SizedBox(height: 24),
            _buildParticipantsSection(),
            const SizedBox(height: 24),
            _buildSplitSection(),
            const SizedBox(height: 24),
            _buildSummarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'What was this for?',
                prefixIcon: Icon(Icons.description, color: Colors.teal),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Auto-calculated Total Amount Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[50]!, Colors.teal[100]!],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[300]!, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.teal[700], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: Colors.teal,
                        size: 20,
                      ),
                      Text(
                        _calculateTotalPaidAmount().toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Calculated from "Who Paid" amounts below',
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category, color: Colors.teal),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.teal),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add additional details',
                prefixIcon: Icon(Icons.note, color: Colors.teal),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Who Paid?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _autoDistributePayers,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Auto Split'),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select payers and enter amounts. Total expense will be calculated automatically.',
                      style: TextStyle(color: Colors.blue[900], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...widget.group.members.map((member) => _buildPayerTile(member)),
            const Divider(height: 24),
            _buildPayersSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPayerTile(Person member) {
    final isSelected = _selectedPayers.contains(member.id);
    final controller = _payerAmountControllers[member.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.teal : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedPayers.add(member.id);
            } else {
              _selectedPayers.remove(member.id);
              controller.text = '0.00';
            }
            _calculateEqualSplit();
          });
        },
        title: Text(
          member.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.teal[900] : Colors.grey[800],
          ),
        ),
        subtitle: isSelected
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Amount paid',
                    prefixIcon: const Icon(
                      Icons.attach_money,
                      size: 18,
                      color: Colors.teal,
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal, width: 2),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _calculateEqualSplit();
                    });
                  },
                  validator: (value) {
                    if (isSelected) {
                      if (value == null || value.isEmpty) {
                        return 'Enter amount';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'Invalid amount';
                      }
                    }
                    return null;
                  },
                ),
              )
            : null,
        secondary: CircleAvatar(
          backgroundColor: isSelected ? Colors.teal : Colors.grey[400],
          child: Text(
            member.name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        activeColor: Colors.teal,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildPayersSummary() {
    final totalPaid = _calculateTotalPaidAmount();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payments, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Total Paid by ${_selectedPayers.length} payer(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.green, size: 24),
                  Text(
                    totalPaid.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Who Participated?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedParticipants.length ==
                          widget.group.members.length) {
                        _selectedParticipants.clear();
                        _selectedParticipants.add(
                          widget.group.members.first.id,
                        );
                      } else {
                        _selectedParticipants.clear();
                        _selectedParticipants.addAll(
                          widget.group.members.map((m) => m.id),
                        );
                      }
                      _calculateEqualSplit();
                    });
                  },
                  icon: Icon(
                    _selectedParticipants.length == widget.group.members.length
                        ? Icons.deselect
                        : Icons.done_all,
                    color: Colors.teal,
                  ),
                  tooltip:
                      _selectedParticipants.length ==
                          widget.group.members.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select people who will share this expense',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Grid of participant cards
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: widget.group.members.length,
              itemBuilder: (context, index) {
                final member = widget.group.members[index];
                return _buildParticipantCard(member);
              },
            ),

            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[50]!, Colors.teal[100]!],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, color: Colors.teal[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedParticipants.length} of ${widget.group.members.length} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[900],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(Person member) {
    final isSelected = _selectedParticipants.contains(member.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_selectedParticipants.length > 1) {
              _selectedParticipants.remove(member.id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('At least one participant required'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            _selectedParticipants.add(member.id);
          }
          _calculateEqualSplit();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal[700]! : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? Colors.white
                        : Colors.teal[100],
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.teal[700] : Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      member.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.teal[700],
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to Split?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<SplitType>(
              segments: const [
                ButtonSegment(
                  value: SplitType.equal,
                  label: Text('Equal'),
                  icon: Icon(Icons.people),
                ),
                ButtonSegment(
                  value: SplitType.custom,
                  label: Text('Custom'),
                  icon: Icon(Icons.edit),
                ),
              ],
              selected: {_splitType},
              onSelectionChanged: (Set<SplitType> newSelection) {
                setState(() {
                  _splitType = newSelection.first;
                  if (_splitType == SplitType.equal) {
                    _calculateEqualSplit();
                  }
                });
              },
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: Colors.teal,
                foregroundColor: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            if (_splitType == SplitType.custom) ..._buildCustomSplitFields(),
            const Divider(height: 24),
            _buildSplitSummary(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCustomSplitFields() {
    return _selectedParticipants.map((participantId) {
      final member = widget.group.members.firstWhere(
        (m) => m.id == participantId,
      );
      final controller = _splitControllers[participantId]!;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: member.name,
            prefixIcon: const Icon(Icons.person, color: Colors.teal),
            suffixIcon: const Icon(Icons.attach_money, color: Colors.teal),
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required';
            if (double.tryParse(value) == null || double.parse(value) < 0) {
              return 'Invalid';
            }
            return null;
          },
        ),
      );
    }).toList();
  }

  Widget _buildSplitSummary() {
    final totalSplit = _selectedParticipants.fold<double>(
      0.0,
      (sum, id) => sum + (double.tryParse(_splitControllers[id]!.text) ?? 0.0),
    );

    final totalExpense = _calculateTotalPaidAmount();
    final difference = totalSplit - totalExpense;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: difference.abs() < 0.01 ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: difference.abs() < 0.01
              ? Colors.green[200]!
              : Colors.red[200]!,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Split:', style: TextStyle(fontSize: 12)),
              Text(
                '\$${totalSplit.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (difference.abs() >= 0.01)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Difference',
                  style: TextStyle(fontSize: 12, color: Colors.red[700]),
                ),
                Text(
                  '\$${difference.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 4),
                Text(
                  'Balanced',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final totalAmount = _calculateTotalPaidAmount();

    return Card(
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Total Expense',
              '\$${totalAmount.toStringAsFixed(2)}',
            ),
            _buildSummaryRow('Paid by ${_selectedPayers.length} person(s)', ''),
            _buildSummaryRow(
              'Split among ${_selectedParticipants.length} person(s)',
              '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _calculateEqualSplit() {
    if (_selectedParticipants.isEmpty) return;

    final totalAmount = _calculateTotalPaidAmount();
    final splitAmount = totalAmount / _selectedParticipants.length;

    for (var participantId in _selectedParticipants) {
      _splitControllers[participantId]!.text = splitAmount.toStringAsFixed(2);
    }

    setState(() {});
  }

  void _autoDistributePayers() {
    setState(() {
      if (_selectedPayers.isEmpty) {
        // Select all participants as payers
        _selectedPayers.addAll(_selectedParticipants);
      }

      final totalAmount = _calculateTotalPaidAmount();
      if (totalAmount <= 0 && _selectedPayers.isNotEmpty) {
        // If no amounts entered yet, set equal amounts (default 100)
        final equalAmount = 100.0 / _selectedPayers.length;
        for (var payerId in _selectedPayers) {
          _payerAmountControllers[payerId]!.text = equalAmount.toStringAsFixed(
            2,
          );
        }
      } else if (_selectedPayers.isNotEmpty) {
        // Redistribute existing total among payers
        final amountPerPayer = totalAmount / _selectedPayers.length;
        for (var payerId in _selectedPayers) {
          _payerAmountControllers[payerId]!.text = amountPerPayer
              .toStringAsFixed(2);
        }
      }

      // Recalculate splits
      _calculateEqualSplit();
    });
  }

  Future<void> _selectDate() async{
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one payer and enter amounts'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one participant'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Calculate total from paid amounts
    final totalExpense = _calculateTotalPaidAmount();

    if (totalExpense <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid payment amounts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate total split equals total expense
    final totalSplit = _selectedParticipants.fold<double>(
      0.0,
      (sum, id) => sum + (double.tryParse(_splitControllers[id]!.text) ?? 0.0),
    );

    if ((totalSplit - totalExpense).abs() >= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total split (\$${totalSplit.toStringAsFixed(2)}) must equal total expense (\$${totalExpense.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Build payers list
    final payers = _selectedPayers.map((id) {
      final person = widget.group.members.firstWhere((m) => m.id == id);
      final amount = double.parse(_payerAmountControllers[id]!.text);
      return PayerShare(person: person, amount: amount);
    }).toList();

    // Build participants list
    final participants = _selectedParticipants
        .map((id) => widget.group.members.firstWhere((m) => m.id == id))
        .toList();

    // Build splits map
    final splits = Map<String, double>.fromEntries(
      _selectedParticipants.map((id) {
        final amount = double.parse(_splitControllers[id]!.text);
        return MapEntry(id, amount);
      }),
    );

    final expense = Expense(
      id: widget.expense?.id ?? const Uuid().v4(),
      groupId: widget.group.id,
      description: _descriptionController.text,
      amount: totalExpense,
      payers: payers,
      participants: participants,
      splits: splits,
      date: _selectedDate,
      category: _selectedCategory,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isSettlement: false,
    );

    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    if (widget.expense == null) {
      // Adding new expense
      provider.addExpense(expense);
      Navigator.pop(context, true); // Return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Updating existing expense
      provider.updateExpense(expense);
      Navigator.pop(context, expense); // Return updated expense

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

enum SplitType { equal, custom }
