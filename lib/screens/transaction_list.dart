import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'add_expense_screen.dart' as expense; // Alias to avoid conflict
import 'statistics_screen.dart';
import 'auth_page.dart';

class TransactionList extends StatefulWidget {
  final DateTime selectedDate;

  const TransactionList({super.key, required this.selectedDate});

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    print('TransactionList: Initialized with $_selectedDate');
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
    print('TransactionList: Changed to previous month: $_selectedDate');
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
    print('TransactionList: Changed to next month: $_selectedDate');
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      print('TransactionList: Signed out successfully');
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('TransactionList: Sign-out error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _showReceiptDialog(String? receiptUrl) {
    if (receiptUrl == null || receiptUrl.isEmpty) {
      print('TransactionList: No receipt URL provided');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No receipt available for this transaction')),
      );
      return;
    }
    print('TransactionList: Showing receipt dialog for URL: $receiptUrl');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CachedNetworkImage(
                imageUrl: receiptUrl,
                height: 300,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, error) {
                  print('TransactionList: Image load error: $error');
                  return const Icon(Icons.error, color: Colors.red);
                },
              ),
            ),
            TextButton(
              onPressed: () {
                print('TransactionList: Closing receipt dialog');
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTransaction(DocumentSnapshot transaction) async {
    final data = transaction.data() as Map<String, dynamic>;
    if (!data.containsKey('amount') ||
        !data.containsKey('category') ||
        !data.containsKey('date') ||
        !data.containsKey('type')) {
      print('TransactionList: Invalid transaction data for edit: $data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid transaction data')),
      );
      return;
    }

    final date = data['date'] is Timestamp
        ? (data['date'] as Timestamp).toDate()
        : DateTime.now();
    final transactionObj = expense.Transaction( // Use alias
      id: transaction.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] as String? ?? 'Unknown',
      note: data['note'] as String? ?? '',
      date: date,
      type: data['type'] as String? ?? 'unknown',
      userId: data['userId'] as String? ?? '',
      receiptUrl: data['receiptUrl'] as String?,
    );

    print('TransactionList: Navigating to edit transaction: ${transaction.id}');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => expense.AddExpenseScreen(transaction: transactionObj),
      ),
    );
  }

  Future<void> _deleteTransaction(String transactionId, String? receiptUrl) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('TransactionList: Delete cancelled for transaction: $transactionId');
      return;
    }

    try {
      // Delete transaction from Firestore
      await FirebaseFirestore.instance.collection('transactions').doc(transactionId).delete();
      print('TransactionList: Deleted transaction: $transactionId');

      // Delete receipt image from Storage if exists
      if (receiptUrl != null && receiptUrl.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('receipts')
              .child(user.uid)
              .child('$transactionId.jpg');
          await storageRef.delete();
          print('TransactionList: Deleted receipt image: $receiptUrl');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully')),
        );
      }
    } catch (e) {
      print('TransactionList: Error deleting transaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('TransactionList: No user logged in');
      return const Center(child: Text('Please log in to view transactions'));
    }

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    print('TransactionList: Querying for $startOfMonth to $endOfMonth');

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, connectivitySnapshot) {
        final isOffline = connectivitySnapshot.hasData &&
            connectivitySnapshot.data!.contains(ConnectivityResult.none);
        print('TransactionList: Connectivity: ${isOffline ? 'Offline' : 'Online'}');

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            actions: [
              IconButton(
                icon: const Icon(Icons.pie_chart, color: Colors.white),
                tooltip: 'View Statistics',
                onPressed: () {
                  print('TransactionList: Navigating to StatisticsScreen');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatisticsScreen(selectedDate: _selectedDate),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Sign Out',
                onPressed: () => _signOut(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            onPressed: () {
              print('TransactionList: Navigating to AddExpenseScreen');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const expense.AddExpenseScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_left, color: Colors.indigo),
                      onPressed: _previousMonth,
                      tooltip: 'Previous Month',
                    ),
                    Text(
                      '${DateFormat.yMMMM().format(_selectedDate)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_right, color: Colors.indigo),
                      onPressed: _nextMonth,
                      tooltip: 'Next Month',
                    ),
                  ],
                ),
              ),
              if (isOffline)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Offline mode: showing cached data',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('userId', isEqualTo: user.uid)
                      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print('TransactionList: Waiting for data');
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      print('TransactionList: Error: ${snapshot.error}');
                      return Center(
                        child: Text(
                          isOffline
                              ? 'Offline: Showing cached data'
                              : 'Error: ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      print('TransactionList: No transactions found');
                      return Center(
                        child: Text(
                          isOffline
                              ? 'No cached transactions for this month'
                              : 'No transactions for this month',
                        ),
                      );
                    }

                    final transactions = snapshot.data!.docs;
                    print('TransactionList: Found ${transactions.length} transactions');

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final data = transaction.data() as Map<String, dynamic>;
                        print('TransactionList: Transaction $index: $data (date type: ${data['date'].runtimeType}, receiptUrl: ${data['receiptUrl']})');

                        if (!data.containsKey('amount') ||
                            !data.containsKey('category') ||
                            !data.containsKey('date') ||
                            !data.containsKey('type')) {
                          print('TransactionList: Invalid transaction data at index $index: $data');
                          return const SizedBox.shrink();
                        }

                        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        final category = data['category'] as String? ?? 'Unknown';
                        final note = data['note'] as String? ?? '';
                        final date = data['date'] is Timestamp
                            ? (data['date'] as Timestamp).toDate()
                            : DateTime.now();
                        final type = data['type'] as String? ?? 'unknown';
                        final receiptUrl = data['receiptUrl'] as String?;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(category),
                            subtitle: Text(
                              '${note.isNotEmpty ? '$note - ' : ''}${DateFormat.yMMMd().format(date)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (receiptUrl != null && receiptUrl.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.receipt, color: Colors.blue),
                                    onPressed: () => _showReceiptDialog(receiptUrl),
                                    tooltip: 'View Receipt',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editTransaction(transaction),
                                  tooltip: 'Edit Transaction',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteTransaction(transaction.id, receiptUrl),
                                  tooltip: 'Delete Transaction',
                                ),
                                Text(
                                  '${type == 'expense' ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: type == 'expense' ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}