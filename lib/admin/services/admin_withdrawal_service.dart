import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWithdrawalService {
  AdminWithdrawalService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminWithdrawalRequest>>
  watchPendingRequests() {
    return _firestore
        .collection('users')
        .where(
      'status',
      isEqualTo: 'WITHDRAWAL_PENDING',
    )
        .snapshots()
        .map((snapshot) {
      final List<AdminWithdrawalRequest>
      requests = snapshot.docs
          .map(
        AdminWithdrawalRequest.fromDocument,
      )
          .toList();

      /*
           * Firestore 복합 색인을 추가하지 않아도 되도록
           * 신청일 정렬은 클라이언트에서 처리합니다.
           */
      requests.sort((
          AdminWithdrawalRequest first,
          AdminWithdrawalRequest second,
          ) {
        final DateTime firstDate =
            first.requestedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        final DateTime secondDate =
            second.requestedAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return secondDate.compareTo(firstDate);
      });

      return requests;
    });
  }
}

class AdminWithdrawalRequest {
  const AdminWithdrawalRequest({
    required this.uid,
    required this.nickname,
    required this.reasonCode,
    required this.reason,
    required this.reasonDetail,
    required this.requestedAt,
    required this.scheduledAt,
  });

  factory AdminWithdrawalRequest.fromDocument(
      DocumentSnapshot<Map<String, dynamic>>
      document,
      ) {
    final Map<String, dynamic> data =
        document.data() ??
            <String, dynamic>{};

    return AdminWithdrawalRequest(
      uid: document.id,
      nickname: _readText(
        data['nickname'],
        fallback: '닉네임 없음',
      ),
      reasonCode: _readText(
        data['withdrawalReasonCode'],
        fallback: 'UNKNOWN',
      ).toUpperCase(),
      reason: _readText(
        data['withdrawalReason'],
      ),
      reasonDetail: _readText(
        data['withdrawalReasonDetail'],
      ),
      requestedAt: _readDateTime(
        data['withdrawalRequestedAt'],
      ),
      scheduledAt: _readDateTime(
        data['withdrawalScheduledAt'],
      ),
    );
  }

  final String uid;
  final String nickname;
  final String reasonCode;
  final String reason;
  final String reasonDetail;
  final DateTime? requestedAt;
  final DateTime? scheduledAt;

  String get reasonLabel {
    if (reason.trim().isNotEmpty) {
      return reason.trim();
    }

    switch (reasonCode) {
      case 'NOT_USED_OFTEN':
        return '앱을 자주 사용하지 않아요.';

      case 'LACK_OF_FEATURES':
        return '원하는 기능이 부족해요.';

      case 'INCONVENIENT':
        return '앱 사용이 불편해요.';

      case 'TOO_MANY_NOTIFICATIONS':
        return '알림이 너무 많아요.';

      case 'PRIVACY_CONCERN':
        return '개인정보가 걱정돼요.';

      case 'USE_OTHER_SERVICE':
        return '다른 서비스를 이용할 예정이에요.';

      case 'OTHER':
        return '기타';

      default:
        return '확인할 수 없음';
    }
  }

  bool get isExpired {
    final DateTime? scheduledDate = scheduledAt;

    if (scheduledDate == null) {
      return false;
    }

    return scheduledDate.isBefore(
      DateTime.now(),
    );
  }

  String get remainingLabel {
    final DateTime? scheduledDate = scheduledAt;

    if (scheduledDate == null) {
      return '예정일 확인 불가';
    }

    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime scheduledDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );

    final int days =
        scheduledDay.difference(today).inDays;

    if (days < 0) {
      return '기간 만료';
    }

    if (days == 0) {
      return 'D-Day';
    }

    return 'D-$days';
  }

  bool matchesSearch(String query) {
    final String normalizedQuery =
    query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    return nickname
        .toLowerCase()
        .contains(normalizedQuery) ||
        reasonLabel
            .toLowerCase()
            .contains(normalizedQuery) ||
        reasonDetail
            .toLowerCase()
            .contains(normalizedQuery);
  }

  bool matchesReason(String selectedCode) {
    if (selectedCode == 'ALL') {
      return true;
    }

    return reasonCode == selectedCode;
  }
}

String _readText(
    Object? value, {
      String fallback = '',
    }) {
  final String text =
      value?.toString().trim() ?? '';

  if (text.isEmpty ||
      text.toLowerCase() == 'null') {
    return fallback;
  }

  return text;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}