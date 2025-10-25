import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_list.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _expenseFormKey = GlobalKey<FormState>();
  final _incomeFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isExpense = true;

  @override
  void initState() {
    super.initState();
    print('AddExpenseScreen initialized'); // Debug
    _listenToConnectivity();
    _syncPendingTransactions();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      print('Connectivity changed: $result'); // Debug
      if (!result.contains(ConnectivityResult.none)) {
        _syncPendingTransactions();
      }
    });
  }

  Future<void> _saveTransaction(GlobalKey<FormState> formKey, bool isExpense) async {
    print('Attempting to save transaction (isExpense: $isExpense)'); // Debug
    if (!formKey.currentState!.validate()) {
      print('Form validation failed'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save transactions')),
        );
      }
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      print('Invalid amount: ${_amountController.text}'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number for amount')),
        );
      }
      return;
    }

    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      print('Empty category'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category cannot be empty')),
        );
      }
      return;
    }

    final note = _noteController.text.trim();
    final type = isExpense ? 'expense' : 'income';

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    print('Connectivity: ${isOffline ? 'Offline' : 'Online'}'); // Debug

    final transactionData = {
      'amount': amount,
      'category': category,
      'note': note,
      'date': _selectedDate.toIso8601String(),
      'type': type,
      'userId': user.uid,
    };

    try {
      if (isOffline) {
        final prefs = await SharedPreferences.getInstance();
        List<String> pending = prefs.getStringList('pending_transactions') ?? [];
        pending.add(jsonEncode(transactionData));
        await prefs.setStringList('pending_transactions', pending);
        print('Saved offline: $transactionData'); // Debug
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved locally, will sync when online')),
          );
        }
      } else {
        // Save category
        final categoriesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('categories');
        final exists = await categoriesRef
            .where('name', isEqualTo: category)
            .where('type', isEqualTo: type)
            .limit(1)
            .get();
        if (exists.docs.isEmpty) {
          await categoriesRef.add({
            'name': category,
            'type': type,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Added category: $category ($type)'); // Debug
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
        print('Saved online: $transactionData'); // Debug

        // Clear pending transactions
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_transactions');
        print('Cleared pending transactions'); // Debug

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction added successfully!')),
          );
        }
      }

      // Clear form
      setState(() {
        _amountController.clear();
        _categoryController.clear();
        _noteController.clear();
      });

      // Navigate to TransactionList
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionList(selectedDate: _selectedDate),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('ERROR SAVING TRANSACTION: $e\n$stackTrace'); // Debug with stack trace
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  Future<void> _syncPendingTransactions() async {
    print('Checking for pending transactions'); // Debug
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_transactions') ?? [];
    if (pending.isEmpty) {
      print('No pending transactions'); // Debug
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in for sync'); // Debug
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('Offline, skipping sync'); // Debug
      return;
    }

    try {
      for (final transactionJson in pending) {
        final data = jsonDecode(transactionJson) as Map<String, dynamic>;
        final dateStr = data['date'] as String?;
        if (dateStr == null) {
          print('Invalid date in pending transaction: $data'); // Debug
          continue;
        }
        data['date'] = Timestamp.fromDate(DateTime.parse(dateStr));
        final category = data['category'] as String;
        final type = data['type'] as String;

        // Save category
        final categoriesRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('categories');
        final exists = await categoriesRef
            .where('name', isEqualTo: category)
            .where('type', isEqualTo: type)
            .limit(1)
            .get();
        if (exists.docs.isEmpty) {
          await categoriesRef.add({
            'name': category,
            'type': type,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Synced category: $category ($type)'); // Debug
        }

        // Save transaction
        await FirebaseFirestore.instance.collection('transactions').add(data);
        print('Synced transaction: $data'); // Debug
      }
      // Clear pending transactions
      await prefs.remove('pending_transactions');
      print('Cleared pending transactions after sync'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline transactions synced!')),
        );
      }
    } catch (e, stackTrace) {
      print('ERROR SYNCING TRANSACTIONS: $e\n$stackTrace'); // Debug with stack trace
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing transactions: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      print('Selected date: $_selectedDate'); // Debug
    }
  }

  @override
  void dispose() {
    print('Disposing AddExpenseScreen'); // Debug
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building AddExpenseScreen'); // Debug
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense / Income'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Expense'),
                  Tab(text: 'Income'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTransactionForm(true, _expenseFormKey),
                    _buildTransactionForm(false, _incomeFormKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionForm(bool isExpense, GlobalKey<FormState> formKey) {
    _isExpense = isExpense; // Ensure _isExpense is updated
    print('Building form (isExpense: $isExpense)'); // Debug
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter amount';
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
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter category';
              }
              return null;
            },
            onChanged: (value) {
              print('Entered category: $value'); // Debug
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
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
            onPressed: () => _saveTransaction(formKey, isExpense),
            child: Text(isExpense ? 'Save Expense' : 'Save Income'),
          ),
        ],
      ),
    );
  }
}