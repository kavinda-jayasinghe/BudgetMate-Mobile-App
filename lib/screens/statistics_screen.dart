import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
  int _selectedTab = 0; // 0 for expenses, 1 for income

  final List<Color> _expenseColors = [
    Color(0xFFFF6B6B), Color(0xFFFFA726), Color(0xFFFFCA28),
    Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFFFF7043),
    Color(0xFF8D6E63), Color(0xFF78909C), Color(0xFF26C6DA),
  ];

  final List<Color> _incomeColors = [
    Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF43A047),
    Color(0xFF388E3C), Color(0xFF2E7D32), Color(0xFF1B5E20),
    Color(0xFF81C784), Color(0xFFA5D6A7), Color(0xFFC8E6C9),
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
      print('StatisticsScreen: Firestore error: $e');
      setState(() {
        errorMessage = 'Error loading statistics: $e';
        isLoading = false;
      });
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

  Widget _buildPieChart(Map<String, double> data, List<Color> colors) {
    if (data.isEmpty) {
      return Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart, size: 64, color: Colors.grey[400]), // Fixed icon
              const SizedBox(height: 16),
              Text(
                'No data available',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add transactions to see statistics',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final total = data.values.reduce((a, b) => a + b);

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: data.entries.toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value.key;
                    final amount = entry.value.value;
                    final percentage = (amount / total * 100).toStringAsFixed(1);
                    
                    return PieChartSectionData(
                      value: amount,
                      title: '',
                      color: colors[index % colors.length],
                      radius: 24,
                      badgeWidget: _buildBadge(category, amount, percentage, colors[index % colors.length]),
                      badgePositionPercentageOffset: 1.2,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 70,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildLegend(data, colors),
      ],
    );
  }

  Widget _buildBadge(String category, double amount, String percentage, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$percentage%',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, double> data, List<Color> colors) {
    final total = data.values.reduce((a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: data.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value.key;
          final amount = entry.value.value;
          final percentage = (amount / total * 100).toStringAsFixed(1);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalExpenses = expenseData.values.fold(0.0, (sum, amount) => sum + amount);
    final totalIncome = incomeData.values.fold(0.0, (sum, amount) => sum + amount);
    final netAmount = totalIncome - totalExpenses;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSummaryCard(
            'Expenses',
            totalExpenses,
            Colors.red,
            Icons.arrow_downward,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Income',
            totalIncome,
            Colors.green,
            Icons.arrow_upward,
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Net',
            netAmount,
            netAmount >= 0 ? Colors.blue : Colors.orange,
            netAmount >= 0 ? Icons.trending_up : Icons.trending_down,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Statistics - ${DateFormat.yMMMM().format(widget.selectedDate)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? _buildLoadingState()
          : errorMessage.isNotEmpty
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildTabButton('Expenses', 0, Colors.red),
                                const SizedBox(width: 12),
                                _buildTabButton('Income', 1, Colors.green),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _selectedTab == 0
                                ? _buildPieChart(expenseData, _expenseColors)
                                : _buildPieChart(incomeData, _incomeColors),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabButton(String text, int index, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _selectedTab == index ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _selectedTab == index ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Statistics...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 20),
            Text(
              errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorMessage.contains('FAILED_PRECONDITION') || errorMessage.contains('index'))
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'This is an index error. Check the debug console for a link to create the required index in Firebase.',
                  style: TextStyle(fontSize: 14, color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchTransactionData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}