import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/expense_provider.dart';
import '../providers/settings_provider.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  final Group group;
  final Expense? expense;

  const AddExpenseScreen({super.key, required this.group, this.expense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  Person? _paidBy;
  final Set<Person> _participants = {};
  final Map<String, double> _customSplits = {};
  String _splitType = 'equal';
  String? _selectedCategory;

  final List<String> _categories = [
    'Food',
    'Transport',
    'Entertainment',
    'Shopping',
    'Accommodation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.expense != null) {
      _loadExistingExpense();
    } else {
      if (widget.group.members.isNotEmpty) {
        _paidBy = widget.group.members.first;
        _participants.addAll(widget.group.members);
      }
    }
  }

  void _loadExistingExpense() {
    final expense = widget.expense!;

    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _selectedCategory = expense.category;
    _paidBy = expense.paidBy;
    _participants.addAll(expense.participants);

    if (expense.splits.isNotEmpty) {
      final firstSplit = expense.splits.values.first;
      final isEqual = expense.splits.values.every(
        (split) => (split - firstSplit).abs() < 0.01,
      );

      _splitType = isEqual ? 'equal' : 'custom';

      if (_splitType == 'custom') {
        _customSplits.addAll(expense.splits);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Map<String, double> _calculateSplits() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final splits = <String, double>{};

    if (_splitType == 'equal') {
      final splitAmount = amount / _participants.length;
      for (var person in _participants) {
        splits[person.id] = splitAmount;
      }
    } else {
      splits.addAll(_customSplits);
    }

    return splits;
  }

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      if (_paidBy == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select who paid'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_participants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final amount = double.parse(_amountController.text);
      final splits = _calculateSplits();

      if (_splitType == 'custom') {
        final totalSplit = splits.values.fold(0.0, (sum, val) => sum + val);
        if ((totalSplit - amount).abs() > 0.01) {
          final currencySymbol = Provider.of<SettingsProvider>(
            context,
            listen: false,
          ).settings.currencySymbol;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Split amounts must equal total: $currencySymbol${amount.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      final expense = Expense(
        id: widget.expense?.id ?? const Uuid().v4(),
        groupId: widget.group.id,
        description: _descriptionController.text.trim(),
        amount: amount,
        paidBy: _paidBy!,
        participants: _participants.toList(),
        splits: splits,
        date: widget.expense?.date ?? DateTime.now(),
        category: _selectedCategory,
      );

      final provider = Provider.of<ExpenseProvider>(context, listen: false);

      if (widget.expense != null) {
        provider.updateExpense(expense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        provider.addExpense(expense);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;
    final currencySymbol = Provider.of<SettingsProvider>(
      context,
    ).settings.currencySymbol;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expense Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What was this for?',
                        prefixIcon: const Icon(Icons.receipt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.attach_money),
                        prefixText: '$currencySymbol ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.teal),
                        hintText: 'Select a category',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(
                          Icons.category,
                          color: Colors.teal,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.teal,
                            width: 2,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.teal[50],
                      style: const TextStyle(color: Colors.teal, fontSize: 16),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paid By',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Person>(
                      value: _paidBy,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.teal,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.teal,
                            width: 2,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.teal[50],
                      style: const TextStyle(color: Colors.teal, fontSize: 16),
                      items: widget.group.members.map((person) {
                        return DropdownMenuItem(
                          value: person,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.teal[100],
                                child: Text(
                                  person.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                person.name,
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _paidBy = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Split Between',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'equal',
                          label: Text('Equal'),
                          icon: Icon(Icons.pie_chart),
                        ),
                        ButtonSegment(
                          value: 'custom',
                          label: Text('Custom'),
                          icon: Icon(Icons.tune),
                        ),
                      ],
                      selected: {_splitType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _splitType = newSelection.first;
                          if (_splitType == 'equal') {
                            _customSplits.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ...widget.group.members.map((person) {
                      final isSelected = _participants.contains(person);
                      final amount =
                          double.tryParse(_amountController.text) ?? 0;
                      final splitAmount = _splitType == 'equal'
                          ? (_participants.isNotEmpty
                                ? amount / _participants.length
                                : 0)
                          : (_customSplits[person.id] ?? 0);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _participants.add(person);
                            } else {
                              _participants.remove(person);
                              _customSplits.remove(person.id);
                            }
                          });
                        },
                        title: Text(person.name),
                        subtitle: isSelected
                            ? Text(
                                '$currencySymbol${splitAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.teal[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                        secondary: CircleAvatar(
                          backgroundColor: Colors.teal[100],
                          child: Text(
                            person.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                        ),
                      );
                    }),
                    if (_splitType == 'custom' && _participants.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'Custom Split Amounts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._participants.map((person) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(person.name)),
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      _customSplits[person.id]?.toStringAsFixed(
                                        2,
                                      ) ??
                                      '',
                                  decoration: InputDecoration(
                                    prefixText: '$currencySymbol ',
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Colors.teal,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d{0,2}'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    final amount = double.tryParse(value) ?? 0;
                                    setState(() {
                                      _customSplits[person.id] = amount;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_customSplits.isNotEmpty) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Split:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$currencySymbol${_customSplits.values.fold(0.0, (sum, val) => sum + val).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveExpense,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEditing ? 'Update Expense' : 'Add Expense',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
