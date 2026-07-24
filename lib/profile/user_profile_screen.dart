import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class UserProfileScreen extends StatefulWidget {
  final String userUid;

  const UserProfileScreen({
    super.key,
    required this.userUid,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
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
          .where(
        'isMainGoal',
        isEqualTo: true,
      )
          .limit(1)
          .get();

      if (mainGoalSnapshot.docs.isNotEmpty) {
        final Map<String, dynamic> mainGoalData =
        mainGoalSnapshot.docs.first.data();

        final String certificateName =
        (mainGoalData['certificateName'] as String? ?? '').trim();

        if (certificateName.isNotEmpty) {
          targetCertificateName = certificateName;
        }
      }

      await _loadBlockStatus();

      if (!_isBlocked) {
        await _loadFriendRelation();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _nickname = nickname;
        _bio = bio;
        _targetCertificateName = targetCertificateName;
        _profileImageUrl = profileImageUrl;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 프로필을 불러오지 못했습니다.'),
        ),
      );
    }
  }

  String? _getFriendRequestId() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return null;
    }

    final List<String> userUids = [
      currentUid,
      widget.userUid,
    ];

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

      final String status =
      (requestData?['status'] as String? ?? 'NONE')
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

  Future<void> _onFriendButtonPressed() async {
    if (_isFriendActionLoading || _isBlocked || _isBlockedByOther) {
      return;
    }

    if (_friendStatus == 'ACCEPTED') {
      return;
    }

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
        ),
      );
      return;
    }

    if (_friendStatus == 'PENDING') {
      if (_friendRequestSenderUid == currentUid) {
        await _cancelFriendRequest();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '이 사용자가 보낸 친구 요청이 있습니다. 친구 화면에서 확인해주세요.',
            ),
          ),
        );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_nickname님에게 친구 요청을 보냈습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구 요청을 보내지 못했습니다.'),
        ),
      );
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '$_nickname님에게 보낸 친구 요청을 취소하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '아니요',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구 요청을 취소했습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isFriendActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구 요청을 취소하지 못했습니다.'),
        ),
      );
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
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '차단 사유를 선택해주세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666A73),
                      ),
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
                    style: TextStyle(
                      color: Color(0xFF9AA0AC),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      selectedReason,
                    );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_nickname님을 차단했습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBlockActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자를 차단하지 못했습니다.'),
        ),
      );
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '$_nickname님의 차단을 해제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Color(0xFF9AA0AC),
                ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('차단을 해제했습니다.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBlockActionLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('차단을 해제하지 못했습니다.'),
        ),
      );
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

      return '받은 요청 확인';
    }

    return '친구 추가';
  }

  AppButtonType _getFriendButtonType() {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (_isBlocked ||
        _isBlockedByOther ||
        _friendStatus == 'ACCEPTED') {
      return AppButtonType.gray;
    }

    if (_friendStatus == 'PENDING' &&
        _friendRequestSenderUid == currentUid) {
      return AppButtonType.outlinePink;
    }

    return AppButtonType.primaryPink;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '프로필',
      ),
      body: AppMainBackground(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF0788F),
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        110,
      ),
      child: _buildProfileCard(),
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
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF8FA),
            Color(0xFFFFF2F6),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFE8EE),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(
              alpha: 0.13,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              26,
            ),
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
                else
                  AppButton(
                    text: _getFriendButtonText(),
                    type: _getFriendButtonType(),
                    onPressed: _isFriendActionLoading ||
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
            Positioned(
              top: 12,
              right: 12,
              child: _buildUserMenuButton(),
            ),
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
        color: Colors.white.withValues(
          alpha: 0.9,
        ),
        border: Border.all(
          color: const Color(0xFFFFDCE4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(
              alpha: 0.10,
            ),
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

          return const [
            PopupMenuItem<String>(
              value: 'block',
              child: Row(
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 10),
                  Text('사용자 차단'),
                ],
              ),
            ),
          ];
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
        border: Border.all(
          color: const Color(0xFFFFDCE4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(
              alpha: 0.18,
            ),
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
          errorBuilder: (
              context,
              error,
              stackTrace,
              ) {
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
          colors: [
            Color(0xFFFFE8EE),
            Color(0xFFFFF6F8),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        size: 58,
        color: Color(0xFFF0788F),
      ),
    );
  }

  Widget _buildTargetCertificateChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.82,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD5DF),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0788F).withValues(
              alpha: 0.08,
            ),
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
          const Text(
            '·',
            style: TextStyle(
              color: Color(0xFFB5B7BE),
            ),
          ),
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
