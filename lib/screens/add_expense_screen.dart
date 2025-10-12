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
  final _expenseFormKey = GlobalKey<FormState>(); // Key for Expense form
  final _incomeFormKey = GlobalKey<FormState>(); // Key for Income form
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isExpense = true;

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

    final category = _categoryController.text;
    final note = _noteController.text;
    final type = _isExpense ? 'expense' : 'income';

    try {
      await FirebaseFirestore.instance.collection('transactions').add({
        'amount': amount,
        'category': category,
        'note': note,
        'date': Timestamp.fromDate(_selectedDate),
        'type': type,
        'userId': user.uid, // Add userId to filter transactions
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added successfully!')),
      );

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense/Income'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
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
    setState(() {
      _isExpense = isExpense;
    });
    return Form(
      key: formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
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
          TextFormField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Category'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a category';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('Date: ${DateFormat.yMMMMd().format(_selectedDate)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _saveExpenseIncome(formKey),
            child: Text(isExpense ? 'Save Expense' : 'Save Income'),
          ),
        ],
      ),
    );
  }
}