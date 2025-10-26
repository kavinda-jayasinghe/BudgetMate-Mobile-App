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
import 'package:cached_network_image/cached_network_image.dart'; // Import the package

class Transaction {
  final String? id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String type;
  final String userId;
  final String? receiptUrl;

  Transaction({
    this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    required this.type,
    required this.userId,
    this.receiptUrl,
  });
}

class AddExpenseScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddExpenseScreen({super.key, this.transaction});

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
  String? _existingReceiptUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print('AddExpenseScreen: Initialized');
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!.amount.toString();
      _categoryController.text = widget.transaction!.category;
      _noteController.text = widget.transaction!.note;
      _selectedDate = widget.transaction!.date;
      _isExpense = widget.transaction!.type == 'expense';
      _existingReceiptUrl = widget.transaction!.receiptUrl;
      print('AddExpenseScreen: Editing transaction: ${widget.transaction!.id}');
    }
    _listenToConnectivity();
    _syncPendingTransactions();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      print('AddExpenseScreen: Connectivity changed: $result');
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
          _existingReceiptUrl = null; // Clear existing URL if new image is picked
        });
        print('AddExpenseScreen: Image picked: ${pickedFile.path}');
      } else {
        print('AddExpenseScreen: No image selected');
      }
    } catch (e) {
      print('AddExpenseScreen: Image picker error: $e');
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
      print('AddExpenseScreen: Image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('AddExpenseScreen: Image upload error: $e');
      return null;
    }
  }

Future<void> _saveTransaction(GlobalKey<FormState> formKey, bool isExpense) async {
  print('AddExpenseScreen: Saving transaction (isExpense: $isExpense)');
  if (!formKey.currentState!.validate()) {
    print('AddExpenseScreen: Form validation failed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
    }
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('AddExpenseScreen: No user logged in');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save transactions')),
      );
    }
    return;
  }

  final amount = double.tryParse(_amountController.text.trim());
  if (amount == null || amount <= 0) {
    print('AddExpenseScreen: Invalid amount: ${_amountController.text}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid positive number for amount')),
      );
    }
    return;
  }

  final category = _categoryController.text.trim();
  if (category.isEmpty) {
    print('AddExpenseScreen: Empty category');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category cannot be empty')),
      );
    }
    return;
  }

  final note = _noteController.text.trim();
  final type = isExpense ? 'expense' : 'income';
  final transactionId = widget.transaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Convert Timestamp to ISO 8601 string for JSON serialization
  final transactionData = {
    'amount': amount,
    'category': category,
    'note': note,
    'date': _selectedDate.toIso8601String(), // Store as string
    'type': type,
    'userId': user.uid,
    'receiptUrl': _existingReceiptUrl,
  };

  final connectivityResult = await Connectivity().checkConnectivity();
  final isOffline = connectivityResult.contains(ConnectivityResult.none);
  print('AddExpenseScreen: Connectivity: ${isOffline ? 'Offline' : 'Online'}');

  try {
    if (isOffline) {
      final prefs = await SharedPreferences.getInstance();
      List<String> pending = prefs.getStringList('pending_transactions') ?? [];
      final pendingTransaction = {
        'transaction': transactionData,
        'imagePath': _selectedImage?.path,
        'id': transactionId,
      };
      pending.add(jsonEncode(pendingTransaction));
      await prefs.setStringList('pending_transactions', pending);
      print('AddExpenseScreen: Saved offline: $pendingTransaction');
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
        print('AddExpenseScreen: Added category: $category ($type)');
      }

      String? receiptUrl = _existingReceiptUrl;
      if (_selectedImage != null) {
        receiptUrl = await _uploadImage(_selectedImage!, user.uid, transactionId);
        if (receiptUrl == null) {
          throw Exception('Failed to upload receipt image');
        }
      }

      final docRef = FirebaseFirestore.instance.collection('transactions').doc(transactionId);
      await docRef.set({
        ...transactionData,
        'date': Timestamp.fromDate(_selectedDate), // Restore as Timestamp for Firestore
        'receiptUrl': receiptUrl,
      });
      print('AddExpenseScreen: Saved transaction: $transactionId with receiptUrl: $receiptUrl');

      // Clear pending transactions after successful save
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_transactions');
      print('AddExpenseScreen: Cleared pending transactions');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully!')),
        );
      }
    }

    setState(() {
      _amountController.clear();
      _categoryController.clear();
      _noteController.clear();
      _selectedImage = null;
      _existingReceiptUrl = null;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e, stackTrace) {
    print('AddExpenseScreen: Error saving transaction: $e\n$stackTrace');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving transaction: $e')),
      );
    }
  }
}

Future<void> _syncPendingTransactions() async {
  print('AddExpenseScreen: Checking for pending transactions');
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList('pending_transactions') ?? [];
  if (pending.isEmpty) {
    print('AddExpenseScreen: No pending transactions');
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('AddExpenseScreen: No user logged in for sync');
    return;
  }

  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult.contains(ConnectivityResult.none)) {
    print('AddExpenseScreen: Offline, skipping sync');
    return;
  }

  try {
    for (final transactionJson in List.from(pending)) {
      final pendingTransaction = jsonDecode(transactionJson) as Map<String, dynamic>;
      final transactionData = Map<String, dynamic>.from(pendingTransaction['transaction']);
      final imagePath = pendingTransaction['imagePath'] as String?;
      final transactionId = pendingTransaction['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Convert date string to Timestamp
      if (transactionData['date'] is String) {
        transactionData['date'] = Timestamp.fromDate(DateTime.parse(transactionData['date']));
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
        print('AddExpenseScreen: Synced category: $category ($type)');
      }

      String? receiptUrl;
      if (imagePath != null && File(imagePath).existsSync()) {
        receiptUrl = await _uploadImage(File(imagePath), user.uid, transactionId);
        print('AddExpenseScreen: Synced receiptUrl: $receiptUrl');
      }

      final docRef = FirebaseFirestore.instance.collection('transactions').doc(transactionId);
      await docRef.set({
        ...transactionData,
        'receiptUrl': receiptUrl,
      });
      print('AddExpenseScreen: Synced transaction: $transactionId');
    }

    await prefs.remove('pending_transactions');
    print('AddExpenseScreen: Cleared pending transactions after sync');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline transactions synced!')),
      );
    }
  } catch (e, stackTrace) {
    print('AddExpenseScreen: Error syncing transactions: $e\n$stackTrace');
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
      print('AddExpenseScreen: Selected date: $_selectedDate');
    }
  }

  @override
  void dispose() {
    print('AddExpenseScreen: Disposing');
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('AddExpenseScreen: Building');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null ? 'Edit Transaction' : 'Add Expense / Income'),
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
    print('AddExpenseScreen: Building form (isExpense: $isExpense)');
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
              print('AddExpenseScreen: Entered category: $value');
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
              _selectedImage != null
                  ? 'Receipt Photo Selected'
                  : _existingReceiptUrl != null
                      ? 'Existing Receipt'
                      : 'Add Receipt Photo',
              style: TextStyle(
                color: _selectedImage != null || _existingReceiptUrl != null ? Colors.green : Colors.grey,
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
          if (_existingReceiptUrl != null && _selectedImage == null) ...[
            const SizedBox(height: 16),
            CachedNetworkImage( // Correct usage as a widget
              imageUrl: _existingReceiptUrl!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) {
                print('AddExpenseScreen: Existing receipt load error: $error');
                return const Icon(Icons.error, color: Colors.red);
              },
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _saveTransaction(formKey, isExpense),
            child: Text(widget.transaction != null ? 'Update Transaction' : 'Save Transaction'),
          ),
        ],
      ),
    );
  }
}