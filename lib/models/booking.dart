import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  Booking({
    required this.seat,
    required this.name,
    required this.cash,
  });

  final int seat;
  final String name;
  final int cash;

  Map<String, dynamic> toMap() => {
    'seat': seat,
    'name': name,
    'cash': cash,
  };

  factory Booking.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Booking(
      seat: data['seat'] as int,
      name: data['name'] as String,
      cash: (data['cash'] as num).toInt(),
    );
  }
}