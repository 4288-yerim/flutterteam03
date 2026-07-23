import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeService {
  HomeService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Future<String> getCurrentUserNickname() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return '사용자';
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return '사용자';
      }

      final nickname = querySnapshot.docs.first.data()['nickname'];

      if (nickname is String && nickname.trim().isNotEmpty) {
        return nickname.trim();
      }

      return '사용자';
    } on FirebaseException catch (error) {
      throw HomeServiceException(
        error.message ?? '닉네임을 불러오지 못했습니다.',
      );
    } catch (_) {
      throw const HomeServiceException(
        '닉네임을 불러오는 중 오류가 발생했습니다.',
      );
    }
  }

  Stream<String> watchCurrentUserNickname() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return Stream<String>.value('사용자');
    }

    return _firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return '사용자';
      }

      final nickname = snapshot.docs.first.data()['nickname'];

      if (nickname is String && nickname.trim().isNotEmpty) {
        return nickname.trim();
      }

      return '사용자';
    }).handleError((Object error) {
      if (error is FirebaseException) {
        throw HomeServiceException(
          error.message ?? '닉네임을 불러오지 못했습니다.',
        );
      }

      throw const HomeServiceException(
        '닉네임을 불러오는 중 오류가 발생했습니다.',
      );
    });
  }

  Stream<List<HomeGoal>> watchActiveGoals() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return Stream<List<HomeGoal>>.value(const []);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .where('goalStatus', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) {
      final today = _dateOnly(DateTime.now());

      final goals = snapshot.docs
          .map(HomeGoal.fromFirestore)
          .where((goal) {
        return !goal.examDateOnly.isBefore(today);
      }).toList();

      goals.sort((first, second) {
        if (first.isMainGoal != second.isMainGoal) {
          return first.isMainGoal ? -1 : 1;
        }

        return first.targetExamDate.compareTo(
          second.targetExamDate,
        );
      });

      return goals;
    }).handleError((Object error) {
      if (error is FirebaseException) {
        throw HomeServiceException(
          error.message ?? '목표 자격증을 불러오지 못했습니다.',
        );
      }

      throw const HomeServiceException(
        '목표 자격증을 불러오는 중 오류가 발생했습니다.',
      );
    });
  }

  Stream<List<HomeTodo>> watchTodayTodos() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return Stream<List<HomeTodo>>.value(const []);
    }

    final now = DateTime.now();

    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final tomorrowStart = todayStart.add(
      const Duration(days: 1),
    );

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('studyPlans')
        .where(
      'planday',
      isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
    )
        .where(
      'planday',
      isLessThan: Timestamp.fromDate(tomorrowStart),
    )
        .snapshots()
        .map((snapshot) {
      final todos = snapshot.docs
          .map(HomeTodo.fromFirestore)
          .toList();

      todos.sort(
            (first, second) {
          return first.startPlannedAt.compareTo(
            second.startPlannedAt,
          );
        },
      );

      return todos;
    }).handleError((Object error) {
      if (error is FirebaseException) {
        throw HomeServiceException(
          error.message ?? '오늘의 학습 계획을 불러오지 못했습니다.',
        );
      }

      throw const HomeServiceException(
        '오늘의 학습 계획을 불러오는 중 오류가 발생했습니다.',
      );
    });
  }

  Future<void> toggleTodoStatus(HomeTodo todo) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const HomeServiceException(
        '로그인이 필요합니다.',
      );
    }

    final nextStatus = !todo.isCompleted;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('studyPlans')
          .doc(todo.id)
          .update({
        'status': nextStatus,
        'completedat': nextStatus
            ? FieldValue.serverTimestamp()
            : null,
        'updatedat': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw HomeServiceException(
        error.message ?? '학습 계획 상태를 변경하지 못했습니다.',
      );
    } catch (_) {
      throw const HomeServiceException(
        '학습 계획 상태를 변경하는 중 오류가 발생했습니다.',
      );
    }
  }

  static DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();

    return DateTime(
      local.year,
      local.month,
      local.day,
    );
  }
}

class HomeTodo {
  final String id;
  final String title;
  final String planType;
  final DateTime startPlannedAt;
  final DateTime endPlannedAt;
  final bool isCompleted;

  const HomeTodo({
    required this.id,
    required this.title,
    required this.planType,
    required this.startPlannedAt,
    required this.endPlannedAt,
    required this.isCompleted,
  });

  factory HomeTodo.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    final startPlannedAt = _readDateTime(
      data['startplannedat'],
    );

    final endPlannedAt = _readDateTime(
      data['endplannedat'],
    );

    if (startPlannedAt == null || endPlannedAt == null) {
      throw const HomeServiceException(
        '학습 시간이 없는 학습 계획이 있습니다.',
      );
    }

    return HomeTodo(
      id: document.id,
      title: _readString(
        data['plantitle'],
        fallback: '학습 계획',
      ),
      planType: _readString(
        data['plantype'],
        fallback: 'USERADD',
      ).toUpperCase(),
      startPlannedAt: startPlannedAt,
      endPlannedAt: endPlannedAt,
      isCompleted: data['status'] == true,
    );
  }

  static String _readString(
      dynamic value, {
        required String fallback,
      }) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }
}

class HomeGoal {
  final String id;
  final String certificateId;
  final String certificateName;
  final String qualificationType;
  final String scheduleId;
  final DateTime targetExamDate;
  final String targetExamType;
  final String targetRound;
  final DateTime? targetPassAnnouncementDate;
  final DateTime? targetPassAnnouncementEndDate;
  final bool isMainGoal;
  final bool calendarLinked;

  const HomeGoal({
    required this.id,
    required this.certificateId,
    required this.certificateName,
    required this.qualificationType,
    required this.scheduleId,
    required this.targetExamDate,
    required this.targetExamType,
    required this.targetRound,
    required this.targetPassAnnouncementDate,
    required this.targetPassAnnouncementEndDate,
    required this.isMainGoal,
    required this.calendarLinked,
  });

  bool get isTechnical => qualificationType == 'TECHNICAL';

  bool get isProfessional => qualificationType == 'PROFESSIONAL';

  String get qualificationLabel {
    if (isTechnical) {
      return '국가기술자격';
    }

    if (isProfessional) {
      return '국가전문자격';
    }

    return '자격증';
  }

  String get examTypeLabel {
    switch (targetExamType) {
      case 'WRITTEN':
        return '필기';
      case 'PRACTICAL':
        return '실기';
      default:
        return targetExamType.isEmpty ? '-' : targetExamType;
    }
  }

  DateTime get examDateOnly {
    final local = targetExamDate.toLocal();

    return DateTime(
      local.year,
      local.month,
      local.day,
    );
  }

  factory HomeGoal.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    final targetExamDate = _readDateTime(data['targetExamDate']);

    if (targetExamDate == null) {
      throw const HomeServiceException(
        '시험일이 없는 목표 데이터가 있습니다.',
      );
    }

    final rawQualificationType =
        _readString(data['qualificationType']).toUpperCase();
    final qualificationType = rawQualificationType == 'PROFESSIONAL'
        ? 'PROFESSIONAL'
        : 'TECHNICAL';

    return HomeGoal(
      id: document.id,
      certificateId: _readString(data['certificateId']),
      certificateName: _readString(data['certificateName']),
      qualificationType: qualificationType,
      scheduleId: _readString(data['scheduleId']),
      targetExamDate: targetExamDate,
      targetExamType: _readString(data['targetExamType']).toUpperCase(),
      targetRound: _readString(data['targetRound']),
      targetPassAnnouncementDate:
          _readDateTime(data['targetPassAnnouncementDate']),
      targetPassAnnouncementEndDate:
          _readDateTime(data['targetPassAnnouncementEndDate']),
      isMainGoal: _readBool(data['isMainGoal']),
      calendarLinked: _readBool(data['calendarLinked']),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }
}

class HomeServiceException implements Exception {
  final String message;

  const HomeServiceException(this.message);

  @override
  String toString() => message;
}
