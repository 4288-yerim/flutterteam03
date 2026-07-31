import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String? _nullableTrim(dynamic raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class FaqItem {
  final String id;
  final String question;
  final String answer;
  final String? quickLinkLabel;
  final String? quickLinkRoute;
  bool isExpanded;

  FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.quickLinkLabel,
    this.quickLinkRoute,
    this.isExpanded = false,
  });

  factory FaqItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return FaqItem(
      id: doc.id,
      question: (data['question'] as String?)?.trim() ?? '',
      answer: (data['answer'] as String?)?.trim() ?? '',
      quickLinkLabel: _nullableTrim(data['quickLinkLabel']),
      quickLinkRoute: _nullableTrim(data['quickLinkRoute']),
    );
  }
}

enum InquiryStatus { waiting, completed }

class InquiryItem {
  final String id;
  final String category;
  final String title;
  final String content;
  final DateTime createdAt;
  final InquiryStatus status;
  final String? answer;
  final DateTime? answeredAt;
  final bool isReadByUser;

  InquiryItem({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.status,
    this.answer,
    this.answeredAt,
    this.isReadByUser = true,
  });

  factory InquiryItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAtTs = data['createdAt'] as Timestamp?;
    final answeredAtTs = data['answeredAt'] as Timestamp?;

    return InquiryItem(
      id: doc.id,
      category: (data['category'] as String?) ?? '기타',
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
      status: (data['status'] as String?) == 'completed'
          ? InquiryStatus.completed
          : InquiryStatus.waiting,
      answer: data['answer'] as String?,
      answeredAt: answeredAtTs?.toDate(),
      isReadByUser: (data['isReadByUser'] as bool?) ?? true,
    );
  }
}

class InquiryDraft {
  final String category;
  final String title;
  final String content;

  const InquiryDraft({
    required this.category,
    required this.title,
    required this.content,
  });
}

class InquiryStatusStyle {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const InquiryStatusStyle({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}

class ChatSessionSummary {
  final String id;
  final String preview;
  final DateTime updatedAt;
  final bool hasUnreadBotReply;

  ChatSessionSummary({
    required this.id,
    required this.preview,
    required this.updatedAt,
    required this.hasUnreadBotReply,
  });

  factory ChatSessionSummary.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updatedAtTs = data['updatedAt'] as Timestamp?;
    return ChatSessionSummary(
      id: doc.id,
      preview: (data['preview'] as String?) ?? '',
      updatedAt: updatedAtTs?.toDate() ?? DateTime.now(),
      hasUnreadBotReply: (data['hasUnreadBotReply'] as bool?) ?? false,
    );
  }
}

class ChatMessageRecord {
  final String id;
  final String text;
  final bool isBot;
  final DateTime? createdAt;
  final String? quickLinkLabel;
  final String? quickLinkRoute;

  ChatMessageRecord({
    required this.id,
    required this.text,
    required this.isBot,
    required this.createdAt,
    this.quickLinkLabel,
    this.quickLinkRoute,
  });

  factory ChatMessageRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAtTs = data['createdAt'] as Timestamp?;
    return ChatMessageRecord(
      id: doc.id,
      text: (data['text'] as String?) ?? '',
      isBot: (data['isBot'] as bool?) ?? false,
      createdAt: createdAtTs?.toDate(),
      quickLinkLabel: _nullableTrim(data['quickLinkLabel']),
      quickLinkRoute: _nullableTrim(data['quickLinkRoute']),
    );
  }
}