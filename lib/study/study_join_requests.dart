import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';

class StudyJoinRequestService {
  const StudyJoinRequestService._();

  static Future<void> approve({
    required String studyId,
    required String memberUid,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final groupDocument = FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);
    final memberDocument = groupDocument.collection('members').doc(memberUid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupDocument);
      final memberSnapshot = await transaction.get(memberDocument);

      if (!groupSnapshot.exists || !memberSnapshot.exists) {
        throw Exception('참여 신청 정보를 찾을 수 없습니다.');
      }

      final groupData = groupSnapshot.data() ?? <String, dynamic>{};
      final memberData = memberSnapshot.data() ?? <String, dynamic>{};

      if (groupData['ownerUid']?.toString() != currentUser.uid) {
        throw Exception('방장만 참여 신청을 처리할 수 있습니다.');
      }

      if (memberData['status']?.toString() != 'PENDING') {
        throw Exception('이미 처리된 참여 신청입니다.');
      }

      final currentMemberCount = _getInt(groupData['currentMemberCount']);
      final maxMemberCount = _getInt(groupData['maxMemberCount']);

      if (maxMemberCount > 0 && currentMemberCount >= maxMemberCount) {
        throw Exception('모집 인원이 모두 찼습니다.');
      }

      final newMemberCount = currentMemberCount + 1;
      final isFull = maxMemberCount > 0 && newMemberCount >= maxMemberCount;

      transaction.update(memberDocument, {
        'status': 'ACTIVE',
        'joinedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(groupDocument, {
        'currentMemberCount': newMemberCount,
        'status': isFull ? 'CLOSED' : 'RECRUITING',
        'recruitmentStatus': isFull ? 'CLOSED' : 'OPEN',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> reject({
    required String studyId,
    required String memberUid,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('로그인 정보가 없습니다.');
    }

    final groupDocument = FirebaseFirestore.instance
        .collection('studyGroups')
        .doc(studyId);
    final memberDocument = groupDocument.collection('members').doc(memberUid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(groupDocument);
      final memberSnapshot = await transaction.get(memberDocument);

      if (!groupSnapshot.exists || !memberSnapshot.exists) {
        throw Exception('참여 신청 정보를 찾을 수 없습니다.');
      }

      final groupData = groupSnapshot.data() ?? <String, dynamic>{};
      final memberData = memberSnapshot.data() ?? <String, dynamic>{};

      if (groupData['ownerUid']?.toString() != currentUser.uid) {
        throw Exception('방장만 참여 신청을 처리할 수 있습니다.');
      }

      if (memberData['status']?.toString() != 'PENDING') {
        throw Exception('이미 처리된 참여 신청입니다.');
      }

      transaction.update(memberDocument, {
        'status': 'REJECTED',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static int _getInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StudyJoinRequestsPage extends StatefulWidget {
  final String studyId;

  const StudyJoinRequestsPage({super.key, required this.studyId});

  @override
  State<StudyJoinRequestsPage> createState() => _StudyJoinRequestsPageState();
}

class _StudyJoinRequestsPageState extends State<StudyJoinRequestsPage> {
  final Set<String> _processingMemberUids = <String>{};

  ColorScheme get _colorScheme => Theme.of(context).colorScheme;

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _approve(String memberUid) async {
    if (_processingMemberUids.contains(memberUid)) {
      return;
    }
    setState(() => _processingMemberUids.add(memberUid));

    try {
      await StudyJoinRequestService.approve(
        studyId: widget.studyId,
        memberUid: memberUid,
      );
      _showMessage('참여 신청을 승인했습니다.');
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _processingMemberUids.remove(memberUid));
      }
    }
  }

  Future<void> _reject(String memberUid) async {
    if (_processingMemberUids.contains(memberUid)) {
      return;
    }
    setState(() => _processingMemberUids.add(memberUid));

    try {
      await StudyJoinRequestService.reject(
        studyId: widget.studyId,
        memberUid: memberUid,
      );
      _showMessage('참여 신청을 거절했습니다.');
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _processingMemberUids.remove(memberUid));
      }
    }
  }

  Widget _buildRequestList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('studyGroups')
          .doc(widget.studyId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView(message: '참여 신청 목록을 불러오는 중입니다.');
        }
        if (snapshot.hasError) {
          return const AppErrorView(
            message: '참여 신청 목록을 불러오지 못했습니다.',
            description: '잠시 후 다시 시도해 주세요.',
          );
        }

        final requests =
            (snapshot.data?.docs ?? [])
                .where((document) => document.data()['status'] == 'PENDING')
                .toList()
              ..sort((a, b) {
                final aTime = a.data()['requestedAt'];
                final bTime = b.data()['requestedAt'];
                if (aTime is Timestamp && bTime is Timestamp) {
                  return aTime.compareTo(bTime);
                }
                return 0;
              });

        if (requests.isEmpty) {
          return const AppEmptyView(
            message: '대기 중인 참여 신청이 없습니다.',
            description: '새로운 신청이 들어오면 이곳에 표시됩니다.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final document = requests[index];
            final data = document.data();
            final nickname = data['nickname']?.toString().trim();
            final profileImageUrl =
                data['profileImageUrl']?.toString().trim() ?? '';
            final isProcessing = _processingMemberUids.contains(document.id);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _colorScheme.secondaryContainer,
                    backgroundImage: profileImageUrl.isEmpty
                        ? null
                        : NetworkImage(profileImageUrl),
                    child: profileImageUrl.isEmpty
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname == null || nickname.isEmpty
                              ? '신청자'
                              : nickname,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '참여 승인 대기 중',
                          style: TextStyle(
                            fontSize: 12,
                            color: _colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isProcessing)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: () => _reject(document.id),
                      child: const Text('거절'),
                    ),
                    const SizedBox(width: 7),
                    FilledButton(
                      onPressed: () => _approve(document.id),
                      child: const Text('승인'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: const AppTopBar(title: '참여 신청 관리'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('studyGroups')
            .doc(widget.studyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(message: '방장 권한을 확인하는 중입니다.');
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const AppErrorView(
              message: '스터디 정보를 찾을 수 없습니다.',
              description: '삭제되었거나 더 이상 이용할 수 없는 스터디입니다.',
            );
          }

          final ownerUid = snapshot.data!.data()?['ownerUid']?.toString() ?? '';
          if (currentUser == null || ownerUid != currentUser.uid) {
            return const AppErrorView(
              message: '참여 신청을 관리할 수 없습니다.',
              description: '스터디 방장만 참여 신청을 처리할 수 있습니다.',
            );
          }

          return AppMainBackground(
            applySafeArea: false,
            child: _buildRequestList(),
          );
        },
      ),
    );
  }
}
