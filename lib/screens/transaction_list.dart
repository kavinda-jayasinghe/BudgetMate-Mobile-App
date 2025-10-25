import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'add_expense_screen.dart';
import 'statistics_screen.dart';

class TransactionList extends StatelessWidget {
  final DateTime selectedDate;

  const TransactionList({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('TransactionList: No user logged in'); // Debug
      return const Center(child: Text('Please log in to view transactions'));
    }

    final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);
    print('TransactionList: Querying for $startOfMonth to $endOfMonth'); // Debug

    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, connectivitySnapshot) {
        final isOffline = connectivitySnapshot.hasData &&
            connectivitySnapshot.data!.contains(ConnectivityResult.none);
        print('TransactionList: Connectivity: ${isOffline ? 'Offline' : 'Online'}'); // Debug

        return Scaffold(
          appBar: AppBar(
            title: const Text('Your Transactions'),
            backgroundColor: Colors.indigo,
            actions: [
              // ----------- STATISTICS ICON BUTTON -----------
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                tooltip: 'View Statistics',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StatisticsScreen(selectedDate: selectedDate),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<QuerySnapshot>(
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

              return Column(
                children: [
                  if (isOffline)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Offline mode: showing cached data',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final data = transaction.data() as Map<String, dynamic>;
                        print('Transaction $index: $data'); // Debug

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
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}