import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminNotificationService {
  AdminNotificationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminNotificationUser>> watchActiveUsers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'USER')
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map(AdminNotificationUser.fromDocument)
              .where((user) => user.status == 'ACTIVE')
              .toList();
          users.sort(
            (a, b) =>
                a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
          );
          return users;
        });
  }

  Future<AdminNotificationResult> sendNotification({
    required String title,
    required String body,
    required bool sendToAll,
    required Set<String> selectedUids,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('알림 제목을 입력해 주세요.');
    }
    if (trimmedTitle.length > 100) {
      throw ArgumentError('알림 제목은 100자 이하로 입력해 주세요.');
    }
    if (trimmedBody.isEmpty) {
      throw ArgumentError('알림 내용을 입력해 주세요.');
    }
    if (trimmedBody.length > 1000) {
      throw ArgumentError('알림 내용은 1,000자 이하로 입력해 주세요.');
    }
    if (!sendToAll && selectedUids.isEmpty) {
      throw ArgumentError('알림을 받을 회원을 한 명 이상 선택해 주세요.');
    }

    final administrator = _firebaseAuth.currentUser;

    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }

    // Callable Function 호출 전에 최신 Firebase ID 토큰을 확보
    await administrator.getIdToken(true);

    final callable = _functions.httpsCallable('sendAdminNotification');
    final result = await callable.call<Object?>({
      'title': trimmedTitle,
      'body': trimmedBody,
      'targetType': sendToAll ? 'ALL' : 'SPECIFIC_USERS',
      'targetUids': sendToAll ? <String>[] : selectedUids.toList(),
    });

    final rawData = result.data;
    if (rawData is! Map) {
      throw StateError('알림 발송 결과를 확인할 수 없습니다.');
    }

    final data = Map<String, dynamic>.from(rawData);
    return AdminNotificationResult(
      recipientCount: _integer(data['recipientCount']),
      storedCount: _integer(data['storedCount']),
      pushSuccessCount: _integer(data['pushSuccessCount']),
      pushFailureCount: _integer(data['pushFailureCount']),
      pushSkippedCount: _integer(data['pushSkippedCount']),
    );
  }
}

class AdminNotificationUser {
  const AdminNotificationUser({
    required this.uid,
    required this.nickname,
    required this.email,
    required this.status,
  });

  factory AdminNotificationUser.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminNotificationUser(
      uid: document.id,
      nickname: _text(data['nickname'], fallback: '닉네임 없음'),
      email: _text(data['email'], fallback: '이메일 없음'),
      status: _text(data['status'], fallback: 'ACTIVE').toUpperCase(),
    );
  }

  final String uid;
  final String nickname;
  final String email;
  final String status;
}

class AdminNotificationResult {
  const AdminNotificationResult({
    required this.recipientCount,
    required this.storedCount,
    required this.pushSuccessCount,
    required this.pushFailureCount,
    required this.pushSkippedCount,
  });

  final int recipientCount;
  final int storedCount;
  final int pushSuccessCount;
  final int pushFailureCount;
  final int pushSkippedCount;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
