import 'dart:async';

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

  /// 홈 새로고침 시 현재 사용자의 스터디 프로필을 다시 동기화합니다.
  ///
  /// 동기화 대상:
  /// 1. studyGroups/{studyId}/members/{uid}.nickname
  /// 2. 방장인 경우 studyGroups/{studyId}.ownerNickname
  Future<void> refreshCurrentUserStudyData() async {
    final User? currentUser = _firebaseAuth.currentUser;

    if (currentUser == null) {
      throw const HomeServiceException(
        '로그인 정보를 확인할 수 없습니다.',
      );
    }

    try {
      Map<String, dynamic> userData = <String, dynamic>{};

      // 우선 users/{uid} 문서 구조를 확인합니다.
      final DocumentSnapshot<Map<String, dynamic>> directUserSnapshot =
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (directUserSnapshot.exists) {
        userData = directUserSnapshot.data() ?? <String, dynamic>{};
      } else {
        // 기존 데이터가 자동 문서 ID를 사용한 경우 uid 필드로 다시 찾습니다.
        final QuerySnapshot<Map<String, dynamic>> userSnapshot =
        await _firestore
            .collection('users')
            .where(
          'uid',
          isEqualTo: currentUser.uid,
        )
            .limit(1)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          userData = userSnapshot.docs.first.data();
        }
      }

      String nickname =
          userData['nickname']?.toString().trim() ?? '';

      // Firestore 닉네임이 없는 기존 사용자는
      // Firebase Auth displayName을 보조값으로 사용합니다.
      if (nickname.isEmpty) {
        nickname = currentUser.displayName?.trim() ?? '';
      }

      // 실제 닉네임을 찾지 못한 경우
      // "사용자" 같은 임시값을 DB에 저장하지 않습니다.
      if (nickname.isEmpty) {
        return;
      }

      final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
      await _firestore
          .collection('studyGroups')
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> groupDocument
      in groupSnapshot.docs) {
        final Map<String, dynamic> groupData =
        groupDocument.data();

        final DocumentReference<Map<String, dynamic>> memberDocument =
        groupDocument.reference
            .collection('members')
            .doc(currentUser.uid);

        final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
        await memberDocument.get();

        // 가입하지 않은 스터디는 건너뜁니다.
        if (!memberSnapshot.exists) {
          continue;
        }

        final Map<String, dynamic> memberData =
            memberSnapshot.data() ?? <String, dynamic>{};

        final String savedMemberNickname =
            memberData['nickname']?.toString().trim() ?? '';

        // 스터디 멤버 문서의 닉네임이 다를 때만 수정합니다.
        if (savedMemberNickname != nickname) {
          await memberDocument.set(
            <String, dynamic>{
              'uid': currentUser.uid,
              'nickname': nickname,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        final String ownerUid =
            groupData['ownerUid']?.toString().trim() ?? '';

        // 현재 사용자가 방장인 경우 그룹 문서의 방장 닉네임도 수정합니다.
        if (ownerUid == currentUser.uid) {
          final String savedOwnerNickname =
              groupData['ownerNickname']?.toString().trim() ?? '';

          if (savedOwnerNickname != nickname) {
            await groupDocument.reference.set(
              <String, dynamic>{
                'ownerNickname': nickname,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        }
      }
    } on FirebaseException catch (error) {
      throw HomeServiceException(
        error.message ?? '홈 정보를 새로고침하지 못했습니다.',
      );
    } on HomeServiceException {
      rethrow;
    } catch (error) {
      throw HomeServiceException(
        '홈 정보를 새로고침하는 중 오류가 발생했습니다.\n$error',
      );
    }
  }

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

  Stream<HomeTodayStudySummary> watchTodayStudySummary() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return Stream<HomeTodayStudySummary>.value(
        const HomeTodayStudySummary.empty(),
      );
    }

    late final StreamController<HomeTodayStudySummary> controller;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    personalLogSubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    studyGroupSubscription;

    final groupSubscriptions = <
        StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    bool isLoading = false;
    bool reloadRequested = false;
    bool isUpdatingGroupSubscriptions = false;
    bool groupSubscriptionUpdateRequested = false;

    Future<void> loadAndEmit() async {
      if (isLoading) {
        reloadRequested = true;
        return;
      }

      isLoading = true;

      try {
        do {
          reloadRequested = false;

          final summary = await _loadTodayStudySummary(
            user.uid,
          );

          if (!controller.isClosed) {
            controller.add(summary);
          }
        } while (reloadRequested && !controller.isClosed);
      } catch (error, stackTrace) {
        print('홈 오늘 공부시간 조회 오류: $error');

        if (!controller.isClosed) {
          if (error is FirebaseException) {
            controller.addError(
              HomeServiceException(
                '[${error.code}] '
                    '${error.message ?? '오늘 공부 기록 조회 실패'}',
              ),
              stackTrace,
            );
          } else {
            controller.addError(
              HomeServiceException(
                error.toString(),
              ),
              stackTrace,
            );
          }
        }
      } finally {
        isLoading = false;
      }
    }

    Future<void> updateGroupSubscriptions() async {
      if (isUpdatingGroupSubscriptions) {
        groupSubscriptionUpdateRequested = true;
        return;
      }

      isUpdatingGroupSubscriptions = true;

      try {
        do {
          groupSubscriptionUpdateRequested = false;

          for (final subscription in groupSubscriptions) {
            await subscription.cancel();
          }

          groupSubscriptions.clear();

          final groupReferences =
          await _loadMyActiveStudyGroupReferences(user.uid);

          for (final groupReference in groupReferences) {
            final memberSubscription = groupReference
                .collection('members')
                .snapshots()
                .listen(
                  (_) {
                loadAndEmit();
              },
              onError: (Object error, StackTrace stackTrace) {
                print(
                  '홈 스터디 멤버 실시간 조회 오류: $error',
                );
              },
            );

            final recordSubscription = groupReference
                .collection('studyRecords')
                .snapshots()
                .listen(
                  (_) {
                loadAndEmit();
              },
              onError: (Object error, StackTrace stackTrace) {
                print(
                  '홈 스터디 기록 실시간 조회 오류: $error',
                );
              },
            );

            groupSubscriptions.add(memberSubscription);
            groupSubscriptions.add(recordSubscription);
          }

          await loadAndEmit();
        } while (groupSubscriptionUpdateRequested &&
            !controller.isClosed);
      } catch (error, stackTrace) {
        print(
          '홈 참여 스터디 실시간 연결 오류: $error',
        );

        if (!controller.isClosed) {
          controller.addError(
            error is FirebaseException
                ? HomeServiceException(
              '[${error.code}] '
                  '${error.message ?? '참여 스터디 조회 실패'}',
            )
                : HomeServiceException(
              error.toString(),
            ),
            stackTrace,
          );
        }
      } finally {
        isUpdatingGroupSubscriptions = false;
      }
    }

    controller = StreamController<HomeTodayStudySummary>(
      onListen: () {
        personalLogSubscription = _firestore
            .collection('userStudyLogs')
            .doc(user.uid)
            .collection('logs')
            .snapshots()
            .listen(
              (_) {
            loadAndEmit();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

        studyGroupSubscription = _firestore
            .collection('studyGroups')
            .snapshots()
            .listen(
              (_) {
            updateGroupSubscriptions();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

        updateGroupSubscriptions();
      },
      onCancel: () async {
        await personalLogSubscription?.cancel();
        await studyGroupSubscription?.cancel();

        for (final subscription in groupSubscriptions) {
          await subscription.cancel();
        }

        groupSubscriptions.clear();
      },
    );

    return controller.stream;
  }

  Future<HomeTodayStudySummary> _loadTodayStudySummary(
      String uid,
      ) async {
    final today = _dateOnly(DateTime.now());

    final personalRecords = await _loadTodayPersonalRecords(
      uid: uid,
      today: today,
    );

    List<HomeStudyGroupSummary> studyGroups = [];

    try {
      studyGroups = await _loadTodayStudyGroups(
        uid: uid,
        today: today,
      );
    } on FirebaseException catch (error) {
      print(
        '홈 스터디 공부시간 조회 실패: '
            '${error.code} / ${error.message}',
      );
    } catch (error) {
      print(
        '홈 스터디 공부시간 조회 실패: $error',
      );
    }

    final studyRecords = studyGroups
        .expand((group) => group.myRecords)
        .toList();

    final allRecords = <HomeStudyRecord>[
      ...personalRecords,
      ...studyRecords,
    ]..sort(
          (first, second) {
        return second.studiedAt.compareTo(
          first.studiedAt,
        );
      },
    );

    final personalSeconds = personalRecords.fold<int>(
      0,
          (sum, record) {
        if (record.seconds > 0) {
          return sum + record.seconds;
        }

        return sum + record.minutes * 60;
      },
    );

    final studySeconds = studyGroups.fold<int>(
      0,
          (sum, group) => sum + group.myStudySeconds,
    );

    return HomeTodayStudySummary(
      personalSeconds: personalSeconds,
      studySeconds: studySeconds,
      records: allRecords,
      studyGroups: studyGroups,
    );
  }

  Future<List<HomeStudyRecord>> _loadTodayPersonalRecords({
    required String uid,
    required DateTime today,
  }) async {
    final snapshot = await _firestore
        .collection('userStudyLogs')
        .doc(uid)
        .collection('logs')
        .get();

    final records = <HomeStudyRecord>[];

    for (final dailyDocument in snapshot.docs) {
      final dailyData = dailyDocument.data();

      final fallbackDate = _readStudyDate(
        dailyData['date'],
        dailyDocument.id,
      );

      if (!_isSameDate(fallbackDate, today)) {
        continue;
      }

      final sessionSnapshot = await dailyDocument.reference
          .collection('sessions')
          .get();

      if (sessionSnapshot.docs.isEmpty) {
        final storedTotalSeconds =
            (dailyData['totalSeconds'] as num?)?.toInt() ?? 0;

        final storedTotalMinutes =
            (dailyData['totalMinutes'] as num?)?.toInt() ?? 0;

        final totalSeconds = storedTotalSeconds > 0
            ? storedTotalSeconds
            : storedTotalMinutes * 60;

        if (totalSeconds > 0) {
          records.add(
            HomeStudyRecord(
              id: dailyDocument.id,
              studiedAt: fallbackDate,
              subject: '학습 기록',
              description: '오늘의 총 학습 시간',
              minutes: totalSeconds ~/ 60,
              seconds: totalSeconds,
              studyType: 'OTHER',
            ),
          );
        }

        continue;
      }

      for (final sessionDocument in sessionSnapshot.docs) {
        final data = sessionDocument.data();

        final storedDurationSeconds =
            (data['durationSeconds'] as num?)?.toInt() ?? 0;

        final storedDurationMinutes =
            (data['durationMinutes'] as num?)?.toInt() ?? 0;

        final durationSeconds = storedDurationSeconds > 0
            ? storedDurationSeconds
            : storedDurationMinutes * 60;

        if (durationSeconds <= 0) {
          continue;
        }

        final minutes = durationSeconds ~/ 60;

        final subject = _readStudyText(
          data,
          const [
            'subject',
            'studyTypeName',
            'certificateName',
          ],
          '학습 기록',
        );

        final memo = _readStudyText(
          data,
          const ['memo'],
          '',
        );

        final studyTypeName = _readStudyText(
          data,
          const ['studyTypeName'],
          '자유 학습',
        );

        final certificateName = _readStudyText(
          data,
          const ['certificateName'],
          '',
        );

        final description = memo.isNotEmpty
            ? memo
            : certificateName.isNotEmpty &&
            certificateName != subject
            ? '$studyTypeName · $certificateName'
            : studyTypeName;

        records.add(
          HomeStudyRecord(
            id: sessionDocument.id,
            studiedAt: _readStudySessionDate(
              data,
              fallbackDate,
            ),
            subject: subject,
            description: description,
            minutes: minutes,
            seconds: durationSeconds,
            studyType:
            (data['studyType'] as String? ?? 'OTHER')
                .trim()
                .toUpperCase(),
          ),
        );
      }
    }

    return records;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>>
  _loadMyActiveStudyGroupReferences(String uid) async {
    final groupSnapshot = await _firestore
        .collection('studyGroups')
        .get();

    final groupReferences =
    <DocumentReference<Map<String, dynamic>>>[];

    for (final groupDocument in groupSnapshot.docs) {
      final groupData = groupDocument.data();
      final ownerUid =
      (groupData['ownerUid'] as String? ?? '').trim();

      if (ownerUid == uid) {
        groupReferences.add(groupDocument.reference);
        continue;
      }

      final memberSnapshot = await groupDocument.reference
          .collection('members')
          .doc(uid)
          .get();

      if (!memberSnapshot.exists) {
        continue;
      }

      final memberData = memberSnapshot.data() ?? {};
      final memberStatus =
      (memberData['status'] as String? ?? '')
          .trim()
          .toUpperCase();

      if (memberStatus == 'ACTIVE') {
        groupReferences.add(groupDocument.reference);
      }
    }

    return groupReferences;
  }

  Future<List<HomeStudyGroupSummary>> _loadTodayStudyGroups({
    required String uid,
    required DateTime today,
  }) async {
    final groupReferences =
    await _loadMyActiveStudyGroupReferences(uid);

    final groups = <HomeStudyGroupSummary>[];

    for (final groupReference in groupReferences) {
      final todayStart = DateTime(
        today.year,
        today.month,
        today.day,
      );

      final tomorrowStart = todayStart.add(
        const Duration(days: 1),
      );

      final weekStart = todayStart.subtract(
        Duration(days: todayStart.weekday - DateTime.monday),
      );

      final results = await Future.wait([
        groupReference.get(),
        groupReference.collection('members').get(),
        groupReference
            .collection('studyRecords')
            .where(
          'endedAt',
          isGreaterThanOrEqualTo:
          Timestamp.fromDate(weekStart),
        )
            .where(
          'endedAt',
          isLessThan:
          Timestamp.fromDate(tomorrowStart),
        )
            .get(),
      ]);

      final groupSnapshot =
      results[0] as DocumentSnapshot<Map<String, dynamic>>;

      final memberSnapshot =
      results[1] as QuerySnapshot<Map<String, dynamic>>;

      final recordSnapshot =
      results[2] as QuerySnapshot<Map<String, dynamic>>;

      if (!groupSnapshot.exists) {
        continue;
      }

      final groupData = groupSnapshot.data() ?? {};

      final groupName = _readStudyText(
        groupData,
        const [
          'groupName',
          'studyName',
          'name',
          'title',
        ],
        '스터디',
      );

      final weeklyGoalMinutes =
          (groupData['weeklyGoalMinutes'] as num?)
              ?.toInt() ??
              0;

      final nicknameByUid = <String, String>{};
      final memberStatusByUid = <String, String>{};
      final activeMemberUids = <String>[];

      int studyingMemberCount = 0;
      int restingMemberCount = 0;
      int pausedMemberCount = 0;

      for (final memberDocument in memberSnapshot.docs) {
        final memberData = memberDocument.data();

        final memberUid =
        (memberData['uid'] as String? ??
            memberDocument.id)
            .trim();

        if (memberUid.isEmpty) {
          continue;
        }

        final memberStatus =
        (memberData['status'] as String? ?? '')
            .trim()
            .toUpperCase();

        final memberRole =
        (memberData['role'] as String? ?? 'MEMBER')
            .trim()
            .toUpperCase();

        // 탈퇴 여부를 나중에 확인할 수 있도록
        // 모든 멤버의 상태를 먼저 저장합니다.
        memberStatusByUid[memberUid] = memberStatus;

        // 탈퇴한 멤버의 기존 닉네임도 일단 보관합니다.
        nicknameByUid[memberUid] = _readStudyText(
          memberData,
          const [
            'nickname',
            'displayName',
            'name',
          ],
          memberUid == uid ? '나' : '사용자',
        );

        // 현재 활동 중인 멤버와 방장만
        // 현재 멤버 상태 및 0초 순위 목록에 포함합니다.
        if (memberStatus != 'ACTIVE' &&
            memberRole != 'OWNER') {
          continue;
        }

        final studyStatus =
        _readMemberStudyStatus(memberData);

        switch (studyStatus) {
          case 'STUDYING':
            studyingMemberCount++;
            break;

          case 'RESTING':
            restingMemberCount++;
            break;

          case 'PAUSED':
            pausedMemberCount++;
            break;
        }

        activeMemberUids.add(memberUid);
      }

      final ownerUid =
      (groupData['ownerUid'] as String? ?? '').trim();

      if (ownerUid.isNotEmpty &&
          !activeMemberUids.contains(ownerUid)) {
        activeMemberUids.add(ownerUid);
        nicknameByUid[ownerUid] = _readStudyText(
          groupData,
          const [
            'ownerNickname',
            'nickname',
          ],
          ownerUid == uid ? '나' : '방장',
        );
      }

      final memberSeconds = <String, int>{
        for (final memberUid in activeMemberUids)
          memberUid: 0,
      };

      int weeklyStudySeconds = 0;

      final myRecords = <HomeStudyRecord>[];

      for (final recordDocument in recordSnapshot.docs) {
        final data = recordDocument.data();

        final recordDate =
        _readGroupStudyRecordDate(data);

        if (recordDate == null) {
          continue;
        }

        final recordUid =
        (data['uid'] as String? ?? '').trim();

        if (recordUid.isEmpty) {
          continue;
        }

        final studySeconds =
        _readGroupStudySeconds(data);

        if (studySeconds <= 0) {
          continue;
        }

// 이번 주 스터디원 전체 공부시간
        weeklyStudySeconds += studySeconds;

// 아래부터는 오늘 기록만 계산
        if (!_isSameDate(recordDate, today)) {
          continue;
        }

        memberSeconds[recordUid] =
            (memberSeconds[recordUid] ?? 0) +
                studySeconds;

        if (recordUid != uid) {
          continue;
        }

        final subject = _readStudyText(
          data,
          const [
            'subject',
            'studySubject',
          ],
          '스터디 공부',
        );

        myRecords.add(
          HomeStudyRecord(
            id: recordDocument.id,
            studiedAt: recordDate,
            subject: groupName,
            description: subject,
            minutes: studySeconds ~/ 60,
            seconds: studySeconds,
            studyType: 'STUDY_GROUP',
            isStudyGroup: true,
            studyId: groupReference.id,
            groupName: groupName,
          ),
        );
      }

      final members = memberSeconds.entries.map((entry) {
        final memberStatus =
            memberStatusByUid[entry.key] ?? '';

        final hasLeft = memberStatus == 'LEFT';

        return HomeStudyGroupMemberSummary(
          uid: entry.key,
          nickname: hasLeft
              ? '스터디 탈퇴 사용자'
              : nicknameByUid[entry.key] ?? '사용자',
          studySeconds: entry.value,
          isCurrentUser: entry.key == uid,
          memberStatus: memberStatus,
        );
      }).toList()
        ..sort((first, second) {
          final secondsCompare =
          second.studySeconds.compareTo(
            first.studySeconds,
          );

          if (secondsCompare != 0) {
            return secondsCompare;
          }

          if (first.isCurrentUser !=
              second.isCurrentUser) {
            return first.isCurrentUser ? -1 : 1;
          }

          return first.nickname.compareTo(
            second.nickname,
          );
        });

      groups.add(
        HomeStudyGroupSummary(
          studyId: groupReference.id,
          groupName: groupName,
          members: members,
          myRecords: myRecords,
          weeklyStudySeconds: weeklyStudySeconds,
          weeklyGoalMinutes: weeklyGoalMinutes,
          studyingMemberCount: studyingMemberCount,
          restingMemberCount: restingMemberCount,
          pausedMemberCount: pausedMemberCount,
        ),
      );
    }

    groups.sort(
          (first, second) {
        return first.groupName.compareTo(
          second.groupName,
        );
      },
    );

    return groups;
  }

  static String _readMemberStudyStatus(
      Map<String, dynamic> data,
      ) {
    final studyStatus =
    (data['studyStatus'] as String? ?? '')
        .trim()
        .toUpperCase();

    if (studyStatus == 'STUDYING' ||
        studyStatus == 'RESTING' ||
        studyStatus == 'PAUSED' ||
        studyStatus == 'IDLE') {
      return studyStatus;
    }

    final timerSessionActive =
        data['timerSessionActive'] == true;

    if (timerSessionActive &&
        data['timerPaused'] == true) {
      return 'PAUSED';
    }

    if (data['isResting'] == true) {
      return 'RESTING';
    }

    if (data['isStudying'] == true) {
      return 'STUDYING';
    }

    return 'IDLE';
  }

  static int _readGroupStudySeconds(
      Map<String, dynamic> data,
      ) {
    final studySeconds = data['studySeconds'];

    if (studySeconds is num) {
      return studySeconds.toInt();
    }

    final elapsedSeconds = data['elapsedSeconds'];

    if (elapsedSeconds is num) {
      return elapsedSeconds.toInt();
    }

    final studyMinutes = data['studyMinutes'];

    if (studyMinutes is num) {
      return (studyMinutes * 60).round();
    }

    return 0;
  }

  static DateTime? _readGroupStudyRecordDate(
      Map<String, dynamic> data,
      ) {
    for (final fieldName in [
      'endedAt',
      'startedAt',
      'createdAt',
    ]) {
      final value = data[fieldName];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }
    }

    final studyDate = data['studyDate'];

    if (studyDate is String &&
        studyDate.trim().isNotEmpty) {
      return DateTime.tryParse(studyDate.trim());
    }

    return null;
  }

  static DateTime _readStudyDate(
      dynamic value,
      String documentId,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      final parsedDate = DateTime.tryParse(value.trim());

      if (parsedDate != null) {
        return parsedDate;
      }
    }

    return DateTime.tryParse(documentId) ?? DateTime.now();
  }

  static DateTime _readStudySessionDate(
      Map<String, dynamic> data,
      DateTime fallbackDate,
      ) {
    for (final fieldName in [
      'endedAt',
      'startedAt',
      'createdAt',
    ]) {
      final value = data[fieldName];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }
    }

    return fallbackDate;
  }

  static String _readStudyText(
      Map<String, dynamic> data,
      List<String> fieldNames,
      String fallback,
      ) {
    for (final fieldName in fieldNames) {
      final value = data[fieldName];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  static bool _isSameDate(
      DateTime first,
      DateTime second,
      ) {
    final firstLocal = first.toLocal();
    final secondLocal = second.toLocal();

    return firstLocal.year == secondLocal.year &&
        firstLocal.month == secondLocal.month &&
        firstLocal.day == secondLocal.day;
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

class HomeTodayStudySummary {
  final int personalSeconds;
  final int studySeconds;
  final List<HomeStudyRecord> records;
  final List<HomeStudyGroupSummary> studyGroups;

  const HomeTodayStudySummary({
    required this.personalSeconds,
    required this.studySeconds,
    required this.records,
    required this.studyGroups,
  });

  const HomeTodayStudySummary.empty()
      : personalSeconds = 0,
        studySeconds = 0,
        records = const [],
        studyGroups = const [];

  int get totalSeconds {
    return personalSeconds + studySeconds;
  }

  int get personalMinutes {
    return personalSeconds ~/ 60;
  }

  int get studyMinutes {
    return studySeconds ~/ 60;
  }

  int get totalMinutes {
    return totalSeconds ~/ 60;
  }

  bool get hasRecords => records.isNotEmpty;
}

class HomeStudyRecord {
  final String id;
  final DateTime studiedAt;
  final String subject;
  final String description;
  final int minutes;
  final int seconds;
  final String studyType;
  final bool isStudyGroup;
  final String studyId;
  final String groupName;

  const HomeStudyRecord({
    required this.id,
    required this.studiedAt,
    required this.subject,
    required this.description,
    required this.minutes,
    this.seconds = 0,
    required this.studyType,
    this.isStudyGroup = false,
    this.studyId = '',
    this.groupName = '',
  });
}

class HomeStudyGroupSummary {
  final String studyId;
  final String groupName;
  final List<HomeStudyGroupMemberSummary> members;
  final List<HomeStudyRecord> myRecords;
  final int weeklyStudySeconds;
  final int weeklyGoalMinutes;
  final int studyingMemberCount;
  final int restingMemberCount;
  final int pausedMemberCount;

  const HomeStudyGroupSummary({
    required this.studyId,
    required this.groupName,
    required this.members,
    required this.myRecords,
    required this.weeklyStudySeconds,
    required this.weeklyGoalMinutes,
    required this.studyingMemberCount,
    required this.restingMemberCount,
    required this.pausedMemberCount,
  });

  // 토글 내부 멤버별 오늘 공부시간 합계
  int get totalStudySeconds {
    return members.fold<int>(
      0,
          (sum, member) => sum + member.studySeconds,
    );
  }

  int get weeklyGoalSeconds {
    return weeklyGoalMinutes * 60;
  }

  int get myStudySeconds {
    return myRecords.fold<int>(
      0,
          (sum, record) {
        if (record.seconds > 0) {
          return sum + record.seconds;
        }

        return sum + record.minutes * 60;
      },
    );
  }
}

class HomeStudyGroupMemberSummary {
  final String uid;
  final String nickname;
  final int studySeconds;
  final bool isCurrentUser;
  final String memberStatus;

  const HomeStudyGroupMemberSummary({
    required this.uid,
    required this.nickname,
    required this.studySeconds,
    required this.isCurrentUser,
    this.memberStatus = '',
  });

  bool get hasLeft {
    return memberStatus == 'LEFT';
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

  final DateTime? targetRegistrationStartDate;
  final DateTime? targetRegistrationEndDate;

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
    required this.targetRegistrationStartDate,
    required this.targetRegistrationEndDate,
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
        return isProfessional ? '실기·면접' : '실기';

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

    final targetExamDate =
    _readDateTime(data['targetExamDate']);

    if (targetExamDate == null) {
      throw const HomeServiceException(
        '시험일이 없는 목표 데이터가 있습니다.',
      );
    }

    final rawQualificationType =
    _readString(
      data['qualificationType'],
    ).toUpperCase();

    final qualificationType =
    rawQualificationType == 'PROFESSIONAL'
        ? 'PROFESSIONAL'
        : 'TECHNICAL';

    return HomeGoal(
      id: document.id,
      certificateId:
      _readString(data['certificateId']),
      certificateName:
      _readString(data['certificateName']),
      qualificationType: qualificationType,
      scheduleId:
      _readString(data['scheduleId']),
      targetExamDate: targetExamDate,
      targetExamType:
      _readString(
        data['targetExamType'],
      ).toUpperCase(),
      targetRound:
      _readString(data['targetRound']),

      targetRegistrationStartDate:
      _readDateTime(
        data['targetRegistrationStartDate'],
      ),
      targetRegistrationEndDate:
      _readDateTime(
        data['targetRegistrationEndDate'],
      ),

      targetPassAnnouncementDate:
      _readDateTime(
        data['targetPassAnnouncementDate'],
      ),
      targetPassAnnouncementEndDate:
      _readDateTime(
        data['targetPassAnnouncementEndDate'],
      ),

      isMainGoal:
      _readBool(data['isMainGoal']),
      calendarLinked:
      _readBool(data['calendarLinked']),
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

    return value
        ?.toString()
        .toLowerCase() ==
        'true';
  }

  static DateTime? _readDateTime(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String &&
        value.trim().isNotEmpty) {
      return DateTime.tryParse(
        value.trim(),
      );
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
