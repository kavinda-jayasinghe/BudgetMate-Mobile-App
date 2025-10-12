import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  final DateTime selectedDate;

  const StatisticsScreen({super.key, required this.selectedDate});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, double> expenseData = {};
  Map<String, double> incomeData = {};
  bool isLoading = true;
  String errorMessage = '';

  // Vibrant color palette for pie charts
  final List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
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
          .orderBy('date', descending: true) // Added to match TransactionList index
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
      setState(() {
        errorMessage = 'Error loading statistics: $e';
        isLoading = false;
      });
      print('Firestore error: $e'); // Log error for debugging
    }
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
                      if (errorMessage.contains('FAILED_PRECONDITION')) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Please check the console for the index creation link.',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expenses by Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 16),
                      expenseData.isEmpty
                          ? const Center(child: Text('No expenses for this month', style: TextStyle(fontSize: 16)))
                          : SizedBox(
                              height: 300,
                              child: PieChart(
                                PieChartData(
                                  sections: expenseData.entries.toList().asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final category = entry.value.key;
                                    final amount = entry.value.value;
                                    return PieChartSectionData(
                                      value: amount,
                                      title: '$category\n\$${amount.toStringAsFixed(2)}',
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
                      const SizedBox(height: 32),
                      const Text(
                        'Income by Category',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const SizedBox(height: 16),
                      incomeData.isEmpty
                          ? const Center(child: Text('No income for this month', style: TextStyle(fontSize: 16)))
                          : SizedBox(
                              height: 300,
                              child: PieChart(
                                PieChartData(
                                  sections: incomeData.entries.toList().asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final category = entry.value.key;
                                    final amount = entry.value.value;
                                    return PieChartSectionData(
                                      value: amount,
                                      title: '$category\n\$${amount.toStringAsFixed(2)}',
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
                  ),
                ),
    );
  }
}