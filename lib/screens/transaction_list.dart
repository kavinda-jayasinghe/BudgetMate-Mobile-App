import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _TransactionListState extends State<TransactionList> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _tabController = TabController(length: 3, vsync: this);
    print('TransactionList: Initialized with $_selectedDate');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    );

    print('TransactionList: Navigating to edit transaction: ${transaction.id}');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => expense.AddExpenseScreen(transaction: transactionObj),
      ),
    );
  }

  Future<void> _deleteTransaction(String transactionId) async {
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

  Widget _buildTransactionList(String typeFilter) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('TransactionList: No user logged in');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please log in to view transactions',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date', descending: true);

    // Apply type filter if not "all"
    if (typeFilter != 'all') {
      query = query.where('type', isEqualTo: typeFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading transactions...',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  typeFilter == 'all' ? Icons.receipt_long : 
                  typeFilter == 'expense' ? Icons.money_off : Icons.attach_money,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  typeFilter == 'all' ? 'No transactions for this month' :
                  typeFilter == 'expense' ? 'No expenses for this month' : 
                  'No income for this month',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data!.docs;
        
        // Calculate total for the current tab
        double total = 0;
        for (final transaction in transactions) {
          final data = transaction.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final transactionType = data['type'] as String? ?? 'unknown';
          if (transactionType == 'expense') {
            total -= amount;
          } else {
            total += amount;
          }
        }

        // For individual tabs, show absolute value
        if (typeFilter != 'all') {
          total = total.abs();
        }

        return Column(
          children: [
            // Total amount card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(typeFilter),
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    typeFilter == 'all' ? 'Total Balance' :
                    typeFilter == 'expense' ? 'Total Expenses' : 'Total Income',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (typeFilter == 'all') ...[
                    const SizedBox(height: 4),
                    Text(
                      total >= 0 ? 'Positive Balance' : 'Negative Balance',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Transaction list
            Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final data = transaction.data() as Map<String, dynamic>;

                  if (!data.containsKey('amount') ||
                      !data.containsKey('category') ||
                      !data.containsKey('date') ||
                      !data.containsKey('type')) {
                    return const SizedBox.shrink();
                  }

                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final category = data['category'] as String? ?? 'Unknown';
                  final note = data['note'] as String? ?? '';
                  final date = data['date'] is Timestamp
                      ? (data['date'] as Timestamp).toDate()
                      : DateTime.now();
                  final type = data['type'] as String? ?? 'unknown';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: type == 'expense' 
                                ? Colors.red.shade50 
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Icon(
                            type == 'expense' ? Icons.arrow_upward : Icons.arrow_downward,
                            color: type == 'expense' ? Colors.red : Colors.green,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.isNotEmpty) ...[
                              Text(
                                note,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                              ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue.shade600),
                              onPressed: () => _editTransaction(transaction),
                              tooltip: 'Edit Transaction',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red.shade600),
                              onPressed: () => _deleteTransaction(transaction.id),
                              tooltip: 'Delete Transaction',
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: type == 'expense' 
                                    ? Colors.red.shade50 
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${type == 'expense' ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: type == 'expense' ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<Color> _getGradientColors(String typeFilter) {
    switch (typeFilter) {
      case 'expense':
        return [Colors.red.shade600, Colors.orange.shade600];
      case 'income':
        return [Colors.green.shade600, Colors.teal.shade600];
      case 'all':
      default:
        return [Colors.indigo.shade600, Colors.purple.shade600];
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, connectivitySnapshot) {
        final isOffline = connectivitySnapshot.hasData &&
            connectivitySnapshot.data!.contains(ConnectivityResult.none);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            elevation: 0,
            title: const Text(
              'Budget Mate',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.pie_chart, color: Colors.white),
                tooltip: 'View Statistics',
                onPressed: () {
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120),
              child: Column(
                children: [
                  // Month navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_left, color: Colors.white),
                          onPressed: _previousMonth,
                          tooltip: 'Previous Month',
                        ),
                        Text(
                          DateFormat.yMMMM().format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_right, color: Colors.white),
                          onPressed: _nextMonth,
                          tooltip: 'Next Month',
                        ),
                      ],
                    ),
                  ),
                  
                  // Tabs
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.indigo,
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Expenses'),
                        Tab(text: 'Income'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const expense.AddExpenseScreen()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: Column(
            children: [
              // Offline indicator
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Offline mode: showing cached data',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionList('all'),
                    _buildTransactionList('expense'),
                    _buildTransactionList('income'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}