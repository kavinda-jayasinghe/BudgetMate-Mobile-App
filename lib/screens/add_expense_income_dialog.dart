import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // Import Firestore

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

  bool _isExpense = true; // Switch between Expense and Income

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense/Income'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expense/Income Toggle Tabs
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

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Category
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

            // Note
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
              final amount = double.parse(_amountController.text);
              final category = _categoryController.text;
              final note = _noteController.text;

              // Save the Expense/Income to Firestore
              await FirebaseFirestore.instance.collection('transactions').add({
                'amount': amount,
                'category': category,
                'note': note,
                'date': widget.selectedDate,  // Store selected date
                'type': _isExpense ? 'expense' : 'income', // Expense or income type
              });

              // Notify the parent widget (HomeScreen)
              widget.onSave(category, amount, note);

              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
