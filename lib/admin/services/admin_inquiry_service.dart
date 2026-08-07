import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminInquiryService {
  AdminInquiryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Stream<List<AdminInquiry>> watchInquiries() {
    return _firestore
        .collection('inquiries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final userDocIds = snapshot.docs
              .map((doc) => _nullableText(doc.data()['userDocId']))
              .whereType<String>()
              .toSet();

          final userDocuments = await Future.wait(
            userDocIds.map(
              (userDocId) =>
                  _firestore.collection('users').doc(userDocId).get(),
            ),
          );
          final usersById = <String, Map<String, dynamic>>{
            for (final document in userDocuments)
              document.id: document.data() ?? <String, dynamic>{},
          };

          return snapshot.docs.map((document) {
            final data = document.data();
            final userDocId = _nullableText(data['userDocId']);
            return AdminInquiry.fromDocument(
              document,
              userData: userDocId == null
                  ? const <String, dynamic>{}
                  : usersById[userDocId] ?? const <String, dynamic>{},
            );
          }).toList();
        });
  }

  Future<void> saveAnswer({
    required AdminInquiry inquiry,
    required String answer,
  }) async {
    final trimmedAnswer = answer.trim();
    if (trimmedAnswer.isEmpty) {
      throw ArgumentError('답변 내용을 입력해 주세요.');
    }
    if (trimmedAnswer.length > 2000) {
      throw ArgumentError('답변은 2,000자 이하로 입력해 주세요.');
    }

    final adminUid = _firebaseAuth.currentUser?.uid;
    if (adminUid == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }

    await inquiry.reference.update({
      'answer': trimmedAnswer,
      'answeredAt': FieldValue.serverTimestamp(),
      'answeredBy': adminUid,
      'status': 'ANSWERED',
      'isReadByUser': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminInquiry {
  const AdminInquiry({
    required this.id,
    required this.userUid,
    required this.userDocId,
    required this.userNickname,
    required this.userEmail,
    required this.category,
    required this.title,
    required this.content,
    required this.status,
    required this.answer,
    required this.createdAt,
    required this.answeredAt,
    required this.isReadByUser,
    required this.reference,
  });

  factory AdminInquiry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    required Map<String, dynamic> userData,
  }) {
    final data = document.data();
    return AdminInquiry(
      id: document.id,
      userUid: _text(data['uid']),
      userDocId: _text(data['userDocId']),
      userNickname: _text(userData['nickname'], fallback: '닉네임 없음'),
      userEmail: _text(userData['email'], fallback: '이메일 없음'),
      category: _text(data['category'], fallback: '기타'),
      title: _text(data['title'], fallback: '제목 없음'),
      content: _text(data['content']),
      status: _text(data['status'], fallback: 'PENDING').toUpperCase(),
      answer: _nullableText(data['answer']),
      createdAt:
          _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      answeredAt: _date(data['answeredAt']),
      isReadByUser: data['isReadByUser'] as bool? ?? true,
      reference: document.reference,
    );
  }

  final String id;
  final String userUid;
  final String userDocId;
  final String userNickname;
  final String userEmail;
  final String category;
  final String title;
  final String content;
  final String status;
  final String? answer;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final bool isReadByUser;
  final DocumentReference<Map<String, dynamic>> reference;

  bool get isAnswered => status == 'ANSWERED';

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
