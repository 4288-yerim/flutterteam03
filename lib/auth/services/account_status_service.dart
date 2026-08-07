import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AccountCheckResult { ok, suspended, withdrawn }

class AccountStatusService {
  static Future<({AccountCheckResult result, DateTime? suspendedUntil})>
  checkCurrentUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return (result: AccountCheckResult.ok, suspendedUntil: null);

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    final status = doc.data()?['status'] as String?;

    if (status == 'SUSPENDED') {
      final until = (doc.data()?['suspendedUntil'] as Timestamp?)?.toDate();
      if (until == null || until.isAfter(DateTime.now())) {
        await FirebaseAuth.instance.signOut();
        return (result: AccountCheckResult.suspended, suspendedUntil: until);
      }
      await ref.update({'status': 'ACTIVE', 'suspendedUntil': null});
    }

    if (status == 'WITHDRAWN') {
      return (result: AccountCheckResult.withdrawn, suspendedUntil: null);
    }

    return (result: AccountCheckResult.ok, suspendedUntil: null);
  }
}