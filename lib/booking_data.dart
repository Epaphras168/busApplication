import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in user's bookings: users/{uid}/bookings
CollectionReference<Map<String, dynamic>> myBookings() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('bookings');
}

/// The signed-in user's waitlist: users/{uid}/waitlist
CollectionReference<Map<String, dynamic>> myWaitlist() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('waitlist');
}

/// Sample data, written once when a new account is created.
Future<void> addSampleBookings() async {
  const price = 3000;
  const samples = {0: 'Alice', 1: 'Bob', 5: 'Clara'};
  final batch = FirebaseFirestore.instance.batch();
  for (final entry in samples.entries) {
    batch.set(myBookings().doc('${entry.key}'), {
      'seat': entry.key,
      'name': entry.value,
      'cash': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}
