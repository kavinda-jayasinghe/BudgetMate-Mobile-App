import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _expenseFormKey = GlobalKey<FormState>();
  final _incomeFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _customCategoryController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isExpense = true;

  // Predefined categories
  List<String> _expenseCategories = ['Food', 'Entertainment', 'Bill', 'Transport', 'Custom'];
  List<String> _incomeCategories = ['Salary', 'Trading', 'Vlogging', 'Custom'];

  // Selected category
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories(); // Load categories from Firestore
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      final expenseCategories = <String>[];
      final incomeCategories = <String>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        final type = data['type'] as String?;
        if (name != null && type != null) {
          if (type == 'expense') {
            expenseCategories.add(name);
          } else if (type == 'income') {
            incomeCategories.add(name);
          }
        }
      }

      setState(() {
        _expenseCategories = ['Food', 'Entertainment', 'Bill', 'Transport', ...expenseCategories, 'Custom'];
        _incomeCategories = ['Salary', 'Trading', 'Vlogging', ...incomeCategories, 'Custom'];
        // Reset _selectedCategory if it’s invalid for the current tab
        if (_selectedCategory != null) {
          final currentCategories = _isExpense ? _expenseCategories : _incomeCategories;
          if (!currentCategories.contains(_selectedCategory)) {
            _selectedCategory = null;
          }
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  Future<void> _saveExpenseIncome(GlobalKey<FormState> formKey) async {
    if (formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save transactions')),
        );
        return;
      }

      final amount = double.tryParse(_amountController.text);
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid amount entered')),
        );
        return;
      }

      final category = _selectedCategory == 'Custom' ? _categoryController.text.trim() : _selectedCategory;
      if (category == null || category.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a category')),
        );
        return;
      }

      final note = _noteController.text;
      final type = _isExpense ? 'expense' : 'income';

      try {
        // Save custom category to Firestore
        if (_selectedCategory == 'Custom' && category.isNotEmpty) {
          final categoriesCollection = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('categories');
          if (_isExpense && !_expenseCategories.contains(category)) {
            await categoriesCollection.add({
              'name': category,
              'type': 'expense',
              'createdAt': Timestamp.now(),
            });
            setState(() {
              _expenseCategories.insert(_expenseCategories.length - 1, category);
            });
          } else if (!_isExpense && !_incomeCategories.contains(category)) {
            await categoriesCollection.add({
              'name': category,
              'type': 'income',
              'createdAt': Timestamp.now(),
            });
            setState(() {
              _incomeCategories.insert(_incomeCategories.length - 1, category);
            });
          }
        }

        // Save transaction
        await FirebaseFirestore.instance.collection('transactions').add({
          'amount': amount,
          'category': category,
          'note': note,
          'date': Timestamp.fromDate(_selectedDate),
          'type': type,
          'userId': user.uid,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added successfully!')),
        );

        // Clear form
        setState(() {
          _amountController.clear();
          _categoryController.clear();
          _noteController.clear();
          _selectedCategory = null;
        });
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense/Income'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Expense'),
                  Tab(text: 'Income'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTransactionForm(isExpense: true, formKey: _expenseFormKey),
                    _buildTransactionForm(isExpense: false, formKey: _incomeFormKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionForm({required bool isExpense, required GlobalKey<FormState> formKey}) {
    final categories = isExpense ? _expenseCategories : _incomeCategories;

    // Reset _selectedCategory if it’s invalid for the current tab
    if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
      _selectedCategory = null;
      _categoryController.clear();
    }

    return Form(
      key: formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              if (double.tryParse(value) == null) {
                return 'Enter a valid number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: categories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _isExpense = isExpense;
                _selectedCategory = value;
                if (value != 'Custom') {
                  _categoryController.clear();
                }
              });
              if (value == 'Custom') {
                _showCustomCategoryDialog(context, isExpense);
              }
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a category';
              }
              if (value == 'Custom' && _categoryController.text.trim().isEmpty) {
                return 'Please enter a custom category';
              }
              return null;
            },
          ),
          if (_selectedCategory == 'Custom') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Custom Category',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_selectedCategory == 'Custom' && (value == null || value.trim().isEmpty)) {
                  return 'Please enter a custom category';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('Date: ${DateFormat.yMMMMd().format(_selectedDate)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _saveExpenseIncome(formKey),
            child: Text(isExpense ? 'Save Expense' : 'Save Income'),
          ),
        ],
      ),
    );
  }

  void _showCustomCategoryDialog(BuildContext context, bool isExpense) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
          content: TextField(
            controller: _customCategoryController,
            decoration: const InputDecoration(labelText: 'New Category'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedCategory = null;
                  _categoryController.clear();
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newCategory = _customCategoryController.text.trim();
                if (newCategory.isNotEmpty) {
                  setState(() {
                    if (isExpense && !_expenseCategories.contains(newCategory)) {
                      _expenseCategories.insert(_expenseCategories.length - 1, newCategory);
                    } else if (!isExpense && !_incomeCategories.contains(newCategory)) {
                      _incomeCategories.insert(_incomeCategories.length - 1, newCategory);
                    }
                    _selectedCategory = 'Custom';
                    _categoryController.text = newCategory;
                  });
                }
                _customCategoryController.clear();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}