import 'package:budget_mate/screens/auth_page.dart';
import 'package:budget_mate/screens/statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_expense_screen.dart';
import 'transaction_list.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isNavigating = false;


// In home_screen.dart, update the method
Future<void> updateTransactionsWithUserIdAndDate() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final transactions = await FirebaseFirestore.instance
      .collection('transactions')
      .get(); // Check all transactions

  for (var doc in transactions.docs) {
    final data = doc.data();
    final date = data['date'];
    final userId = data['userId'];

    if (userId == null || date == null || date is! Timestamp) {
      Timestamp? updatedDate;
      if (date is DateTime) {
        updatedDate = Timestamp.fromDate(date);
      } else if (date is Timestamp) {
        updatedDate = date;
      } else {
        updatedDate = Timestamp.now(); // Fallback to current time
      }

      await doc.reference.update({
        'userId': user.uid,
        'date': updatedDate,
      });
    }
  }
}

  void _previousMonth() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
      print('Navigated to: ${_selectedDate.toString()}');
    });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isNavigating = false;
    });
  }

  void _nextMonth() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
      print('Navigated to: ${_selectedDate.toString()}');
    });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isNavigating = false;
    });
  }

  @override
  void initState() {
    super.initState();
    updateTransactionsWithUserIdAndDate();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Budget Mate'),
      //   centerTitle: true,
      //   backgroundColor: Colors.blueAccent, // Match StatisticsScreen styling
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.pie_chart, color: Colors.white),
      //       tooltip: 'View Statistics',
      //       onPressed: () {
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(
      //             builder: (context) => StatisticsScreen(selectedDate: _selectedDate),
      //           ),
      //         );
      //       },
      //     ),
      //     IconButton(
      //       icon: const Icon(Icons.logout, color: Colors.white),
      //       tooltip: 'Logout',
      //       onPressed: () async {
      //         await FirebaseAuth.instance.signOut();
      //         Navigator.pushReplacement(
      //           context,
      //           MaterialPageRoute(builder: (context) => const AuthPage()),
      //         );
      //       },
      //     ),
      //   ],
      //   bottom: PreferredSize(
      //     preferredSize: const Size.fromHeight(50),
      //     child: Padding(
      //       padding: const EdgeInsets.symmetric(vertical: 8.0),
      //       child: Row(
      //         mainAxisAlignment: MainAxisAlignment.center,
      //         children: [
      //           IconButton(
      //             icon: const Icon(Icons.arrow_left, color: Colors.white),
      //             onPressed: _previousMonth,
      //           ),
      //           Text(
      //             DateFormat.yMMMM().format(_selectedDate),
      //             style: const TextStyle(
      //               fontSize: 18,
      //               fontWeight: FontWeight.bold,
      //               color: Colors.white,
      //             ),
      //           ),
      //           IconButton(
      //             icon: const Icon(Icons.arrow_right, color: Colors.white),
      //             onPressed: _nextMonth,
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
      body: Column(
        children: [
          // const SizedBox(height: 16),
          // Text(
          //   user != null ? 'Welcome, ${user.email}' : 'You are not logged in',
          //   style: const TextStyle(fontSize: 16),
          // ),
          const SizedBox(height: 16),
          Expanded(
            child: TransactionList(selectedDate: _selectedDate),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}