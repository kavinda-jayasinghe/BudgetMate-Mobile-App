

import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final double amount;
  final String category;  // e.g., 'Food', 'Transport'
  final String? note;  // Optional note field
  final DateTime date;  // Date of the expense
  final String type;  // 'expense' or 'income'

  // Constructor
  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.type,  // 'expense' or 'income'
  });

  // Method to convert Expense object to Firestore Map 
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),  // Convert DateTime to Firestore Timestamp
      'type': type,  // Store 'expense' or 'income'
    };
  }

  // Factory method to create an Expense from a Firestore document
  factory Expense.fromDoc(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      note: map['note'],
      date: (map['date'] as Timestamp).toDate(),  // Convert Firestore Timestamp back to DateTime
      type: map['type'] ?? 'expense',  // Default to 'expense' if type is missing
    );
  }
}
