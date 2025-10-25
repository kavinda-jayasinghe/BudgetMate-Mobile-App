import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print('AddExpenseScreen: Initialized'); // Debug
    _listenToConnectivity();
    _syncPendingTransactions();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      print('AddExpenseScreen: Connectivity changed: $result'); // Debug
      if (!result.contains(ConnectivityResult.none)) {
        _syncPendingTransactions();
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        print('AddExpenseScreen: Image picked: ${pickedFile.path}'); // Debug
      } else {
        print('AddExpenseScreen: No image selected'); // Debug
      }
    } catch (e) {
      print('AddExpenseScreen: Image picker error: $e'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File image, String userId, String transactionId) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child(userId)
          .child('$transactionId.jpg');
      final uploadTask = await storageRef.putFile(image);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('AddExpenseScreen: Image uploaded: $downloadUrl'); // Debug
      return downloadUrl;
    } catch (e) {
      print('AddExpenseScreen: Image upload error: $e'); // Debug
      return null;
    }
  }

  Future<void> _saveTransaction(GlobalKey<FormState> formKey, bool isExpense) async {
    print('AddExpenseScreen: Saving transaction (isExpense: $isExpense)'); // Debug
    if (!formKey.currentState!.validate()) {
      print('AddExpenseScreen: Form validation failed'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('AddExpenseScreen: No user logged in'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save transactions')),
        );
      }
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      print('AddExpenseScreen: Invalid amount: ${_amountController.text}'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid positive number for amount')),
        );
      }
      return;
    }

    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      print('AddExpenseScreen: Empty category'); // Debug
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
    print('AddExpenseScreen: Connectivity: ${isOffline ? 'Offline' : 'Online'}'); // Debug

    final transactionData = {
      'amount': amount,
      'category': category,
      'note': note,
      'date': _selectedDate.toIso8601String(),
      'type': type,
      'userId': user.uid,
      'receiptUrl': null, // Placeholder for receipt URL
    };

    try {
      if (isOffline) {
        final prefs = await SharedPreferences.getInstance();
        List<String> pending = prefs.getStringList('pending_transactions') ?? [];
        final pendingTransaction = {
          'transaction': transactionData,
          'imagePath': _selectedImage?.path,
        };
        pending.add(jsonEncode(pendingTransaction));
        await prefs.setStringList('pending_transactions', pending);
        print('AddExpenseScreen: Saved offline: $pendingTransaction'); // Debug
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved locally, will sync when online')),
          );
        }
      } else {
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
          print('AddExpenseScreen: Added category: $category ($type)'); // Debug
        }

        final docRef = await FirebaseFirestore.instance.collection('transactions').add({
          'amount': amount,
          'category': category,
          'note': note,
          'date': Timestamp.fromDate(_selectedDate),
          'type': type,
          'userId': user.uid,
          'receiptUrl': null, // Will update if image exists
        });

        String? receiptUrl;
        if (_selectedImage != null) {
          receiptUrl = await _uploadImage(_selectedImage!, user.uid, docRef.id);
          if (receiptUrl != null) {
            await docRef.update({'receiptUrl': receiptUrl});
            print('AddExpenseScreen: Updated transaction with receiptUrl: $receiptUrl'); // Debug
          }
        }

        print('AddExpenseScreen: Saved online: ${{
          ...transactionData,
          'receiptUrl': receiptUrl,
        }}'); // Debug

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_transactions');
        print('AddExpenseScreen: Cleared pending transactions'); // Debug

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction added successfully!')),
          );
        }
      }

      setState(() {
        _amountController.clear();
        _categoryController.clear();
        _noteController.clear();
        _selectedImage = null;
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('AddExpenseScreen: ERROR SAVING TRANSACTION: $e\n$stackTrace'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  Future<void> _syncPendingTransactions() async {
    print('AddExpenseScreen: Checking for pending transactions'); // Debug
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_transactions') ?? [];
    if (pending.isEmpty) {
      print('AddExpenseScreen: No pending transactions'); // Debug
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('AddExpenseScreen: No user logged in for sync'); // Debug
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('AddExpenseScreen: Offline, skipping sync'); // Debug
      return;
    }

    try {
      for (final transactionJson in List.from(pending)) {
        final pendingTransaction = jsonDecode(transactionJson) as Map<String, dynamic>;
        final transactionData = pendingTransaction['transaction'] as Map<String, dynamic>;
        final imagePath = pendingTransaction['imagePath'] as String?;
        final dateStr = transactionData['date'] as String?;
        if (dateStr == null) {
          print('AddExpenseScreen: Invalid date in pending transaction: $transactionData'); // Debug
          continue;
        }
        try {
          transactionData['date'] = Timestamp.fromDate(DateTime.parse(dateStr));
        } catch (e) {
          print('AddExpenseScreen: Failed to parse date: $dateStr'); // Debug
          continue;
        }
        final category = transactionData['category'] as String? ?? 'Unknown';
        final type = transactionData['type'] as String? ?? 'unknown';

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
          print('AddExpenseScreen: Synced category: $category ($type)'); // Debug
        }

        final docRef = await FirebaseFirestore.instance.collection('transactions').add({
          ...transactionData,
          'receiptUrl': null, // Will update if image exists
        });

        String? receiptUrl;
        if (imagePath != null && File(imagePath).existsSync()) {
          receiptUrl = await _uploadImage(File(imagePath), user.uid, docRef.id);
          if (receiptUrl != null) {
            await docRef.update({'receiptUrl': receiptUrl});
            print('AddExpenseScreen: Synced transaction with receiptUrl: $receiptUrl'); // Debug
          }
        }

        print('AddExpenseScreen: Synced transaction: ${{
          ...transactionData,
          'receiptUrl': receiptUrl,
        }}'); // Debug
      }
      await prefs.remove('pending_transactions');
      print('AddExpenseScreen: Cleared pending transactions after sync'); // Debug
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline transactions synced!')),
        );
      }
    } catch (e, stackTrace) {
      print('AddExpenseScreen: ERROR SYNCING TRANSACTIONS: $e\n$stackTrace'); // Debug
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
      print('AddExpenseScreen: Selected date: $_selectedDate'); // Debug
    }
  }

  @override
  void dispose() {
    print('AddExpenseScreen: Disposing'); // Debug
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('AddExpenseScreen: Building'); // Debug
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
    _isExpense = isExpense;
    print('AddExpenseScreen: Building form (isExpense: $isExpense)'); // Debug
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
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Enter a valid positive number';
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
              print('AddExpenseScreen: Entered category: $value'); // Debug
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
          ListTile(
            title: Text(
              _selectedImage == null ? 'Add Receipt Photo' : 'Receipt Photo Selected',
              style: TextStyle(
                color: _selectedImage == null ? Colors.grey : Colors.green,
              ),
            ),
            trailing: const Icon(Icons.camera_alt),
            onTap: _pickImage,
          ),
          if (_selectedImage != null) ...[
            const SizedBox(height: 16),
            Image.file(
              _selectedImage!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          ],
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