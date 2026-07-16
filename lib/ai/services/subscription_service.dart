// subscription_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

const String kImpUserCode = 'imp76454883';
const String kMerchantOrderName = '구름iT 구독 - 첫 달';
const int kFirstMonthAmount = 1000;

enum SubscriptionPurchaseState {
  idle,
  loading,
  success,
  cancelled,
  error,
}

class SubscriptionService {
  SubscriptionService._internal();
  static final SubscriptionService instance = SubscriptionService._internal();

  void Function(SubscriptionPurchaseState state, {String? message})?
  onStateChanged;

  Future<void> init() async {
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> subscriptionStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('current')
        .snapshots();
  }

  Future<void> verifyAndActivate({
    required String customerUid,
  }) async {
    onStateChanged?.call(SubscriptionPurchaseState.loading);

    try {
      final callable =
      FirebaseFunctions.instance.httpsCallable('verifySubscriptionPayment');
      final result = await callable.call({
        'customer_uid': customerUid,
      });

      final bool success = result.data['success'] == true;
      if (success) {
        onStateChanged?.call(SubscriptionPurchaseState.success);
      } else {
        onStateChanged?.call(
          SubscriptionPurchaseState.error,
          message: result.data['message'] ?? '결제 검증에 실패했습니다.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      onStateChanged?.call(
        SubscriptionPurchaseState.error,
        message: e.message ?? '결제 처리 중 오류가 발생했습니다.',
      );
    } catch (e) {
      onStateChanged?.call(
        SubscriptionPurchaseState.error,
        message: '결제 처리 중 오류가 발생했습니다.',
      );
    }
  }

  void onPaymentCancelled() {
    onStateChanged?.call(SubscriptionPurchaseState.cancelled);
  }

  Future<bool> cancelSubscription() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      final result = await callable.call();
      return result.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {}
}