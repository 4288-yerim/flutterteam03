import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WithdrawalStatusService {
  WithdrawalStatusService._();

  static Future<bool> isCurrentUserWithdrawalPending() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> userDocument =
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final String status =
        userDocument.data()?['status'] as String? ?? 'ACTIVE';

    return status == 'WITHDRAWAL_PENDING';
  }
}
