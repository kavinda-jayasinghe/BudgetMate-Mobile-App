// add_expense_income_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddExpenseIncomeDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Function(String, double, String) onSave;

  const AddExpenseIncomeDialog({
    Key? key,
    required this.selectedDate,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddExpenseIncomeDialogState createState() => _AddExpenseIncomeDialogState();
}

class _AddExpenseIncomeDialogState extends State<AddExpenseIncomeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isExpense = true;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense/Income'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButtons(
              isSelected: [_isExpense, !_isExpense],
              onPressed: (int index) {
                setState(() {
                  _isExpense = index == 0;
                });
              },
              children: const [Text('Expense'), Text('Income')],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
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

              try {
                await FirebaseFirestore.instance.collection('transactions').add({
                  'amount': amount,
                  'category': category,
                  'note': note,
                  'date': Timestamp.fromDate(widget.selectedDate), // Store as Timestamp
                  'type': _isExpense ? 'expense' : 'income',
                  'userId': user.uid, // Add userId
                });

                widget.onSave(category, amount, note);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction added successfully!')),
                );

                _amountController.clear();
                _categoryController.clear();
                _noteController.clear();

                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}