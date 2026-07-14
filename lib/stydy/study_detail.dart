import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import 'study_chat.dart';
import 'study_edit.dart';
import 'study_quiz.dart';

class StudyDetailPage extends StatelessWidget {
  final String studyId;
  final Map<String, dynamic> studyData;

  const StudyDetailPage({
    super.key,
    required this.studyId,
    required this.studyData,
  });

  /// Firestore 숫자 가져오기
  int _getInt(
      Map<String, dynamic> data,
      String fieldName,
      ) {
    final value = data[fieldName];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  /// 현재 로그인한 사용자가 방장인지 확인
  bool _isOwner(Map<String, dynamic> data) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    final ownerUid =
    data['ownerUid']?.toString();

    return currentUserUid != null &&
        currentUserUid == ownerUid;
  }

  /// 공부시간 표시
  String _formatStudyTime(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0분';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$minutes분';
    }

    if (minutes == 0) {
      return '$hours시간';
    }

    return '$hours시간 $minutes분';
  }

  /// 안내 메시지 표시
  void _showMessage(
      BuildContext context,
      String message,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  /// 중복되지 않는 초대 문서 ID 생성
  String _createInviteDocumentId(
      String target,
      ) {
    final value = '$studyId|$target';

    return base64Url
        .encode(
      utf8.encode(value),
    )
        .replaceAll('=', '');
  }

  /// 초대 정보 저장
  Future<void> _saveInvite({
    required String groupName,
    required String target,
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final normalizedTarget =
    target.trim().toLowerCase();

    final bool isEmail =
    normalizedTarget.contains('@');

    final inviteDocumentId =
    _createInviteDocumentId(
      normalizedTarget,
    );

    final inviteDocument =
    FirebaseFirestore.instance
        .collection('studyGroupInvites')
        .doc(inviteDocumentId);

    await inviteDocument.set(
      {
        'groupId': studyId,
        'groupName': groupName,

        'inviterUid': currentUser.uid,
        'inviterNickname':
        currentUser.displayName ?? '사용자',

        'inviteeUid': '',

        'targetEmail':
        isEmail ? normalizedTarget : '',

        'targetId':
        isEmail ? '' : normalizedTarget,

        'inviteType':
        isEmail ? 'EMAIL' : 'ID',

        'status': 'PENDING',

        'createdAt':
        FieldValue.serverTimestamp(),

        'updatedAt':
        FieldValue.serverTimestamp(),

        // 초대 유효기간 7일
        'expiredAt': Timestamp.fromDate(
          DateTime.now().add(
            const Duration(days: 7),
          ),
        ),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  /// 기존 스터디에 방장 멤버 정보가 없으면 생성
  Future<void> _ensureOwnerMember(
      Map<String, dynamic> currentStudyData,
      ) async {
    final ownerUid =
        currentStudyData['ownerUid']
            ?.toString() ??
            '';

    if (ownerUid.isEmpty) {
      return;
    }

    final ownerNickname =
        currentStudyData['ownerNickname']
            ?.toString() ??
            '방장';

    final ownerMemberDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId)
        .collection('members')
        .doc(ownerUid);

    final ownerMemberSnapshot =
    await ownerMemberDocument.get();

    if (ownerMemberSnapshot.exists) {
      return;
    }

    await ownerMemberDocument.set({
      'uid': ownerUid,
      'nickname': ownerNickname,
      'role': 'OWNER',
      'status': 'ACTIVE',
      'totalStudyMinutes': 0,

      'joinedAt':
      currentStudyData['createdAt'] ??
          FieldValue.serverTimestamp(),

      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  /// 스터디 수정 화면으로 이동
  Future<void> _openEditPage(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudyEditPage(
          studyId: studyId,
          studyData: currentStudyData,
        ),
      ),
    );
  }

  /// 그룹원 추방
  Future<void> _kickMember({
    required String memberUid,
  }) async {
    final groupDocument =
    FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);

    final memberDocument =
    groupDocument
        .collection('members')
        .doc(memberUid);

    await FirebaseFirestore.instance
        .runTransaction(
          (transaction) async {
        final groupSnapshot =
        await transaction.get(
          groupDocument,
        );

        final memberSnapshot =
        await transaction.get(
          memberDocument,
        );

        if (!groupSnapshot.exists ||
            !memberSnapshot.exists) {
          throw Exception(
            '그룹원 정보를 찾을 수 없습니다.',
          );
        }

        final groupData =
            groupSnapshot.data() ?? {};

        final memberData =
            memberSnapshot.data() ?? {};

        final role =
            memberData['role']?.toString() ??
                'MEMBER';

        final status =
            memberData['status']?.toString() ??
                'ACTIVE';

        if (role == 'OWNER') {
          throw Exception(
            '방장은 추방할 수 없습니다.',
          );
        }

        if (status != 'ACTIVE') {
          throw Exception(
            '이미 활동 중인 그룹원이 아닙니다.',
          );
        }

        final currentMemberCount =
        _getInt(
          groupData,
          'currentMemberCount',
        );

        final newMemberCount =
        currentMemberCount > 1
            ? currentMemberCount - 1
            : 1;

        final currentStatus =
            groupData['status']?.toString() ??
                'RECRUITING';

        transaction.update(
          memberDocument,
          {
            'status': 'BANNED',
            'bannedAt':
            FieldValue.serverTimestamp(),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          groupDocument,
          {
            'currentMemberCount':
            newMemberCount,

            // 완료된 스터디가 아니면 다시 모집 중으로 변경
            'status':
            currentStatus == 'COMPLETED'
                ? 'COMPLETED'
                : 'RECRUITING',

            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  /// 그룹원 추방 확인창
  void _showKickMemberDialog({
    required BuildContext context,
    required String memberUid,
    required String nickname,
  }) {
    bool isProcessing = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> kickMember() async {
              setDialogState(() {
                isProcessing = true;
              });

              try {
                await _kickMember(
                  memberUid: memberUid,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  context,
                  '$nickname 님을 스터디에서 추방했습니다.',
                );
              } catch (error) {
                debugPrint(
                  '그룹원 추방 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isProcessing = false;
                });

                _showMessage(
                  context,
                  '그룹원을 추방하지 못했습니다.',
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons
                        .person_remove_outlined,
                    color: Colors.red,
                  ),
                  SizedBox(width: 10),
                  Text('그룹원 추방'),
                ],
              ),
              content: Text(
                '$nickname 님을 스터디에서 추방하시겠습니까?\n\n'
                    '추방된 사용자는 이 스터디에 참여할 수 없습니다.',
                style: const TextStyle(
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : kickMember,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('추방'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 그룹원 관리 화면
  Future<void> _openMemberManagement(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    try {
      await _ensureOwnerMember(
        currentStudyData,
      );
    } catch (error) {
      debugPrint(
        '방장 멤버 정보 생성 오류: $error',
      );
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.50,
          maxChildSize: 0.93,
          expand: false,
          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9FD),
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 11),

                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFD8D5DE,
                      ),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      18,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF0ECFF,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .manage_accounts_outlined,
                            color: Color(
                              0xFF8068D8,
                            ),
                          ),
                        ),

                        const SizedBox(width: 13),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                '그룹원 관리',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '활동 중인 그룹원을 확인하고 관리합니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(
                                    0xFF858994,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream:
                      FirebaseFirestore.instance
                          .collection(
                        'studyGroups',
                      )
                          .doc(studyId)
                          .collection('members')
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          debugPrint(
                            '그룹원 조회 오류: '
                                '${snapshot.error}',
                          );

                          return const Center(
                            child: Text(
                              '그룹원 목록을 불러오지 못했습니다.',
                            ),
                          );
                        }

                        final memberList =
                            snapshot.data?.docs
                                .where(
                                  (document) {
                                final status =
                                document
                                    .data()[
                                'status']
                                    ?.toString();

                                return status ==
                                    'ACTIVE';
                              },
                            )
                                .toList() ??
                                [];

                        // 방장이 가장 위에 표시되도록 정렬
                        memberList.sort(
                              (a, b) {
                            final aRole =
                                a.data()['role']
                                    ?.toString() ??
                                    'MEMBER';

                            final bRole =
                                b.data()['role']
                                    ?.toString() ??
                                    'MEMBER';

                            if (aRole == 'OWNER' &&
                                bRole != 'OWNER') {
                              return -1;
                            }

                            if (aRole != 'OWNER' &&
                                bRole == 'OWNER') {
                              return 1;
                            }

                            final aNickname =
                                a.data()['nickname']
                                    ?.toString() ??
                                    '';

                            final bNickname =
                                b.data()['nickname']
                                    ?.toString() ??
                                    '';

                            return aNickname
                                .compareTo(
                              bNickname,
                            );
                          },
                        );

                        if (memberList.isEmpty) {
                          return const Center(
                            child: Text(
                              '등록된 그룹원이 없습니다.',
                            ),
                          );
                        }

                        return ListView.builder(
                          controller:
                          scrollController,
                          padding:
                          const EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            30,
                          ),
                          itemCount:
                          memberList.length,
                          itemBuilder:
                              (context, index) {
                            final memberDocument =
                            memberList[index];

                            final memberData =
                            memberDocument.data();

                            final nickname =
                                memberData['nickname']
                                    ?.toString() ??
                                    '스터디원';

                            final role =
                                memberData['role']
                                    ?.toString() ??
                                    'MEMBER';

                            final totalStudyMinutes =
                            _getInt(
                              memberData,
                              'totalStudyMinutes',
                            );

                            final isOwner =
                                role == 'OWNER';

                            return Container(
                              margin:
                              const EdgeInsets.only(
                                bottom: 11,
                              ),
                              padding:
                              const EdgeInsets.all(
                                15,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(
                                  18,
                                ),
                                border: Border.all(
                                  color: const Color(
                                    0xFFECEAF0,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    alignment:
                                    Alignment.center,
                                    decoration:
                                    const BoxDecoration(
                                      color: Color(
                                        0xFFF0ECFF,
                                      ),
                                      shape:
                                      BoxShape.circle,
                                    ),
                                    child: Text(
                                      nickname.isNotEmpty
                                          ? nickname[0]
                                          .toUpperCase()
                                          : '?',
                                      style:
                                      const TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                        FontWeight
                                            .bold,
                                        color: Color(
                                          0xFF6F58C9,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 13,
                                  ),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                nickname,
                                                overflow:
                                                TextOverflow
                                                    .ellipsis,
                                                style:
                                                const TextStyle(
                                                  fontSize:
                                                  15,
                                                  fontWeight:
                                                  FontWeight
                                                      .bold,
                                                ),
                                              ),
                                            ),

                                            if (isOwner) ...[
                                              const SizedBox(
                                                width: 7,
                                              ),
                                              Container(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal:
                                                  8,
                                                  vertical:
                                                  3,
                                                ),
                                                decoration:
                                                BoxDecoration(
                                                  color:
                                                  const Color(
                                                    0xFFFFE7EE,
                                                  ),
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                    11,
                                                  ),
                                                ),
                                                child:
                                                const Text(
                                                  '방장',
                                                  style:
                                                  TextStyle(
                                                    fontSize:
                                                    10,
                                                    color:
                                                    Color(
                                                      0xFFD85F82,
                                                    ),
                                                    fontWeight:
                                                    FontWeight
                                                        .w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        const SizedBox(
                                          height: 5,
                                        ),

                                        Text(
                                          '누적 공부시간 '
                                              '${_formatStudyTime(totalStudyMinutes)}',
                                          style:
                                          const TextStyle(
                                            fontSize: 11,
                                            color: Color(
                                              0xFF92969F,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (!isOwner)
                                    OutlinedButton(
                                      onPressed: () {
                                        _showKickMemberDialog(
                                          context:
                                          context,
                                          memberUid:
                                          memberDocument
                                              .id,
                                          nickname:
                                          nickname,
                                        );
                                      },
                                      style:
                                      OutlinedButton
                                          .styleFrom(
                                        foregroundColor:
                                        Colors.red,
                                        side:
                                        const BorderSide(
                                          color: Color(
                                            0xFFE99AA4,
                                          ),
                                        ),
                                        minimumSize:
                                        const Size(
                                          64,
                                          38,
                                        ),
                                      ),
                                      child:
                                      const Text(
                                        '추방',
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 공부시간 순위 표시
  Future<void> _openStudyRanking(
      BuildContext context,
      Map<String, dynamic> currentStudyData,
      ) async {
    try {
      await _ensureOwnerMember(
        currentStudyData,
      );
    } catch (error) {
      debugPrint(
        '방장 멤버 정보 생성 오류: $error',
      );
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9FD),
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 11),

                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFD8D5DE,
                      ),
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      20,
                      18,
                      12,
                      14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF0ECFF,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .emoji_events_outlined,
                            color: Color(
                              0xFF8068D8,
                            ),
                          ),
                        ),

                        const SizedBox(width: 13),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                '공부시간 순위',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '전체 누적 공부시간 기준',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(
                                    0xFF858994,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              bottomSheetContext,
                            );
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<
                            Map<String, dynamic>>>(
                      stream:
                      FirebaseFirestore.instance
                          .collection(
                        'studyGroups',
                      )
                          .doc(studyId)
                          .collection('members')
                          .snapshots(),
                      builder:
                          (context, snapshot) {
                        if (snapshot
                            .connectionState ==
                            ConnectionState
                                .waiting) {
                          return const Center(
                            child:
                            CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              '공부시간 순위를 불러오지 못했습니다.',
                            ),
                          );
                        }

                        final memberList =
                            snapshot.data?.docs
                                .where(
                                  (document) {
                                final status =
                                document
                                    .data()[
                                'status']
                                    ?.toString();

                                return status ==
                                    'ACTIVE';
                              },
                            )
                                .toList() ??
                                [];

                        memberList.sort(
                              (a, b) {
                            final aMinutes =
                            _getInt(
                              a.data(),
                              'totalStudyMinutes',
                            );

                            final bMinutes =
                            _getInt(
                              b.data(),
                              'totalStudyMinutes',
                            );

                            return bMinutes
                                .compareTo(
                              aMinutes,
                            );
                          },
                        );

                        if (memberList.isEmpty) {
                          return const Center(
                            child: Text(
                              '표시할 공부시간이 없습니다.',
                            ),
                          );
                        }

                        return ListView.builder(
                          controller:
                          scrollController,
                          padding:
                          const EdgeInsets.fromLTRB(
                            18,
                            16,
                            18,
                            30,
                          ),
                          itemCount:
                          memberList.length,
                          itemBuilder:
                              (context, index) {
                            final memberDocument =
                            memberList[index];

                            return _buildRankingItem(
                              rank: index + 1,
                              memberUid:
                              memberDocument.id,
                              memberData:
                              memberDocument
                                  .data(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 공부시간 순위 한 줄
  Widget _buildRankingItem({
    required int rank,
    required String memberUid,
    required Map<String, dynamic> memberData,
  }) {
    final currentUserUid =
        FirebaseAuth.instance.currentUser?.uid;

    final isCurrentUser =
        currentUserUid == memberUid;

    final nickname =
        memberData['nickname']?.toString() ??
            '스터디원';

    final role =
        memberData['role']?.toString() ??
            'MEMBER';

    final totalStudyMinutes =
    _getInt(
      memberData,
      'totalStudyMinutes',
    );

    Color rankBackgroundColor;
    Color rankTextColor;

    if (rank == 1) {
      rankBackgroundColor =
      const Color(0xFFFFF3CF);
      rankTextColor =
      const Color(0xFFC58B18);
    } else if (rank == 2) {
      rankBackgroundColor =
      const Color(0xFFF0F1F4);
      rankTextColor =
      const Color(0xFF7D838E);
    } else if (rank == 3) {
      rankBackgroundColor =
      const Color(0xFFF8E7DC);
      rankTextColor =
      const Color(0xFFB8754C);
    } else {
      rankBackgroundColor =
      const Color(0xFFF0ECFF);
      rankTextColor =
      const Color(0xFF6F58C9);
    }

    return Container(
      margin:
      const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFFF6F2FF)
            : Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFFB7A8EF)
              : const Color(0xFFECEAF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: rank <= 3
                ? Icon(
              Icons
                  .emoji_events_rounded,
              size: 21,
              color: rankTextColor,
            )
                : Text(
              '$rank',
              style: TextStyle(
                color: rankTextColor,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),

                    if (role == 'OWNER') ...[
                      const SizedBox(width: 7),
                      _buildMiniBadge(
                        text: '방장',
                        backgroundColor:
                        const Color(
                          0xFFFFE7EE,
                        ),
                        textColor:
                        const Color(
                          0xFFD85F82,
                        ),
                      ),
                    ],

                    if (isCurrentUser) ...[
                      const SizedBox(width: 7),
                      _buildMiniBadge(
                        text: '나',
                        backgroundColor:
                        const Color(
                          0xFFE9E4FF,
                        ),
                        textColor:
                        const Color(
                          0xFF6F58C9,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 5),

                const Text(
                  '누적 공부시간',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(
                      0xFF92969F,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            _formatStudyTime(
              totalStudyMinutes,
            ),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(
                0xFF6C54C8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 작은 미니 배지
  Widget _buildMiniBadge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(11),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 그룹원 초대 창
  void _showInviteDialog(
      BuildContext context,
      String groupName,
      ) {
    final TextEditingController
    inviteController =
    TextEditingController();

    bool isSending = false;
    String? inputError;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> sendInvite() async {
              final target =
              inviteController.text.trim();

              if (target.isEmpty) {
                setDialogState(() {
                  inputError =
                  '아이디 또는 이메일을 입력해주세요.';
                });

                return;
              }

              if (target.length < 2) {
                setDialogState(() {
                  inputError =
                  '2글자 이상 입력해주세요.';
                });

                return;
              }

              setDialogState(() {
                isSending = true;
                inputError = null;
              });

              try {
                await _saveInvite(
                  groupName: groupName,
                  target: target,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  context,
                  '그룹 초대를 보냈습니다.',
                );
              } catch (error) {
                debugPrint(
                  '그룹 초대 저장 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSending = false;
                  inputError =
                  '초대를 보내지 못했습니다.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons
                        .person_add_alt_outlined,
                    color: Color(
                      0xFF8068D8,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('그룹원 초대'),
                ],
              ),
              content: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    '초대할 사용자의 아이디 또는 이메일을 입력해주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(
                        0xFF777C86,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller:
                    inviteController,
                    enabled: !isSending,
                    autofocus: true,
                    textInputAction:
                    TextInputAction.done,
                    onSubmitted: (_) {
                      if (!isSending) {
                        sendInvite();
                      }
                    },
                    decoration:
                    InputDecoration(
                      labelText:
                      '아이디 또는 이메일',
                      hintText:
                      '예: user01 또는 user@email.com',
                      errorText: inputError,
                      prefixIcon:
                      const Icon(
                        Icons
                            .alternate_email_rounded,
                      ),
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : sendInvite,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF8068D8,
                    ),
                    foregroundColor:
                    Colors.white,
                  ),
                  child: isSending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('초대 보내기'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      inviteController.dispose();
    });
  }

  /// 컬렉션 안의 문서들을 나누어 삭제
  Future<void> _deleteCollection(
      Query<Map<String, dynamic>> query,
      ) async {
    while (true) {
      final snapshot =
      await query.limit(200).get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch =
      FirebaseFirestore.instance.batch();

      for (final document in snapshot.docs) {
        batch.delete(
          document.reference,
        );
      }

      await batch.commit();

      if (snapshot.docs.length < 200) {
        break;
      }
    }
  }

  /// 스터디와 관련된 데이터 삭제
  Future<void> _deleteStudyData() async {
    final firestore =
        FirebaseFirestore.instance;

    final groupDocument =
    firestore
        .collection('studyGroups')
        .doc(studyId);

    // 문제별 답안 삭제
    final quizSnapshot =
    await groupDocument
        .collection('quizzes')
        .get();

    for (final quizDocument
    in quizSnapshot.docs) {
      await _deleteCollection(
        quizDocument.reference
            .collection('answers'),
      );
    }

    // 문제 삭제
    await _deleteCollection(
      groupDocument.collection('quizzes'),
    );

    // 그룹원 삭제
    await _deleteCollection(
      groupDocument.collection('members'),
    );

    // 채팅 메시지 삭제
    final chatDocument =
    firestore
        .collection('chats')
        .doc(studyId);

    await _deleteCollection(
      chatDocument.collection('messages'),
    );

    final chatSnapshot =
    await chatDocument.get();

    if (chatSnapshot.exists) {
      await chatDocument.delete();
    }

    // 해당 스터디의 초대 삭제
    await _deleteCollection(
      firestore
          .collection('studyGroupInvites')
          .where(
        'groupId',
        isEqualTo: studyId,
      ),
    );

    // 마지막으로 스터디 문서 삭제
    await groupDocument.delete();
  }

  /// 스터디 삭제 확인창
  void _showDeleteStudyDialog(
      BuildContext context,
      String groupName,
      ) {
    bool isDeleting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            Future<void> deleteStudy() async {
              setDialogState(() {
                isDeleting = true;
              });

              try {
                await _deleteStudyData();

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(
                  context,
                );
              } catch (error) {
                debugPrint(
                  '스터디 삭제 오류: $error',
                );

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isDeleting = false;
                });

                _showMessage(
                  context,
                  '스터디를 삭제하지 못했습니다.',
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  SizedBox(width: 10),
                  Text('스터디 삭제'),
                ],
              ),
              content: Text(
                '"$groupName" 스터디를 정말 삭제하시겠습니까?\n\n'
                    '그룹원, 채팅, 문제, 초대 정보도 함께 삭제되며 '
                    '삭제한 후에는 복구할 수 없습니다.',
                style: const TextStyle(
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : deleteStudy,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: isDeleting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('삭제'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 그룹원 신고
  void _showReportDialog(
      BuildContext context,
      ) {
    String selectedReason =
        '부적절한 언행';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title:
              const Text('그룹원 신고'),
              content:
              DropdownButtonFormField<String>(
                initialValue:
                selectedReason,
                decoration:
                const InputDecoration(
                  labelText: '신고 사유',
                  border:
                  OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '부적절한 언행',
                    child:
                    Text('부적절한 언행'),
                  ),
                  DropdownMenuItem(
                    value: '광고 또는 홍보',
                    child:
                    Text('광고 또는 홍보'),
                  ),
                  DropdownMenuItem(
                    value: '스터디 활동 방해',
                    child:
                    Text('스터디 활동 방해'),
                  ),
                  DropdownMenuItem(
                    value: '기타',
                    child: Text('기타'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setDialogState(() {
                    selectedReason = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );

                    _showMessage(
                      context,
                      '신고 기능은 다음 단계에서 연결합니다.',
                    );
                  },
                  child: const Text('신고'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 스터디 나가기
  void _showLeaveDialog(
      BuildContext context,
      ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
          const Text('스터디 나가기'),
          content: const Text(
            '이 스터디에서 나가시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                _showMessage(
                  context,
                  '스터디 나가기 기능은 다음 단계에서 연결합니다.',
                );
              },
              style:
              TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );
  }

  /// 작은 표시
  Widget _buildBadge(
      String text,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 상세 정보 한 줄
  Widget _buildInfoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(
              0xFF8A8F99,
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 78,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(
                  0xFF777C86,
                ),
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 메뉴 카드
  Widget _buildMenuButton({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(
                color: const Color(
                  0xFFF0ECFF,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: const Color(
                  0xFF8068D8,
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    description,
                    style:
                    const TextStyle(
                      fontSize: 12,
                      color: Color(
                        0xFF7B7F89,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Color(
                0xFF999DA6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(studyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '스터디 상세 조회 오류: '
                '${snapshot.error}',
          );
        }

        if (snapshot.hasData &&
            snapshot.data?.exists == false) {
          return Scaffold(
            appBar: AppBar(
              title:
              const Text('스터디 상세'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                '삭제되었거나 존재하지 않는 스터디입니다.',
              ),
            ),
          );
        }

        final currentStudyData =
            snapshot.data?.data() ??
                studyData;

        final groupName =
            currentStudyData['groupName']
                ?.toString() ??
                '그룹명 없음';

        final description =
            currentStudyData['description']
                ?.toString() ??
                '';

        final certificateName =
            currentStudyData[
            'certificateName']
                ?.toString() ??
                '공통 스터디';

        final ownerNickname =
            currentStudyData[
            'ownerNickname']
                ?.toString() ??
                '방장 정보 없음';

        final currentMemberCount =
        _getInt(
          currentStudyData,
          'currentMemberCount',
        );

        final maxMemberCount =
        _getInt(
          currentStudyData,
          'maxMemberCount',
        );

        final isPublic =
        currentStudyData['isPublic']
        is bool
            ? currentStudyData[
        'isPublic'] as bool
            : true;

        final joinApprovalRequired =
        currentStudyData[
        'joinApprovalRequired']
        is bool
            ? currentStudyData[
        'joinApprovalRequired']
        as bool
            : true;

        final isOwner =
        _isOwner(currentStudyData);

        return Scaffold(
          appBar: AppBar(
            title:
            const Text('스터디 상세'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            actions: [
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditPage(
                        context,
                        currentStudyData,
                      );
                    }

                    if (value == 'member') {
                      _openMemberManagement(
                        context,
                        currentStudyData,
                      );
                    }

                    if (value == 'delete') {
                      _showDeleteStudyDialog(
                        context,
                        groupName,
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('방 수정'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'member',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .manage_accounts_outlined,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text('그룹원 관리'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .delete_outline,
                              size: 20,
                              color:
                              Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '방 삭제',
                              style:
                              TextStyle(
                                color:
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),

          body: AppMainBackground(
            applySafeArea: false,
            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                24,
                20,
                40,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildBadge(
                              certificateName,
                              const Color(
                                0xFFE9E4FF,
                              ),
                              const Color(
                                0xFF6F58C9,
                              ),
                            ),

                            _buildBadge(
                              isPublic
                                  ? '공개'
                                  : '비공개',
                              const Color(
                                0xFFF1F2F5,
                              ),
                              const Color(
                                0xFF737782,
                              ),
                            ),

                            if (isOwner)
                              _buildBadge(
                                '방장',
                                const Color(
                                  0xFFFFE7EE,
                                ),
                                const Color(
                                  0xFFD85F82,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        Text(
                          groupName,
                          style:
                          const TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          description.isEmpty
                              ? '등록된 스터디 소개가 없습니다.'
                              : description,
                          style:
                          const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(
                              0xFF686D78,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 24,
                        ),

                        _buildInfoRow(
                          Icons.person_outline,
                          '방장',
                          ownerNickname,
                        ),

                        _buildInfoRow(
                          Icons.groups_outlined,
                          '참여 인원',
                          '$currentMemberCount / '
                              '$maxMemberCount명',
                        ),

                        _buildInfoRow(
                          Icons.lock_outline,
                          '공개 여부',
                          isPublic
                              ? '공개'
                              : '비공개',
                        ),

                        _buildInfoRow(
                          Icons
                              .fact_check_outlined,
                          '참여 방식',
                          joinApprovalRequired
                              ? '방장 승인 후 참여'
                              : '바로 참여 가능',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '스터디 활동',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildMenuButton(
                    icon: Icons
                        .chat_bubble_outline,
                    title: '그룹 채팅',
                    description:
                    '스터디원들과 메시지를 주고받아요.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StudyChatPage(
                                studyId:
                                studyId,
                                groupName:
                                groupName,
                              ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildMenuButton(
                    icon: Icons
                        .emoji_events_outlined,
                    title: '공부시간 순위',
                    description:
                    '그룹원의 누적 공부시간 순위를 확인해요.',
                    onTap: () {
                      _openStudyRanking(
                        context,
                        currentStudyData,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildMenuButton(
                    icon:
                    Icons.quiz_outlined,
                    title: '발송된 문제 풀기',
                    description:
                    '그룹에 발송된 문제를 확인하고 풀어요.',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StudyQuizPage(
                                studyId:
                                studyId,
                                groupName:
                                groupName,
                              ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _buildMenuButton(
                    icon: Icons
                        .person_add_alt_outlined,
                    title: '그룹원 초대',
                    description:
                    '아이디 또는 이메일로 그룹원을 초대해요.',
                    onTap: () {
                      _showInviteDialog(
                        context,
                        groupName,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    '그룹 관리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildMenuButton(
                    icon:
                    Icons.report_outlined,
                    title: '그룹원 신고',
                    description:
                    '문제가 있는 그룹원을 신고해요.',
                    onTap: () {
                      _showReportDialog(
                        context,
                      );
                    },
                  ),

                  if (!isOwner) ...[
                    const SizedBox(
                      height: 12,
                    ),

                    _buildMenuButton(
                      icon: Icons.logout,
                      title: '스터디 나가기',
                      description:
                      '현재 스터디에서 나가요.',
                      onTap: () {
                        _showLeaveDialog(
                          context,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}