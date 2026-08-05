import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminMemberService {
  AdminMemberService({
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

  Stream<List<AdminMember>> watchMembers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'USER')
        .snapshots()
        .map((snapshot) {
          final members = snapshot.docs.map(AdminMember.fromDocument).toList();
          members.sort(
            (a, b) =>
                a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
          );
          return members;
        });
  }

  Future<void> refreshMembers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'USER')
        .get(const GetOptions(source: Source.server));
  }

  Future<void> updateMemberSuspension({
    required String uid,
    required bool suspend,
  }) async {
    final administrator = _firebaseAuth.currentUser;
    if (administrator == null) {
      throw StateError('관리자 로그인이 필요합니다.');
    }
    await administrator.getIdToken(true);
    final operationId = _firestore.collection('adminOperations').doc().id;
    await _functions.httpsCallable('setAdminMemberSuspension').call<Object?>({
      'operationId': operationId,
      'targetUid': uid,
      'suspend': suspend,
    });
  }

  Future<void> updateMemberProfile({
    required String uid,
    required String nickname,
    required String bio,
  }) {
    final trimmedNickname = nickname.trim();
    final trimmedBio = bio.trim();
    if (trimmedNickname.isEmpty || trimmedNickname.length > 12) {
      throw ArgumentError('닉네임은 1자 이상 12자 이하로 입력해야 합니다.');
    }
    if (trimmedBio.length > 100) {
      throw ArgumentError('소개글은 100자 이하로 입력해야 합니다.');
    }

    return _firestore.collection('users').doc(uid).update({
      'nickname': trimmedNickname,
      'bio': trimmedBio,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<AdminMemberDetail> fetchMemberDetail(AdminMember member) async {
    final userReference = _firestore.collection('users').doc(member.uid);

    final results = await Future.wait<dynamic>([
      userReference.get(),
      userReference.collection('settings').doc('app').get(),
      userReference.collection('subscription').doc('current').get(),
      userReference.collection('goals').get(),
      userReference.collection('studyPlans').get(),
      userReference.collection('quiz_sessions').get(),
      userReference.collection('roadmaps').get(),
      userReference.collection('saved_summaries').get(),
      _firestore.collection('studyGroups').get(),
      _firestore
          .collection('posts')
          .where('writerUid', isEqualTo: member.uid)
          .get(),
      _firestore.collection('posts').get(),
    ]);

    final userDocument = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final settingsDocument =
        results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final subscriptionDocument =
        results[2] as DocumentSnapshot<Map<String, dynamic>>;
    final goalSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
    final studyPlanSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;
    final quizSnapshot = results[5] as QuerySnapshot<Map<String, dynamic>>;
    final roadmapSnapshot = results[6] as QuerySnapshot<Map<String, dynamic>>;
    final summarySnapshot = results[7] as QuerySnapshot<Map<String, dynamic>>;
    final groupSnapshot = results[8] as QuerySnapshot<Map<String, dynamic>>;
    final postSnapshot = results[9] as QuerySnapshot<Map<String, dynamic>>;
    final communityPostSnapshot =
        results[10] as QuerySnapshot<Map<String, dynamic>>;

    final userData = userDocument.data() ?? <String, dynamic>{};
    final settingsData = settingsDocument.data() ?? <String, dynamic>{};
    final subscriptionData = subscriptionDocument.data() ?? <String, dynamic>{};

    final studies = <AdminStudy>[];
    for (final group in groupSnapshot.docs) {
      final memberDocument = await group.reference
          .collection('members')
          .doc(member.uid)
          .get();
      if (!memberDocument.exists) {
        continue;
      }

      final memberStatus = _text(
        memberDocument.data()?['status'],
        fallback: 'ACTIVE',
      ).toUpperCase();
      if (memberStatus != 'ACTIVE') {
        continue;
      }

      final data = group.data();
      studies.add(
        AdminStudy(
          name: _text(data['groupName'], fallback: '이름 없는 스터디'),
          certificateName: _text(data['certificateName'], fallback: '자격증 미지정'),
          currentMemberCount: _integer(data['currentMemberCount']),
          maxMemberCount: _integer(data['maxMemberCount']),
        ),
      );
    }

    final studyPlans = studyPlanSnapshot.docs
        .where(
          (document) =>
              _text(document.data()['plantype']).toUpperCase() != 'USERADD',
        )
        .map((document) => AdminAiRecord('학습 플랜', document.data()))
        .toList();

    final posts = postSnapshot.docs
        .where((document) => _isVisibleCommunityContent(document.data()))
        .map(
          (document) => AdminCommunityActivity(
            id: document.id,
            postId: document.id,
            type: AdminCommunityActivityType.post,
            content: _text(document.data()['title'], fallback: '제목 없는 게시글'),
            boardType: _text(
              document.data()['boardType'],
              fallback: 'FREE',
            ).toUpperCase(),
            createdAt: _nullableDate(document.data()['createdAt']),
          ),
        )
        .toList();

    final comments = <AdminCommunityActivity>[];
    for (final post in communityPostSnapshot.docs) {
      final postData = post.data();
      if (!_isVisibleCommunityContent(postData)) {
        continue;
      }

      final commentSnapshot = await post.reference.collection('comments').get();
      for (final comment in commentSnapshot.docs) {
        final commentData = comment.data();
        if (_text(commentData['writerUid']) != member.uid ||
            !_isVisibleComment(commentData)) {
          continue;
        }
        comments.add(
          AdminCommunityActivity(
            id: comment.id,
            postId: post.id,
            type: AdminCommunityActivityType.comment,
            content: _text(commentData['content'], fallback: '내용 없는 댓글'),
            boardType: _text(
              postData['boardType'],
              fallback: 'FREE',
            ).toUpperCase(),
            createdAt: _nullableDate(commentData['createdAt']),
          ),
        );
      }
    }

    _sortActivities(posts);
    _sortActivities(comments);

    return AdminMemberDetail(
      member: AdminMember.fromData(member.uid, userData),
      marketingAlertEnabled:
          settingsData['marketingAlertEnabled'] as bool? ?? false,
      isSubscribed:
          subscriptionDocument.exists &&
          _text(subscriptionData['status']).toUpperCase() == 'ACTIVE',
      goals: goalSnapshot.docs.map((document) {
        final data = document.data();
        return AdminGoal(
          certificateName: _text(
            data['certificateName'],
            fallback: '자격증 이름 없음',
          ),
          createdAt: _nullableDate(data['createdAt']),
          updatedAt: _nullableDate(data['updatedAt']),
        );
      }).toList(),
      studies: studies,
      studyPlans: _sortRecords(studyPlans),
      quizzes: _sortRecords(
        quizSnapshot.docs
            .map((document) => AdminAiRecord('문제 생성', document.data()))
            .toList(),
      ),
      roadmaps: _sortRecords(
        roadmapSnapshot.docs
            .map((document) => AdminAiRecord('로드맵', document.data()))
            .toList(),
      ),
      summaries: _sortRecords(
        summarySnapshot.docs
            .map((document) => AdminAiRecord('요약 생성', document.data()))
            .toList(),
      ),
      posts: posts,
      comments: comments,
    );
  }

  static bool _isVisibleCommunityContent(Map<String, dynamic> data) {
    return _text(data['postStatus'], fallback: 'NORMAL').toUpperCase() ==
            'NORMAL' &&
        _text(data['visibility'], fallback: 'PUBLIC').toUpperCase() ==
            'PUBLIC' &&
        data['deletedAt'] == null;
  }

  static bool _isVisibleComment(Map<String, dynamic> data) {
    return _text(data['commentStatus'], fallback: 'NORMAL').toUpperCase() ==
            'NORMAL' &&
        data['deletedAt'] == null;
  }

  static void _sortActivities(List<AdminCommunityActivity> activities) {
    activities.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
  }

  static List<AdminAiRecord> _sortRecords(List<AdminAiRecord> records) {
    records.sort(
      (a, b) =>
          _date(b.data['createdAt']).compareTo(_date(a.data['createdAt'])),
    );
    return records;
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _integer(dynamic value) => value is num ? value.toInt() : 0;

  static DateTime _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _nullableDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return value is DateTime ? value : null;
  }
}

class AdminMember {
  const AdminMember({
    required this.uid,
    required this.nickname,
    required this.email,
    required this.loginProvider,
    required this.status,
    required this.profileImageUrl,
    required this.bio,
    required this.createdAt,
    required this.lastLoginAt,
    required this.reportCount,
    required this.postReportCount,
    required this.commentsReportCount,
    required this.studyMemberReportCount,
  });

  factory AdminMember.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return AdminMember.fromData(document.id, document.data());
  }

  factory AdminMember.fromData(String uid, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return AdminMember(
      uid: uid,
      nickname: AdminMemberService._text(data['nickname'], fallback: '닉네임 없음'),
      email: AdminMemberService._text(data['email']),
      loginProvider: AdminMemberService._text(
        data['loginProvider'],
        fallback: 'PASSWORD',
      ).toUpperCase(),
      status: AdminMemberService._text(
        data['status'],
        fallback: 'ACTIVE',
      ).toUpperCase(),
      profileImageUrl: AdminMemberService._text(data['profileImageUrl']),
      bio: AdminMemberService._text(data['bio']),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      lastLoginAt: AdminMemberService._nullableDate(data['lastLoginAt']),
      reportCount: AdminMemberService._integer(data['reportCount']),
      postReportCount: AdminMemberService._integer(data['postReportCount']),
      commentsReportCount: AdminMemberService._integer(
        data['commentsReportCount'],
      ),
      studyMemberReportCount: AdminMemberService._integer(
        data['studyMemberReportCount'],
      ),
    );
  }

  final String uid;
  final String nickname;
  final String email;
  final String loginProvider;
  final String status;
  final String profileImageUrl;
  final String bio;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final int reportCount;
  final int postReportCount;
  final int commentsReportCount;
  final int studyMemberReportCount;

  String get providerLabel => switch (loginProvider) {
    'KAKAO' => '카카오',
    'NAVER' => '네이버',
    'GOOGLE' => '구글',
    'PASSWORD' => '이메일',
    _ => loginProvider,
  };

  String get identifier => loginProvider == 'PASSWORD' ? email : providerLabel;

  String get statusLabel => switch (status) {
    'ACTIVE' => '활성',
    'DORMANT' => '휴면',
    'SUSPENDED' => '정지',
    'WITHDRAWN' => '탈퇴',
    'WITHDRAWAL_PENDING' => '탈퇴 신청',
    _ => status,
  };
}

class AdminMemberDetail {
  const AdminMemberDetail({
    required this.member,
    required this.marketingAlertEnabled,
    required this.isSubscribed,
    required this.goals,
    required this.studies,
    required this.studyPlans,
    required this.quizzes,
    required this.roadmaps,
    required this.summaries,
    required this.posts,
    required this.comments,
  });

  final AdminMember member;
  final bool marketingAlertEnabled;
  final bool isSubscribed;
  final List<AdminGoal> goals;
  final List<AdminStudy> studies;
  final List<AdminAiRecord> studyPlans;
  final List<AdminAiRecord> quizzes;
  final List<AdminAiRecord> roadmaps;
  final List<AdminAiRecord> summaries;
  final List<AdminCommunityActivity> posts;
  final List<AdminCommunityActivity> comments;
}

class AdminGoal {
  const AdminGoal({
    required this.certificateName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String certificateName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class AdminStudy {
  const AdminStudy({
    required this.name,
    required this.certificateName,
    required this.currentMemberCount,
    required this.maxMemberCount,
  });

  final String name;
  final String certificateName;
  final int currentMemberCount;
  final int maxMemberCount;
}

class AdminAiRecord {
  const AdminAiRecord(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

enum AdminCommunityActivityType { post, comment }

class AdminCommunityActivity {
  const AdminCommunityActivity({
    required this.id,
    required this.postId,
    required this.type,
    required this.content,
    required this.boardType,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final AdminCommunityActivityType type;
  final String content;
  final String boardType;
  final DateTime? createdAt;
}
