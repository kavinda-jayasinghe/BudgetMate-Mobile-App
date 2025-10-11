import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseRepository {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Get expenses of the current user
  Stream<List<Expense>> getExpenses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Expense.fromDoc(doc.id, doc.data())).toList());
  }

  Future<void> addExpense(Expense expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _firestore.collection('users').doc(uid).collection('expenses').doc(expense.id);
    await docRef.set(expense.toMap());
  }

  Future<void> updateExpense(Expense expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _firestore.collection('users').doc(uid).collection('expenses').doc(expense.id);
    await docRef.update(expense.toMap());
  }

  Future<void> deleteExpense(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final docRef = _firestore.collection('users').doc(uid).collection('expenses').doc(id);
    await docRef.delete();
  }
}
