import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'add_expense_screen.dart';
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
    // Initialize with current month if widget.selectedDate is null or invalid
    _selectedDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    print('TransactionList: Initialized with $_selectedDate'); // Debug
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
    print('TransactionList: Changed to previous month: $_selectedDate'); // Debug
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
    print('TransactionList: Changed to next month: $_selectedDate'); // Debug
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      print('TransactionList: Signed out successfully'); // Debug
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('TransactionList: Sign-out error: $e'); // Debug
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('TransactionList: No user logged in'); // Debug
      return const Center(child: Text('Please log in to view transactions'));
    }

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
    print('TransactionList: Querying for $startOfMonth to $endOfMonth'); // Debug

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, connectivitySnapshot) {
        final isOffline = connectivitySnapshot.hasData &&
            connectivitySnapshot.data!.contains(ConnectivityResult.none);
        print('TransactionList: Connectivity: ${isOffline ? 'Offline' : 'Online'}'); // Debug

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
                title: const Text(
            'Budget Mate',
              style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
               ),
             ),
            actions: [
              // Statistics Icon
              IconButton(
                icon: const Icon(Icons.pie_chart, color: Colors.white),
                tooltip: 'View Statistics',
                onPressed: () {
                  print('TransactionList: Navigating to StatisticsScreen'); // Debug
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StatisticsScreen(selectedDate: _selectedDate),
                    ),
                  );
                },
              ),
              // Logout Icon
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
              print('TransactionList: Navigating to AddExpenseScreen'); // Debug
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Selector
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
                      print('TransactionList: Waiting for data'); // Debug
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      print('TransactionList: Error: ${snapshot.error}'); // Debug
                      return Center(
                        child: Text(
                          isOffline
                              ? 'Offline: Showing cached data'
                              : 'Error: ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      print('TransactionList: No transactions found'); // Debug
                      return Center(
                        child: Text(
                          isOffline
                              ? 'No cached transactions for this month'
                              : 'No transactions for this month',
                        ),
                      );
                    }

                    final transactions = snapshot.data!.docs;
                    print('TransactionList: Found ${transactions.length} transactions'); // Debug

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final data = transaction.data() as Map<String, dynamic>;
                        print('TransactionList: Transaction $index: $data'); // Debug

                        if (!data.containsKey('amount') ||
                            !data.containsKey('category') ||
                            !data.containsKey('date') ||
                            !data.containsKey('type')) {
                          print('TransactionList: Invalid transaction data at index $index: $data'); // Debug
                          return const SizedBox.shrink();
                        }

                        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                        final category = data['category'] as String? ?? 'Unknown';
                        final note = data['note'] as String? ?? '';
                        final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final type = data['type'] as String? ?? 'unknown';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(category),
                            subtitle: Text(
                              '${note.isNotEmpty ? '$note - ' : ''}${DateFormat.yMMMd().format(date)}',
                            ),
                            trailing: Text(
                              '${type == 'expense' ? '-' : '+'}\$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: type == 'expense' ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
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