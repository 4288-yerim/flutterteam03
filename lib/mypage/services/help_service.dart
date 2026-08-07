import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/inquiry_models.dart';

class HelpServiceException implements Exception {
  final String message;
  HelpServiceException(this.message);
}

class HelpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  Future<DocumentReference<Map<String, dynamic>>> _requireUserDocRef() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw HelpServiceException('로그인이 필요합니다.');
    }

    final query = await _firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw HelpServiceException('사용자 정보를 찾을 수 없습니다.');
    }

    return query.docs.first.reference;
  }

  /// 전역 FAQ 목록
  Stream<List<FaqItem>> watchFaqs() {
    return _firestore
        .collection('faqs')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(FaqItem.fromDoc).toList());
  }

  /// 내 문의 내역
  Stream<List<InquiryItem>> watchInquiries() async* {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        yield const [];
        return;
      }

      yield* _firestore
          .collection('inquiries')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(InquiryItem.fromDoc).toList());
    } catch (_) {
      yield const [];
    }
  }

  Future<void> submitInquiry({
    required String category,
    required String title,
    required String content,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw HelpServiceException('로그인이 필요합니다.');
    }

    final userDocRef = await _requireUserDocRef();
    final inquiryRef = _firestore.collection('inquiries').doc();

    await inquiryRef.set({
      'inquiryId': inquiryRef.id,
      'uid': user.uid,
      'userDocId': userDocRef.id,
      'category': category.trim(),
      'title': title.trim(),
      'content': content.trim(),
      'attachmentFiles': <String>[],
      'answer': null,
      'status': 'PENDING',
      'answeredBy': null,
      'answeredAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isReadByUser': true,
    });
  }

  Stream<List<ChatSessionSummary>> watchChatSessions() async* {
    try {
      final userDocRef = await _requireUserDocRef();
      yield* userDocRef
          .collection('chat_sessions')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(ChatSessionSummary.fromDoc).toList());
    } catch (_) {
      yield const [];
    }
  }

  Future<String> createChatSession() async {
    final userDocRef = await _requireUserDocRef();

    final sessionRef = await userDocRef.collection('chat_sessions').add({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'preview': '',
      'hasUnreadBotReply': false,
    });

    return sessionRef.id;
  }

  Future<List<ChatMessageRecord>> fetchChatMessages(String sessionId) async {
    final userDocRef = await _requireUserDocRef();

    final snap = await userDocRef
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    return snap.docs.map(ChatMessageRecord.fromDoc).toList();
  }

  Future<void> deleteChatSession(String sessionId) async {
    final userDocRef = await _requireUserDocRef();
    final sessionRef = userDocRef.collection('chat_sessions').doc(sessionId);

    final messages = await sessionRef.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(sessionRef);
    await batch.commit();
  }

  Future<void> deleteChatSessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return;
    final userDocRef = await _requireUserDocRef();

    for (final sessionId in sessionIds) {
      final sessionRef = userDocRef.collection('chat_sessions').doc(sessionId);
      final messages = await sessionRef.collection('messages').get();
      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(sessionRef);
      await batch.commit();
    }
  }

  Future<void> addChatMessage({
    required String sessionId,
    required String text,
    required bool isBot,
    String? quickLinkLabel,
    String? quickLinkRoute,
  }) async {
    final userDocRef = await _requireUserDocRef();
    final sessionRef = userDocRef.collection('chat_sessions').doc(sessionId);

    await sessionRef.collection('messages').add({
      'text': text,
      'isBot': isBot,
      'quickLinkLabel': quickLinkLabel,
      'quickLinkRoute': quickLinkRoute,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview = text.length > 40 ? '${text.substring(0, 40)}…' : text;

    await sessionRef.update({
      'updatedAt': FieldValue.serverTimestamp(),
      'preview': preview,
      if (isBot) 'hasUnreadBotReply': true,
    });
  }

  Future<void> markSessionRead(String sessionId) async {
    final userDocRef = await _requireUserDocRef();
    await userDocRef.collection('chat_sessions').doc(sessionId).update({
      'hasUnreadBotReply': false,
    });
  }

  Future<void> markInquiryRead(String inquiryId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw HelpServiceException('로그인이 필요합니다.');
    }

    final inquiryRef = _firestore.collection('inquiries').doc(inquiryId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(inquiryRef);
      if (!snapshot.exists || snapshot.data()?['uid'] != user.uid) {
        throw HelpServiceException('문의 정보를 찾을 수 없습니다.');
      }
      transaction.update(inquiryRef, {'isReadByUser': true});
    });
  }

  Future<String?> getAiReply(String userText) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty || trimmed.length > 300) return null;

    try {
      final callable = _functions.httpsCallable(
        'chatbotReply',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 12)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'message': trimmed,
      });

      final reply = result.data['reply'] as String?;
      if (reply == null || reply.trim().isEmpty) return null;
      return reply.trim();
    } catch (_) {
      // 네트워크 오류, 함수 미배포 등 어떤 이유로든 실패하면
      // 조용히 null을 돌려주고 챗봇 화면에서 기본 안내 메시지로 대체합니다.
      return null;
    }
  }
}
