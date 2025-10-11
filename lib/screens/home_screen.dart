import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_page.dart';
import 'package:intl/intl.dart'; // To format the date

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Navigate to previous month
  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  // Navigate to next month
  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthPage()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous month button
                IconButton(
                  icon: const Icon(Icons.arrow_left),
                  onPressed: _previousMonth,
                ),

                // Display Month & Year
                Text(
                  DateFormat.yMMMM().format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),

                // Next month button
                IconButton(
                  icon: const Icon(Icons.arrow_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Welcome message
            Text(
              user != null
                  ? 'Welcome, ${user.email}'
                  : 'You are not logged in',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Placeholder for history / transaction list
            Expanded(
              child: Center(
                child: Text(
                  'Transactions for ${DateFormat.yMMMM().format(_selectedDate)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
      // Floating + Button to add Expense/Income (you can implement later)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open Add Expense/Income Page
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
