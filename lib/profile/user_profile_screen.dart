import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mypage/utils/study_time_formatter.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import 'user_activity_list_screen.dart';
import 'user_goal_certificate_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userUid;

  const UserProfileScreen({super.key, required this.userUid});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _ActivityItem extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ActivityItem({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 21, color: context.colors.pinkDeep),
              const SizedBox(height: 7),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserActivityStats {
  final int postCount;
  final int commentCount;
  final int friendCount;
  final int goalCount;
  final int studyCount;
  final int studySeconds;

  const _UserActivityStats({
    required this.postCount,
    required this.commentCount,
    required this.friendCount,
    required this.goalCount,
    required this.studyCount,
    required this.studySeconds,
  });
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _nickname = '불러오는 중...';
  String _bio = '';
  String _targetCertificateName = '등록된 목표 없음';
  String? _profileImageUrl;

  bool _isLoading = true;
  bool _hasError = false;

  String _friendStatus = 'NONE';
  String? _friendRequestSenderUid;
  bool _isFriendActionLoading = false;

  bool _isBlocked = false;
  bool _isBlockedByOther = false;
  bool _isBlockActionLoading = false;
  bool _isActivityPrivate = false;
  int _postCount = 0;
  int _commentCount = 0;
  int _friendCount = 0;
  int _goalCount = 0;
  int _studyCount = 0;
  int _studySeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // 프로필 정보를 읽기 전에 차단 관계를 먼저 확인합니다.
      await _loadBlockStatus();

      // 상대방이 나를 차단한 경우에는 닉네임, 자기소개,
      // 프로필 이미지, 대표 목표를 읽지 않고 접근을 종료합니다.
      if (_isBlockedByOther) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _hasError = false;
        });

        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userUid)
              .get();

      if (!userDocument.exists) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _hasError = true;
        });

        return;
      }

      final Map<String, dynamic>? userData = userDocument.data();

      String nickname = '닉네임 없음';
      String bio = '';
      String targetCertificateName = '등록된 목표 없음';
      String? profileImageUrl;

      if (userData != null) {
        final dynamic savedNickname = userData['nickname'];
        final dynamic savedBio = userData['bio'];
        final dynamic savedProfileImageUrl = userData['profileImageUrl'];

        if (savedNickname is String && savedNickname.trim().isNotEmpty) {
          nickname = savedNickname.trim();
        }

        if (savedBio is String && savedBio.trim().isNotEmpty) {
          bio = savedBio.trim();
        }

        if (savedProfileImageUrl is String &&
            savedProfileImageUrl.trim().isNotEmpty) {
          profileImageUrl = savedProfileImageUrl.trim();
        }
      }

      final QuerySnapshot<Map<String, dynamic>> mainGoalSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userUid)
              .collection('goals')
              .where('isMainGoal', isEqualTo: true)
              .limit(1)
              .get();

      if (mainGoalSnapshot.docs.isNotEmpty) {
        final Map<String, dynamic> mainGoalData = mainGoalSnapshot.docs.first
            .data();

        final String certificateName =
            (mainGoalData['certificateName'] as String? ?? '').trim();

        if (certificateName.isNotEmpty) {
          targetCertificateName = certificateName;
        }
      }

      if (!_isBlocked && !_isBlockedByOther) {
        await _loadFriendRelation();
      }

      final bool isOwner =
          FirebaseAuth.instance.currentUser?.uid == widget.userUid;
      final activityVisibility = userData?['profileActivityPublic'];
      final bool profileActivityPublic = activityVisibility is bool
          ? activityVisibility
          : true;

      const emptyStats = _UserActivityStats(
        postCount: 0,
        commentCount: 0,
        friendCount: 0,
        goalCount: 0,
        studyCount: 0,
        studySeconds: 0,
      );
      final bool canViewActivity = isOwner || profileActivityPublic;
      final _UserActivityStats activityStats = canViewActivity
          ? await _loadActivityStats(widget.userUid)
          : emptyStats;

      if (!mounted) {
        return;
      }

      setState(() {
        _nickname = nickname;
        _bio = bio;
        _targetCertificateName = targetCertificateName;
        _profileImageUrl = profileImageUrl;
        _postCount = activityStats.postCount;
        _commentCount = activityStats.commentCount;
        _friendCount = activityStats.friendCount;
        _goalCount = activityStats.goalCount;
        _studyCount = activityStats.studyCount;
        _studySeconds = activityStats.studySeconds;
        _isActivityPrivate = !canViewActivity;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용자 프로필을 불러오지 못했습니다.')));
    }
  }

  Future<_UserActivityStats> _loadActivityStats(String userUid) async {
    int postCount = 0;
    int commentCount = 0;
    int friendCount = 0;
    int goalCount = 0;
    int studyCount = 0;
    int studySeconds = 0;

    try {
      final QuerySnapshot<Map<String, dynamic>> postSnapshot =
          await FirebaseFirestore.instance
              .collection('posts')
              .where('writerUid', isEqualTo: userUid)
              .get();

      for (final document in postSnapshot.docs) {
        final data = document.data();
        final status = (data['postStatus'] as String? ?? 'NORMAL')
            .trim()
            .toUpperCase();
        final visibility = (data['visibility'] as String? ?? 'PUBLIC')
            .trim()
            .toUpperCase();

        if (status == 'NORMAL' &&
            visibility == 'PUBLIC' &&
            data['deletedAt'] == null) {
          postCount++;
        }
      }
    } catch (_) {}

    try {
      final QuerySnapshot<Map<String, dynamic>> publicPosts =
          await FirebaseFirestore.instance
              .collection('posts')
              .where('postStatus', isEqualTo: 'NORMAL')
              .where('visibility', isEqualTo: 'PUBLIC')
              .get();

      for (final postDocument in publicPosts.docs) {
        if (postDocument.data()['deletedAt'] != null) {
          continue;
        }

        final QuerySnapshot<Map<String, dynamic>> comments = await postDocument
            .reference
            .collection('comments')
            .where('commentStatus', isEqualTo: 'NORMAL')
            .get();

        for (final commentDocument in comments.docs) {
          final data = commentDocument.data();
          if (data['writerUid']?.toString() == userUid &&
              data['deletedAt'] == null) {
            commentCount++;
          }
        }
      }
    } catch (_) {}

    try {
      final List<QuerySnapshot<Map<String, dynamic>>> friendSnapshots =
          await Future.wait([
            FirebaseFirestore.instance
                .collection('friendRequests')
                .where('senderUid', isEqualTo: userUid)
                .get(),
            FirebaseFirestore.instance
                .collection('friendRequests')
                .where('receiverUid', isEqualTo: userUid)
                .get(),
          ]);

      final Set<String> acceptedRelationIds = {};
      for (final snapshot in friendSnapshots) {
        for (final document in snapshot.docs) {
          final status = (document.data()['status'] as String? ?? '')
              .toUpperCase();
          if (status == 'ACCEPTED') {
            acceptedRelationIds.add(document.id);
          }
        }
      }
      friendCount = acceptedRelationIds.length;
    } catch (_) {}

    try {
      final goals = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('goals')
          .get();
      goalCount = goals.docs.where((document) {
        final status = (document.data()['goalStatus']?.toString() ?? 'ACTIVE')
            .toUpperCase();
        return status != 'DELETED';
      }).length;
    } catch (_) {}

    try {
      final QuerySnapshot<Map<String, dynamic>> dailyLogs =
          await FirebaseFirestore.instance
              .collection('userStudyLogs')
              .doc(userUid)
              .collection('logs')
              .get();

      for (final document in dailyLogs.docs) {
        final data = document.data();
        studySeconds +=
            (data['totalSeconds'] as num?)?.toInt() ??
            ((data['totalMinutes'] as num?)?.toInt() ?? 0) * 60;
      }
    } catch (_) {}

    try {
      final QuerySnapshot<Map<String, dynamic>> groupSnapshot =
          await FirebaseFirestore.instance.collection('studyGroups').get();

      for (final groupDocument in groupSnapshot.docs) {
        final DocumentSnapshot<Map<String, dynamic>> memberDocument =
            await groupDocument.reference
                .collection('members')
                .doc(userUid)
                .get();
        final memberStatus =
            (memberDocument.data()?['status'] as String? ?? 'ACTIVE')
                .trim()
                .toUpperCase();

        if (memberDocument.exists && memberStatus == 'ACTIVE') {
          studyCount++;
        }

        final QuerySnapshot<Map<String, dynamic>> records = await groupDocument
            .reference
            .collection('studyRecords')
            .where('uid', isEqualTo: userUid)
            .get();

        for (final record in records.docs) {
          final data = record.data();
          studySeconds +=
              (data['studySeconds'] as num?)?.toInt() ??
              (data['elapsedSeconds'] as num?)?.toInt() ??
              ((data['studyMinutes'] as num?)?.toInt() ?? 0) * 60;
        }
      }
    } catch (_) {}

    return _UserActivityStats(
      postCount: postCount,
      commentCount: commentCount,
      friendCount: friendCount,
      goalCount: goalCount,
      studyCount: studyCount,
      studySeconds: studySeconds,
    );
  }

  String? _getFriendRequestId() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return null;
    }

    final List<String> userUids = [currentUid, widget.userUid];

    userUids.sort();

    return '${userUids[0]}_${userUids[1]}';
  }

  Future<void> _loadFriendRelation() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final String? requestId = _getFriendRequestId();

    if (currentUid == null ||
        requestId == null ||
        currentUid == widget.userUid) {
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> requestDocument =
          await FirebaseFirestore.instance
              .collection('friendRequests')
              .doc(requestId)
              .get();

      if (!mounted) {
        return;
      }

      if (!requestDocument.exists) {
        setState(() {
          _friendStatus = 'NONE';
          _friendRequestSenderUid = null;
        });

        return;
      }

      final Map<String, dynamic>? requestData = requestDocument.data();

      final String status = (requestData?['status'] as String? ?? 'NONE')
          .trim()
          .toUpperCase();

      final String? senderUid = requestData?['senderUid'] as String?;

      setState(() {
        _friendStatus = status;
        _friendRequestSenderUid = senderUid;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'NONE';
        _friendRequestSenderUid = null;
      });
    }
  }

  Future<void> _loadBlockStatus() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null || currentUid == widget.userUid) {
      return;
    }

    try {
      // 내가 상대방을 차단했는지 확인
      final DocumentSnapshot<Map<String, dynamic>> blockedByMeDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('blockedUsers')
              .doc(widget.userUid)
              .get();

      // 상대방이 나를 차단했는지 확인
      final DocumentSnapshot<Map<String, dynamic>> blockedByOtherDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userUid)
              .collection('blockedUsers')
              .doc(currentUid)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = blockedByMeDocument.exists;
        _isBlockedByOther = blockedByOtherDocument.exists;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = false;
        _isBlockedByOther = false;
      });
    }
  }

  bool get _isMyProfile {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    return currentUid == widget.userUid;
  }

  bool get _isReceivedPendingRequest {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return _friendStatus == 'PENDING' &&
        _friendRequestSenderUid != null &&
        _friendRequestSenderUid != currentUid;
  }

  Future<void> _onFriendButtonPressed() async {
    if (_isFriendActionLoading || _isBlocked || _isBlockedByOther) {
      return;
    }

    if (_friendStatus == 'ACCEPTED') {
      return;
    }

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    if (_friendStatus == 'PENDING') {
      if (_friendRequestSenderUid == currentUid) {
        await _cancelFriendRequest();
      }

      return;
    }

    await _sendFriendRequest();
  }

  Future<void> _sendFriendRequest() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final String? requestId = _getFriendRequestId();

    if (currentUid == null ||
        requestId == null ||
        _isBlocked ||
        _isBlockedByOther) {
      return;
    }

    setState(() {
      _isFriendActionLoading = true;
    });

    try {
      // 화면에 표시된 차단 상태만 믿지 않고,
      // 실제 친구 요청 저장 직전에 차단 관계를 다시 확인합니다.
      await _loadBlockStatus();

      if (_isBlocked || _isBlockedByOther) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isFriendActionLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단 관계에 있는 사용자에게는 친구 요청을 보낼 수 없습니다.')),
        );

        return;
      }

      final DocumentReference<Map<String, dynamic>> requestReference =
          FirebaseFirestore.instance
              .collection('friendRequests')
              .doc(requestId);

      final DocumentSnapshot<Map<String, dynamic>> existingRequest =
          await requestReference.get();

      if (existingRequest.exists) {
        final String existingStatus =
            (existingRequest.data()?['status'] as String? ?? '')
                .trim()
                .toUpperCase();

        if (existingStatus == 'PENDING' || existingStatus == 'ACCEPTED') {
          await _loadFriendRelation();

          if (!mounted) {
            return;
          }

          setState(() {
            _isFriendActionLoading = false;
          });

          return;
        }
      }

      await requestReference.set({
        'senderUid': currentUid,
        'receiverUid': widget.userUid,
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'PENDING';
        _friendRequestSenderUid = currentUid;
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_nickname님에게 친구 요청을 보냈습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 보내지 못했습니다.')));
    }
  }

  Future<void> _acceptReceivedFriendRequest() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final String? requestId = _getFriendRequestId();

    if (currentUid == null ||
        requestId == null ||
        !_isReceivedPendingRequest ||
        _isFriendActionLoading) {
      return;
    }

    setState(() {
      _isFriendActionLoading = true;
    });

    try {
      await _loadBlockStatus();

      if (_isBlocked || _isBlockedByOther) {
        if (!mounted) {
          return;
        }

        await FirebaseFirestore.instance
            .collection('friendRequests')
            .doc(requestId)
            .delete();

        if (!mounted) {
          return;
        }

        setState(() {
          _friendStatus = 'NONE';
          _friendRequestSenderUid = null;
          _isFriendActionLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단 관계에 있는 사용자의 친구 요청은 수락할 수 없습니다.')),
        );

        return;
      }

      final DocumentReference<Map<String, dynamic>> requestReference =
          FirebaseFirestore.instance
              .collection('friendRequests')
              .doc(requestId);

      final DocumentSnapshot<Map<String, dynamic>> requestDocument =
          await requestReference.get();

      final Map<String, dynamic>? requestData = requestDocument.data();
      final String status = (requestData?['status'] as String? ?? '')
          .trim()
          .toUpperCase();
      final String senderUid = (requestData?['senderUid'] as String? ?? '')
          .trim();
      final String receiverUid = (requestData?['receiverUid'] as String? ?? '')
          .trim();

      if (!requestDocument.exists ||
          status != 'PENDING' ||
          senderUid != widget.userUid ||
          receiverUid != currentUid) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isFriendActionLoading = false;
        });

        await _loadFriendRelation();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 처리되었거나 확인할 수 없는 친구 요청입니다.')),
        );

        return;
      }

      await requestReference.update({
        'status': 'ACCEPTED',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'ACCEPTED';
        _friendRequestSenderUid = widget.userUid;
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_nickname님과 친구가 되었습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 수락하지 못했습니다.')));
    }
  }

  Future<void> _rejectReceivedFriendRequest() async {
    final String? requestId = _getFriendRequestId();

    if (requestId == null ||
        !_isReceivedPendingRequest ||
        _isFriendActionLoading) {
      return;
    }

    final bool? shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '친구 요청 거절',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('$_nickname님의 친구 요청을 거절하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xFF9AA0AC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '거절',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      return;
    }

    setState(() {
      _isFriendActionLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'NONE';
        _friendRequestSenderUid = null;
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 거절했습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 거절하지 못했습니다.')));
    }
  }

  Future<void> _cancelFriendRequest() async {
    final String? requestId = _getFriendRequestId();

    if (requestId == null) {
      return;
    }

    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '친구 요청 취소',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('$_nickname님에게 보낸 친구 요청을 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '아니요',
                style: TextStyle(color: Color(0xFF9AA0AC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '요청 취소',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    setState(() {
      _isFriendActionLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'NONE';
        _friendRequestSenderUid = null;
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 취소했습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구 요청을 취소하지 못했습니다.')));
    }
  }

  Future<void> _deleteFriend() async {
    final String? requestId = _getFriendRequestId();

    if (requestId == null ||
        _friendStatus != 'ACCEPTED' ||
        _isFriendActionLoading) {
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '친구 삭제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('$_nickname님을 친구 목록에서 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xFF9AA0AC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isFriendActionLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _friendStatus = 'NONE';
        _friendRequestSenderUid = null;
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_nickname님을 친구 목록에서 삭제했습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('친구를 삭제하지 못했습니다.')));
    }
  }

  Future<void> _showBlockReasonDialog() async {
    String selectedReason = 'UNWANTED';

    final String? reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                '$_nickname님 차단',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '차단 사유를 선택해주세요.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666A73)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    value: 'SPAM',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFF0788F),
                    title: const Text('스팸 또는 광고'),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'HARASSMENT',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFF0788F),
                    title: const Text('괴롭힘 또는 불쾌한 행동'),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'UNWANTED',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFF0788F),
                    title: const Text('원하지 않는 사용자'),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    value: 'OTHER',
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFF0788F),
                    title: const Text('기타'),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Color(0xFF9AA0AC)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, selectedReason);
                  },
                  child: const Text(
                    '차단',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (reason == null) {
      return;
    }

    await _blockUser(reason);
  }

  Future<void> _blockUser(String reason) async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final String? requestId = _getFriendRequestId();

    if (currentUid == null || currentUid == widget.userUid) {
      return;
    }

    setState(() {
      _isBlockActionLoading = true;
    });

    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      final DocumentReference<Map<String, dynamic>> blockedReference =
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('blockedUsers')
              .doc(widget.userUid);

      batch.set(blockedReference, {
        'createdAt': FieldValue.serverTimestamp(),
        'reason': reason,
        'source': 'PROFILE',
      });

      if (requestId != null) {
        final DocumentReference<Map<String, dynamic>> relationReference =
            FirebaseFirestore.instance
                .collection('friendRequests')
                .doc(requestId);

        batch.delete(relationReference);
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = true;
        _friendStatus = 'NONE';
        _friendRequestSenderUid = null;
        _isBlockActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$_nickname님을 차단했습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBlockActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용자를 차단하지 못했습니다.')));
    }
  }

  Future<void> _unblockUser() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return;
    }

    final bool? shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '차단 해제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text('$_nickname님의 차단을 해제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xFF9AA0AC)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                '차단 해제',
                style: TextStyle(
                  color: Color(0xFFF0788F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldUnblock != true) {
      return;
    }

    setState(() {
      _isBlockActionLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(widget.userUid)
          .delete();

      if (!mounted) {
        return;
      }

      setState(() {
        _isBlocked = false;
        _isBlockActionLoading = false;
      });

      await _loadFriendRelation();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제했습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBlockActionLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제하지 못했습니다.')));
    }
  }

  String _getFriendButtonText() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (_isBlockActionLoading || _isFriendActionLoading) {
      return '처리 중...';
    }

    if (_isBlocked) {
      return '차단한 사용자입니다';
    }

    if (_isBlockedByOther) {
      return '친구 요청을 보낼 수 없습니다';
    }

    if (_friendStatus == 'ACCEPTED') {
      return '친구';
    }

    if (_friendStatus == 'PENDING') {
      if (_friendRequestSenderUid == currentUid) {
        return '요청 취소';
      }

      return '친구 요청 수락';
    }

    return '친구 추가';
  }

  AppButtonType _getFriendButtonType() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (_isBlocked || _isBlockedByOther || _friendStatus == 'ACCEPTED') {
      return AppButtonType.gray;
    }

    if (_friendStatus == 'PENDING' && _friendRequestSenderUid == currentUid) {
      return AppButtonType.outlinePink;
    }

    return AppButtonType.primaryPink;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: _isLoading || _hasError || _isBlockedByOther
            ? '프로필'
            : '$_nickname 프로필',
      ),
      body: AppMainBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(message: '프로필을 불러오는 중입니다.');
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_off_outlined,
                size: 64,
                color: Color(0xFFB5B7BE),
              ),
              const SizedBox(height: 16),
              const Text(
                '사용자 프로필을 불러올 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF44474E),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: AppButton(
                  text: '다시 시도',
                  height: 48,
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                    });

                    _loadUserProfile();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isBlockedByOther) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: Color(0xFFB5B7BE),
              ),
              SizedBox(height: 16),
              Text(
                '이 사용자의 프로필을 확인할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF44474E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildActivityCard(),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: context.colors.pinkDeep),
              const SizedBox(width: 9),
              Text(
                '활동 기록',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isActivityPrivate)
            SizedBox(
              height: 76,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '비공개',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 16) / 3;

                return Wrap(
                  spacing: 8,
                  runSpacing: 18,
                  children: [
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.timer_outlined,
                      label: '학습 시간',
                      value: formatStudyTime(_studySeconds),
                    ),
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.workspace_premium_outlined,
                      label: '목표 자격증',
                      value: '$_goalCount개',
                      onTap: _openGoalCertificates,
                    ),
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.people_outline_rounded,
                      label: '친구',
                      value: '$_friendCount명',
                      onTap: () => _openActivityList(UserActivityType.friends),
                    ),
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.article_outlined,
                      label: '쓴 글',
                      value: '$_postCount개',
                      onTap: () => _openActivityList(UserActivityType.posts),
                    ),
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '댓글',
                      value: '$_commentCount개',
                      onTap: () => _openActivityList(UserActivityType.comments),
                    ),
                    _ActivityItem(
                      width: itemWidth,
                      icon: Icons.groups_outlined,
                      label: '참여 스터디',
                      value: '$_studyCount개',
                      onTap: () => _openActivityList(UserActivityType.studies),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _openGoalCertificates() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserGoalCertificateListScreen(
          userUid: widget.userUid,
          nickname: _nickname,
        ),
      ),
    );
  }

  void _openActivityList(UserActivityType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserActivityListScreen(
          userUid: widget.userUid,
          nickname: _nickname,
          type: type,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF8FA), Color(0xFFFFF2F6)],
        ),
        border: Border.all(color: const Color(0xFFFFE8EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
            child: Column(
              children: [
                _buildProfileImage(),
                const SizedBox(height: 18),
                Text(
                  _nickname,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _bio.isEmpty ? '자기소개가 없습니다.' : _bio,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF777B84),
                  ),
                ),
                const SizedBox(height: 18),
                _buildTargetCertificateChip(),
                const SizedBox(height: 24),
                if (_isMyProfile)
                  AppButton(
                    text: '내 프로필입니다',
                    type: AppButtonType.gray,
                    onPressed: null,
                  )
                else if (_isReceivedPendingRequest)
                  Column(
                    children: [
                      AppButton(
                        text: _isFriendActionLoading ? '처리 중...' : '친구 요청 수락',
                        type: AppButtonType.primaryPink,
                        onPressed:
                            _isFriendActionLoading ||
                                _isBlockActionLoading ||
                                _isBlocked ||
                                _isBlockedByOther
                            ? null
                            : _acceptReceivedFriendRequest,
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        text: '거절',
                        type: AppButtonType.gray,
                        onPressed:
                            _isFriendActionLoading ||
                                _isBlockActionLoading ||
                                _isBlocked ||
                                _isBlockedByOther
                            ? null
                            : _rejectReceivedFriendRequest,
                      ),
                    ],
                  )
                else
                  AppButton(
                    text: _getFriendButtonText(),
                    type: _getFriendButtonType(),
                    onPressed:
                        _isFriendActionLoading ||
                            _isBlockActionLoading ||
                            _friendStatus == 'ACCEPTED' ||
                            _isBlocked ||
                            _isBlockedByOther
                        ? null
                        : _onFriendButtonPressed,
                  ),
              ],
            ),
          ),
          if (!_isMyProfile)
            Positioned(top: 12, right: 12, child: _buildUserMenuButton()),
        ],
      ),
    );
  }

  Widget _buildUserMenuButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: const Color(0xFFFFDCE4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(alpha: 0.10),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        tooltip: '사용자 메뉴',
        padding: EdgeInsets.zero,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        position: PopupMenuPosition.under,
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 22,
          color: Color(0xFF777B84),
        ),
        onSelected: (value) {
          if (value == 'block') {
            _showBlockReasonDialog();
          }

          if (value == 'unblock') {
            _unblockUser();
          }

          if (value == 'deleteFriend') {
            _deleteFriend();
          }
        },
        itemBuilder: (context) {
          if (_isBlocked) {
            return const [
              PopupMenuItem<String>(
                value: 'unblock',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 20,
                      color: Color(0xFFF0788F),
                    ),
                    SizedBox(width: 10),
                    Text('차단 해제'),
                  ],
                ),
              ),
            ];
          }

          final List<PopupMenuEntry<String>> menuItems = [];

          if (_friendStatus == 'ACCEPTED') {
            menuItems.add(
              const PopupMenuItem<String>(
                value: 'deleteFriend',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_remove_outlined,
                      size: 20,
                      color: Color(0xFF666A73),
                    ),
                    SizedBox(width: 10),
                    Text('친구 삭제'),
                  ],
                ),
              ),
            );
          }

          menuItems.add(
            const PopupMenuItem<String>(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block_outlined, size: 20, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('사용자 차단'),
                ],
              ),
            ),
          );

          return menuItems;
        },
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFFDCE4), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipOval(
        child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
            ? Image.network(
                _profileImageUrl!,
                width: 94,
                height: 94,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultProfileImage();
                },
              )
            : _buildDefaultProfileImage(),
      ),
    );
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE8EE), Color(0xFFFFF6F8)],
        ),
      ),
      child: const Icon(Icons.person, size: 58, color: Color(0xFFF0788F)),
    );
  }

  Widget _buildTargetCertificateChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD5DF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.track_changes_outlined,
            size: 20,
            color: Color(0xFFF0788F),
          ),
          const SizedBox(width: 8),
          const Text(
            '목표 자격증',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF44474E),
            ),
          ),
          const SizedBox(width: 5),
          const Text('·', style: TextStyle(color: Color(0xFFB5B7BE))),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _targetCertificateName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF0788F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
