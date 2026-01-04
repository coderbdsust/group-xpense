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
  final _amountController = TextEditingController();
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
      _amountController.text = widget.expense!.amount.toStringAsFixed(2);
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

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
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
          IconButton(icon: const Icon(Icons.check), onPressed: _saveExpense),
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
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Total Amount *',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => _calculateEqualSplit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null ||
                    double.parse(value) <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectDate,
            ),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add additional details',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
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
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more people who paid for this expense',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

    return CheckboxListTile(
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _selectedPayers.add(member.id);
          } else {
            _selectedPayers.remove(member.id);
            controller.text = '0.00';
          }
        });
      },
      title: Text(member.name),
      subtitle: isSelected
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Amount paid',
                  prefixIcon: Icon(Icons.attach_money, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
        backgroundColor: isSelected ? Colors.teal : Colors.grey[300],
        child: Text(
          member.name[0].toUpperCase(),
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildPayersSummary() {
    final totalPaid = _selectedPayers.fold<double>(
      0.0,
      (sum, id) =>
          sum + (double.tryParse(_payerAmountControllers[id]!.text) ?? 0.0),
    );

    final totalExpense = double.tryParse(_amountController.text) ?? 0.0;
    final difference = totalPaid - totalExpense;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: difference.abs() < 0.01 ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: difference.abs() < 0.01
              ? Colors.green[200]!
              : Colors.orange[200]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Paid:', style: TextStyle(fontSize: 12)),
              Text(
                '\$${totalPaid.toStringAsFixed(2)}',
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
                  difference > 0 ? 'Overpaid' : 'Underpaid',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
                Text(
                  '\$${difference.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
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
                      if (_selectedParticipants.length == widget.group.members.length) {
                        _selectedParticipants.clear();
                        _selectedParticipants.add(widget.group.members.first.id);
                      } else {
                        _selectedParticipants.clear();
                        _selectedParticipants.addAll(widget.group.members.map((m) => m.id));
                      }
                      _calculateEqualSplit();
                    });
                  },
                  icon: Icon(
                    _selectedParticipants.length == widget.group.members.length
                        ? Icons.deselect
                        : Icons.done_all,
                  ),
                  tooltip: _selectedParticipants.length == widget.group.members.length
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
                    backgroundColor: isSelected ? Colors.white : Colors.teal[100],
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
  Widget _buildParticipantTile(Person member) {
    final isSelected = _selectedParticipants.contains(member.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
        onChanged: (selected) {
          setState(() {
            if (selected == true) {
              _selectedParticipants.add(member.id);
            } else {
              if (_selectedParticipants.length > 1) {
                _selectedParticipants.remove(member.id);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least one participant required'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
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
            ? Text(
          'Participating',
          style: TextStyle(
            color: Colors.teal[700],
            fontSize: 12,
          ),
        )
            : null,
        secondary: CircleAvatar(
          backgroundColor: isSelected ? Colors.teal : Colors.grey[400],
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(
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
            prefixIcon: const Icon(Icons.person),
            suffixIcon: const Icon(Icons.attach_money),
            border: const OutlineInputBorder(),
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

    final totalExpense = double.tryParse(_amountController.text) ?? 0.0;
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
              '\$${(double.tryParse(_amountController.text) ?? 0.0).toStringAsFixed(2)}',
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

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    final splitAmount = totalAmount / _selectedParticipants.length;

    for (var participantId in _selectedParticipants) {
      _splitControllers[participantId]!.text = splitAmount.toStringAsFixed(2);
    }

    setState(() {});
  }

  void _autoDistributePayers() {
    if (_selectedPayers.isEmpty) {
      // Select all participants as payers
      setState(() {
        _selectedPayers.addAll(_selectedParticipants);
      });
    }

    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0 || _selectedPayers.isEmpty) return;

    final amountPerPayer = totalAmount / _selectedPayers.length;

    for (var payerId in _selectedPayers) {
      _payerAmountControllers[payerId]!.text = amountPerPayer.toStringAsFixed(
        2,
      );
    }

    setState(() {});
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
          content: Text('Please select at least one payer'),
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

    // Validate total paid equals total expense
    final totalPaid = _selectedPayers.fold<double>(
      0.0,
      (sum, id) =>
          sum + (double.tryParse(_payerAmountControllers[id]!.text) ?? 0.0),
    );
    final totalExpense = double.parse(_amountController.text);

    if ((totalPaid - totalExpense).abs() >= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total paid must equal total expense'),
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
        const SnackBar(
          content: Text('Total split must equal total expense'),
          backgroundColor: Colors.red,
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
      provider.addExpense(expense);
    } else {
      provider.updateExpense(expense);
    }

    Navigator.pop(context);
  }
}

enum SplitType { equal, custom }
