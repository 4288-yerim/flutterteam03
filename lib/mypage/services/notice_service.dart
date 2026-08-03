import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notice_models.dart';

class NoticeService {
  final _db = FirebaseFirestore.instance;

  Stream<List<NoticeItem>> watchNotices() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();

    return _db
        .collection('notices')
        .where('status', isEqualTo: 'PUBLISHED')
        .snapshots()
        .map((snap) {
      final notices = snap.docs
          .map((d) => NoticeItem.fromMap(d.id, d.data()))
          .where((n) {
        final notExpired =
            n.expiredAt == null || n.expiredAt!.isAfter(now);
        final visible = n.targetType == NoticeTargetType.all ||
            (uid != null && n.targetUids.contains(uid));
        return notExpired && visible;
      })
          .toList();

      notices.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aDate = a.publishedAt ?? a.createdAt;
        final bDate = b.publishedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      return notices;
    });
  }
}