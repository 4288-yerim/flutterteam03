import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
enum NoticeType { app, exam, update }

extension NoticeTypeX on NoticeType {
  static NoticeType fromString(String? value) {
    switch (value) {
      case 'EXAM':
        return NoticeType.exam;
      case 'UPDATE':
        return NoticeType.update;
      default:
        return NoticeType.app;
    }
  }

  Color badgeBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case NoticeType.exam:
        return isDark ? const Color(0xFF3A3350) : const Color(0xFFE3D6FA);
      case NoticeType.update:
        return isDark ? const Color(0xFF25433A) : const Color(0xFFD4F3E6);
      case NoticeType.app:
        return isDark ? const Color(0xFF4A2E3B) : const Color(0xFFFBD4E1);
    }
  }

  Color badgeFg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case NoticeType.exam:
        return isDark ? const Color(0xFFC3AEFB) : const Color(0xFF8A6FE0);
      case NoticeType.update:
        return isDark ? const Color(0xFF80E0B0) : const Color(0xFF3FA57A);
      case NoticeType.app:
        return isDark ? const Color(0xFFFFA6C4) : const Color(0xFFEC6A9C);
    }
  }

  String get raw {
    switch (this) {
      case NoticeType.exam:
        return 'EXAM';
      case NoticeType.update:
        return 'UPDATE';
      case NoticeType.app:
        return 'APP';
    }
  }

  String get label {
    switch (this) {
      case NoticeType.exam:
        return '시험·접수';
      case NoticeType.update:
        return '업데이트';
      case NoticeType.app:
        return '일반';
    }
  }
}

enum NoticeTargetType { all, specificUsers }

extension NoticeTargetTypeX on NoticeTargetType {
  static NoticeTargetType fromString(String? value) {
    return value == 'SPECIFIC_USERS'
        ? NoticeTargetType.specificUsers
        : NoticeTargetType.all;
  }
}

enum NoticeStatus { draft, scheduled, published, ended }

extension NoticeStatusX on NoticeStatus {
  static NoticeStatus fromString(String? value) {
    switch (value) {
      case 'DRAFT':
        return NoticeStatus.draft;
      case 'SCHEDULED':
        return NoticeStatus.scheduled;
      case 'ENDED':
        return NoticeStatus.ended;
      default:
        return NoticeStatus.published;
    }
  }
}

class NoticeItem {
  final String id;
  final String title;
  final String content;
  final NoticeType noticeType;
  final NoticeTargetType targetType;
  final List<String> targetUids;
  final bool isPinned;
  final NoticeStatus status;
  final DateTime? publishedAt;
  final DateTime? expiredAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoticeItem({
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
  });

  factory NoticeItem.fromMap(String id, Map<String, dynamic> map) {
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

    return NoticeItem(
      id: id,
      title: (map['title'] ?? '') as String,
      content: (map['content'] ?? '') as String,
      noticeType: NoticeTypeX.fromString(map['noticeType'] as String?),
      targetType: NoticeTargetTypeX.fromString(map['targetType'] as String?),
      targetUids: List<String>.from(map['targetUids'] ?? const []),
      isPinned: (map['isPinned'] ?? false) as bool,
      status: NoticeStatusX.fromString(map['status'] as String?),
      publishedAt: toDate(map['publishedAt']),
      expiredAt: toDate(map['expiredAt']),
      createdBy: (map['createdBy'] ?? '') as String,
      createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: toDate(map['updatedAt']) ?? DateTime.now(),
    );
  }
}