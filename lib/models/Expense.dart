import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Expense {
  final String id;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final String type;
  final double? latitude;
  final double? longitude;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.type,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Expense.fromDoc(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Other',
      note: map['note'],
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      type: map['type'] ?? 'expense',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
}