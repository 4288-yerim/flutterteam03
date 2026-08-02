import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminNoticeService {
  AdminNoticeService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminNotice>> watchNotices() {
    return _firestore
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AdminNotice.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> saveNotice({
    String? noticeId,
    required NoticeDraft draft,
  }) async {
    final administrator = _firebaseAuth.currentUser;
    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }

    final title = draft.title.trim();
    final content = draft.content.trim();
    if (title.isEmpty) throw ArgumentError('공지 제목을 입력해 주세요.');
    if (title.length > 100) {
      throw ArgumentError('공지 제목은 100자 이하로 입력해 주세요.');
    }
    if (content.isEmpty) throw ArgumentError('공지 내용을 입력해 주세요.');
    if (content.length > 5000) {
      throw ArgumentError('공지 내용은 5,000자 이하로 입력해 주세요.');
    }
    if (draft.targetType == 'SPECIFIC_USERS' && draft.targetUids.isEmpty) {
      throw ArgumentError('특정 회원 공지는 수신자 UID를 입력해 주세요.');
    }
    if (draft.status == 'SCHEDULED' && draft.publishedAt == null) {
      throw ArgumentError('예약 게시 일시를 선택해 주세요.');
    }
    if (draft.status == 'SCHEDULED' &&
        !draft.publishedAt!.isAfter(DateTime.now())) {
      throw ArgumentError('예약 게시 일시는 현재 시간 이후여야 합니다.');
    }

    final reference = noticeId == null
        ? _firestore.collection('notices').doc()
        : _firestore.collection('notices').doc(noticeId);
    final isNew = noticeId == null;

    await reference.set({
      'title': title,
      'content': content,
      'noticeType': draft.noticeType,
      'targetType': draft.targetType,
      'targetUids': draft.targetType == 'ALL' ? <String>[] : draft.targetUids,
      'isPinned': draft.isPinned,
      'status': draft.status,
      'publishedAt': switch (draft.status) {
        'PUBLISHED' =>
          draft.publishedAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(draft.publishedAt!),
        'SCHEDULED' => Timestamp.fromDate(draft.publishedAt!),
        _ => null,
      },
      'expiredAt': draft.expiredAt == null
          ? null
          : Timestamp.fromDate(draft.expiredAt!),
      if (isNew) 'createdBy': administrator.uid,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: !isNew));
  }

  Future<void> publishNow(AdminNotice notice) async {
    _requireAdministrator();
    await notice.reference.update({
      'status': 'PUBLISHED',
      'publishedAt': FieldValue.serverTimestamp(),
      'expiredAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endNotice(AdminNotice notice) async {
    _requireAdministrator();
    await notice.reference.update({
      'status': 'ENDED',
      'expiredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNotice(AdminNotice notice) async {
    _requireAdministrator();
    await notice.reference.delete();
  }

  void _requireAdministrator() {
    if (_firebaseAuth.currentUser == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }
  }
}

class NoticeDraft {
  const NoticeDraft({
    required this.title,
    required this.content,
    required this.noticeType,
    required this.targetType,
    required this.targetUids,
    required this.isPinned,
    required this.status,
    required this.publishedAt,
    required this.expiredAt,
  });

  final String title;
  final String content;
  final String noticeType;
  final String targetType;
  final List<String> targetUids;
  final bool isPinned;
  final String status;
  final DateTime? publishedAt;
  final DateTime? expiredAt;
}

class AdminNotice {
  const AdminNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.noticeType,
    required this.targetType,
    required this.targetUids,
    required this.isPinned,
    required this.status,
    required this.publishedAt,
    required this.expiredAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.reference,
  });

  factory AdminNotice.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminNotice(
      id: document.id,
      title: _text(data['title'], fallback: '제목 없음'),
      content: _text(data['content']),
      noticeType: _text(data['noticeType'], fallback: 'APP').toUpperCase(),
      targetType: _text(data['targetType'], fallback: 'ALL').toUpperCase(),
      targetUids: _stringList(data['targetUids']),
      isPinned: data['isPinned'] as bool? ?? false,
      status: _text(data['status'], fallback: 'DRAFT').toUpperCase(),
      publishedAt: _date(data['publishedAt']),
      expiredAt: _date(data['expiredAt']),
      createdBy: _text(data['createdBy']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      reference: document.reference,
    );
  }

  final String id;
  final String title;
  final String content;
  final String noticeType;
  final String targetType;
  final List<String> targetUids;
  final bool isPinned;
  final String status;
  final DateTime? publishedAt;
  final DateTime? expiredAt;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DocumentReference<Map<String, dynamic>> reference;

  bool get canPublish => status == 'DRAFT' || status == 'SCHEDULED';
  bool get canEnd => status == 'PUBLISHED';
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
