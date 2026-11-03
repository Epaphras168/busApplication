import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistPerson {
  WaitlistPerson(this.id, this.name, this.priority, [this.reason = '']);

  final String id;
  final String name;
  final bool priority;
  final String reason;

  factory WaitlistPerson.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      WaitlistPerson(
        doc.id,
        doc.data()['name'] as String,
        doc.data()['priority'] as bool,
        (doc.data()['reason'] as String?) ?? '',
      );
}