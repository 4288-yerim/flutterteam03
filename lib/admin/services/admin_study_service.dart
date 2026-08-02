import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStudyService {
  AdminStudyService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminStudyGroup>> watchGroups() {
    return _firestore.collection('studyGroups').snapshots().map((snapshot) {
      final groups = snapshot.docs
          .map(AdminStudyGroup.fromDocument)
          .toList(growable: false);
      groups.sort((a, b) {
        final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final second = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return second.compareTo(first);
      });
      return groups;
    });
  }

  Stream<Map<String, int>> watchStudyReportCounts() {
    return _firestore
        .collection('reports')
        .where('targetType', isEqualTo: 'STUDY_GROUP')
        .snapshots()
        .map((snapshot) {
          final counts = <String, int>{};
          for (final document in snapshot.docs) {
            for (final targetId in _targetIds(document.data()['targetId'])) {
              counts[targetId] = (counts[targetId] ?? 0) + 1;
            }
          }
          return counts;
        });
  }
}

class AdminStudyGroup {
  const AdminStudyGroup({
    required this.id,
    required this.groupName,
    required this.description,
    required this.ownerUid,
    required this.ownerNickname,
    required this.certificateName,
    required this.currentMemberCount,
    required this.maxMemberCount,
    required this.isPublic,
    required this.createdAt,
  });

  factory AdminStudyGroup.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AdminStudyGroup(
      id: document.id,
      groupName: _text(data['groupName'] ?? data['name'], fallback: '그룹명 없음'),
      description: _text(data['description']),
      ownerUid: _text(data['ownerUid']),
      ownerNickname: _text(data['ownerNickname'], fallback: '알 수 없음'),
      certificateName: _text(data['certificateName'], fallback: '공통 스터디'),
      currentMemberCount: _number(
        data['currentMemberCount'] ?? data['memberCount'],
      ),
      maxMemberCount: _number(data['maxMemberCount']),
      isPublic: _boolean(
        data['isPublic'] ?? data['visibility'],
        fallback: true,
      ),
      createdAt: _date(data['createdAt']),
    );
  }

  final String id;
  final String groupName;
  final String description;
  final String ownerUid;
  final String ownerNickname;
  final String certificateName;
  final int currentMemberCount;
  final int maxMemberCount;
  final bool isPublic;
  final DateTime? createdAt;
}

List<String> _targetIds(Object? value) {
  if (value is String) {
    final id = value.trim();
    return id.isEmpty ? const [] : <String>[id];
  }
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    if (item is Map) {
      final id = item['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) result.add(id);
    } else {
      final id = item?.toString().trim() ?? '';
      if (id.isNotEmpty) result.add(id);
    }
  }
  return result;
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

int _number(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolean(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value?.toString().toLowerCase() == 'true') return true;
  if (value?.toString().toLowerCase() == 'false') return false;
  return fallback;
}
