// transaction_list.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionList extends StatelessWidget {
  final DateTime selectedDate;

  const TransactionList({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view transactions'));
    }

    // Define the start and end of the selected month
    final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

    print('Fetching transactions for user: ${user.uid}');
    print('Date range: $startOfMonth to $endOfMonth');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Firestore error: ${snapshot.error}'); // Log error for debugging
          return Center(
            child: Text(
              snapshot.error.toString().contains('network')
                  ? 'No internet connection. Please try again.'
                  : 'Error loading transactions: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No transactions for this month'));
        }

        final transactions = snapshot.data!.docs;

        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            final amount = transaction['amount'] as double? ?? 0.0;
            final category = transaction['category'] as String? ?? 'Unknown';
            final note = transaction['note'] as String? ?? '';
            final date = (transaction['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            final type = transaction['type'] as String? ?? 'unknown';

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
    );
  }
}