import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // For offline check

class StatisticsScreen extends StatefulWidget {
  final DateTime selectedDate;

  const StatisticsScreen({super.key, required this.selectedDate});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, double> expenseData = {};
  Map<String, double> incomeData = {};
  bool isLoading = true;
  String errorMessage = '';

  final List<Color> colors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange,
    Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    Colors.cyan, Colors.lime,
  ];

  @override
  void initState() {
    super.initState();
    _fetchTransactionData();
  }

  Future<void> _fetchTransactionData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        errorMessage = 'Please log in to view statistics';
        isLoading = false;
      });
      return;
    }

    final startOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final endOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0, 23, 59, 59);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date', descending: true)
          .get();

      final expenseTotals = <String, double>{};
      final incomeTotals = <String, double>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Unknown';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final type = data['type'] as String? ?? 'unknown';

        if (type == 'expense') {
          expenseTotals[category] = (expenseTotals[category] ?? 0) + amount;
        } else if (type == 'income') {
          incomeTotals[category] = (incomeTotals[category] ?? 0) + amount;
        }
      }

      setState(() {
        expenseData = expenseTotals;
        incomeData = incomeTotals;
        isLoading = false;
      });
    } catch (e) {
      print('StatisticsScreen: Firestore error: $e'); // Debug log
      setState(() {
        errorMessage = 'Error loading statistics: $e';
        isLoading = false;
      });
      // If it's an index error, show helpful message
      if (e.toString().contains('FAILED_PRECONDITION') || e.toString().contains('index')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Query requires an index. Check console for link to create it.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildPieChart(Map<String, double> data, String title, Color titleColor) {
    if (data.isEmpty) {
      return const Center(child: Text('No data for this month', style: TextStyle(fontSize: 16)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: data.entries.toList().asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value.key;
                final amount = entry.value.value;
                return PieChartSectionData(
                  value: amount,
                  title: '$category\n\$${amount.toStringAsFixed(0)}',
                  color: colors[index % colors.length],
                  radius: 100,
                  titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 50,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Statistics - ${DateFormat.yMMMM().format(widget.selectedDate)}',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage, style: const TextStyle(color: Colors.red)),
                      if (errorMessage.contains('FAILED_PRECONDITION') || errorMessage.contains('index'))
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'This is an index error. Check the debug console for a link to create the required index in Firebase.',
                            style: TextStyle(fontSize: 14, color: Colors.orange),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPieChart(expenseData, 'Expenses by Category', Colors.blueAccent),
                      const SizedBox(height: 32),
                      _buildPieChart(incomeData, 'Income by Category', Colors.green),
                    ],
                  ),
                ),
    );
  }
}