import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/waitlist_person.dart';

class BusRepository {
  BusRepository(this.uid);

  final String uid;

  CollectionReference<Map<String, dynamic>> get _bookings => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('bookings');

  CollectionReference<Map<String, dynamic>> get _waitlist => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('waitlist');

  // The pipe for bookings: a map from doc id -> name, keyed by seat index.
  Stream<Map<int, String>> watchBookings() => _bookings.snapshots().map(
        (snapshot) => {
      for (final doc in snapshot.docs)
        if (int.tryParse(doc.id) != null) int.parse(doc.id): doc.data()['name'] as String,
    },
  );

  Stream<List<WaitlistPerson>> watchWaitlist() =>
      _waitlist.orderBy('joinedAt').snapshots().map(
            (snapshot) => snapshot.docs.map(WaitlistPerson.fromDoc).toList(),
      );

  Future<void> bookSeat(int seat, Booking booking) =>
      _bookings.doc('$seat').set({
        ...booking.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancelSeat(int seat) => _bookings.doc('$seat').delete();

  Future<void> joinWaitlist(String name, bool priority, String reason) =>
      _waitlist.add({
        'name': name,
        'priority': priority,
        'reason': priority ? reason : '',
        'joinedAt': FieldValue.serverTimestamp(),
      });

  Future<void> leaveWaitlist(String id) => _waitlist.doc(id).delete();

  Future<void> addSamples() async {
    const price = 3000;
    const samples = {0: 'Alice', 1: 'Bob', 5: 'Clara'};
    final batch = FirebaseFirestore.instance.batch();
    for (final entry in samples.entries) {
      batch.set(_bookings.doc('${entry.key}'), {
        'seat': entry.key,
        'name': entry.value,
        'cash': price,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}