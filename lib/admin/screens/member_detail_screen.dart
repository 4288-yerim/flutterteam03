import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_main_background.dart';
import '../services/admin_member_service.dart';
import '../widgets/member_detail_widgets.dart';
import 'member_community_activity_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.member});

  final AdminMember member;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final AdminMemberService _service = AdminMemberService();
  late Future<AdminMemberDetail> _detail;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _detail = _service.fetchMemberDetail(widget.member);
  }

  Future<void> _changeStatus(AdminMember member) async {
    final suspend = member.status == 'ACTIVE';
    var confirmed = false;
    await AppConfirmDialog.show<void>(
      context,
      icon: suspend ? Icons.person_off_rounded : Icons.person_add_alt_1_rounded,
      title: suspend ? '회원 정지' : '정지 해제',
      description: suspend
          ? '${member.nickname} 회원을 정지하시겠습니까?'
          : '${member.nickname} 회원의 정지를 해제하시겠습니까?',
      primaryLabel: suspend ? '정지' : '정지 해제',
      secondaryLabel: '취소',
      isDestructive: suspend,
      onSecondaryPressed: () => Navigator.pop(context),
      onPrimaryPressed: () {
        confirmed = true;
        Navigator.pop(context);
      },
    );
    if (!confirmed || !mounted) return;

    setState(() => _isUpdatingStatus = true);
    try {
      await _service.updateMemberSuspension(uid: member.uid, suspend: suspend);
      if (!mounted) return;
      setState(() {
        _detail = _service.fetchMemberDetail(member);
        _isUpdatingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(suspend ? '회원을 정지했습니다.' : '회원 정지를 해제했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 상태를 변경하지 못했습니다.')));
    }
  }

  Future<void> _editProfile(AdminMember member) async {
    final nicknameController = TextEditingController(text: member.nickname);
    final bioController = TextEditingController(text: member.bio);
    final formKey = GlobalKey<FormState>();

    InputDecoration fieldDecoration({
      required String label,
      required String hint,
      required IconData icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
        filled: true,
        fillColor: const Color(0xFFF7F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2DFE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
      );
    }

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        padding: EdgeInsets.fromLTRB(
          22,
          14,
          22,
          MediaQuery.of(modalContext).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF77747E).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EDFF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '회원 정보 수정',
                              style: TextStyle(
                                color: Color(0xFF242126),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '닉네임과 소개글을 변경할 수 있어요.',
                              style: TextStyle(
                                color: Color(0xFF77747E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: nicknameController,
                    maxLength: 12,
                    textInputAction: TextInputAction.next,
                    decoration: fieldDecoration(
                      label: '닉네임',
                      hint: '닉네임을 입력해 주세요.',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (value) {
                      final nickname = value?.trim() ?? '';
                      if (nickname.isEmpty) {
                        return '닉네임을 입력해 주세요.';
                      }
                      if (nickname.length > 12) {
                        return '닉네임은 12자 이하로 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bioController,
                    maxLength: 100,
                    maxLines: 4,
                    decoration: fieldDecoration(
                      label: '소개글',
                      hint: '회원 소개글을 입력해 주세요.',
                      icon: Icons.subject_rounded,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length > 100) {
                        return '소개글은 100자 이하로 입력해 주세요.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState?.validate() == true) {
                          Navigator.pop(modalContext, true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text(
                        '변경사항 저장',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldSave == true) {
      try {
        await _service.updateMemberProfile(
          uid: member.uid,
          nickname: nicknameController.text,
          bio: bioController.text,
        );
        if (mounted) {
          setState(() => _detail = _service.fetchMemberDetail(member));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('회원 정보를 수정했습니다.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('회원 정보를 수정하지 못했습니다.')));
        }
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      nicknameController.dispose();
      bioController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '회원 상세보기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppMainBackground(
        child: FutureBuilder<AdminMemberDetail>(
          future: _detail,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('회원 상세 정보를 불러오지 못했습니다.'));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              );
            }
            return _DetailBody(
              detail: snapshot.data!,
              isUpdatingStatus: _isUpdatingStatus,
              onStatusAction: _changeStatus,
              onEditProfile: _editProfile,
            );
          },
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.isUpdatingStatus,
    required this.onStatusAction,
    required this.onEditProfile,
  });

  final AdminMemberDetail detail;
  final bool isUpdatingStatus;
  final ValueChanged<AdminMember> onStatusAction;
  final ValueChanged<AdminMember> onEditProfile;

  @override
  Widget build(BuildContext context) {
    final member = detail.member;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
      children: [
        _ProfileHeader(member: member),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => onEditProfile(member),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('닉네임·소개글 수정'),
          ),
        ),
        const SizedBox(height: 4),
        _InfoCard(
          rows: [
            ('가입 일시', _formatDateTime(member.createdAt)),
            ('마지막 로그인', _formatDateTime(member.lastLoginAt)),
            ('상시 로그인 여부', member.hasPersistentLogin ? '상시 로그인' : '아님'),
            ('상태', member.statusLabel),
            ('가입 유형', member.providerLabel),
            ('구독 여부', detail.isSubscribed ? '구독 중' : '미구독'),
            ('마케팅 수신', detail.marketingAlertEnabled ? '동의' : '미동의'),
          ],
        ),
        if (_showsStatusButton(member.status)) ...[
          const SizedBox(height: 12),
          _StatusButton(
            member: member,
            isLoading: isUpdatingStatus,
            onPressed: () => onStatusAction(member),
          ),
        ],
        const SizedBox(height: 12),
        _ActivityCard(
          icon: Icons.report_problem_outlined,
          label: '신고 누적 횟수',
          count: member.reportCount,
          countSuffix: '회',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemberReportSummaryScreen(member: member),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                icon: Icons.article_outlined,
                label: '작성한 글',
                count: detail.posts.length,
                onTap: () =>
                    _openActivity(context, AdminCommunityActivityType.post),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityCard(
                icon: Icons.chat_bubble_outline_rounded,
                label: '작성한 댓글',
                count: detail.comments.length,
                onTap: () =>
                    _openActivity(context, AdminCommunityActivityType.comment),
              ),
            ),
          ],
        ),
        _Section(
          icon: Icons.subject_rounded,
          title: '소개글',
          count: member.bio.isEmpty ? '미등록' : '등록',
          child: _EmptyOrText(
            value: member.bio,
            emptyMessage: '등록된 소개글이 없습니다.',
          ),
        ),
        _Section(
          icon: Icons.workspace_premium_rounded,
          title: '목표 자격증',
          count: '${detail.goals.length}개',
          child: detail.goals.isEmpty
              ? const _EmptyText('등록된 목표 자격증이 없습니다.')
              : Column(
                  children: detail.goals
                      .map(
                        (goal) => _RecordTile(
                          icon: Icons.flag_outlined,
                          title: goal.certificateName,
                          subtitle:
                              '등록 ${_formatDateTime(goal.createdAt)} · '
                              '수정 ${_formatDateTime(goal.updatedAt)}',
                        ),
                      )
                      .toList(),
                ),
        ),
        _Section(
          icon: Icons.groups_rounded,
          title: '참여 스터디',
          count: '${detail.studies.length}개',
          child: detail.studies.isEmpty
              ? const _EmptyText('참여 중인 스터디가 없습니다.')
              : Column(
                  children: detail.studies
                      .map(
                        (study) => _RecordTile(
                          icon: Icons.menu_book_rounded,
                          title: study.name,
                          subtitle:
                              '${study.certificateName} · '
                              '${study.currentMemberCount}/${study.maxMemberCount}명',
                        ),
                      )
                      .toList(),
                ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 2),
          child: Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: Color(0xFF6C63FF)),
              SizedBox(width: 9),
              Text(
                'AI 메뉴 사용 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        _AiSection(
          title: '학습 플랜',
          records: detail.studyPlans,
          labelBuilder: _studyPlanLabel,
        ),
        _AiSection(
          title: '문제 생성',
          records: detail.quizzes,
          labelBuilder: _quizLabel,
        ),
        _AiSection(
          title: '로드맵',
          records: detail.roadmaps,
          labelBuilder: _roadmapLabel,
        ),
        _AiSection(
          title: '요약 생성',
          records: detail.summaries,
          labelBuilder: _summaryLabel,
        ),
      ],
    );
  }

  void _openActivity(
    BuildContext context,
    AdminCommunityActivityType initialType,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberCommunityActivityScreen(
          memberNickname: detail.member.nickname,
          initialType: initialType,
          posts: detail.posts,
          comments: detail.comments,
        ),
      ),
    );
  }
}

class MemberReportSummaryScreen extends StatelessWidget {
  const MemberReportSummaryScreen({super.key, required this.member});

  final AdminMember member;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '신고 누적 상세보기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppMainBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
          children: [
            Text(
              '${member.nickname} 회원 신고 현황',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '회원에게 누적된 신고 건수를 확인할 수 있어요.',
              style: TextStyle(color: Color(0xFF77747E), fontSize: 13),
            ),
            const SizedBox(height: 18),
            _ReportCountCard(
              icon: Icons.report_problem_outlined,
              label: '신고 누적 횟수',
              count: member.reportCount,
              isPrimary: true,
            ),
            const SizedBox(height: 10),
            _ReportCountCard(
              icon: Icons.article_outlined,
              label: '게시글 신고 누적 횟수',
              count: member.postReportCount,
            ),
            const SizedBox(height: 10),
            _ReportCountCard(
              icon: Icons.chat_bubble_outline_rounded,
              label: '댓글 신고 누적 횟수',
              count: member.commentsReportCount,
            ),
            const SizedBox(height: 10),
            _ReportCountCard(
              icon: Icons.groups_outlined,
              label: '스터디원 신고 누적 횟수',
              count: member.studyMemberReportCount,
            ),
            const SizedBox(height: 26),
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Color(0xFF6C63FF)),
                SizedBox(width: 9),
                Text(
                  '신고 내역',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AdminMemberDetailSurface(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 38),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    color: Color(0xFF99949E),
                    size: 34,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '표시할 신고 내역이 없습니다.',
                    style: TextStyle(
                      color: Color(0xFF77747E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '신고 내역 데이터는 추후 연결될 예정입니다.',
                    style: TextStyle(color: Color(0xFF99949E), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCountCard extends StatelessWidget {
  const _ReportCountCard({
    required this.icon,
    required this.label,
    required this.count,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final accent = isPrimary
        ? const Color(0xFFE85D68)
        : const Color(0xFF6C63FF);
    return AdminMemberDetailSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5D5962),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count건',
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.member});
  final AdminMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoration(),
      child: Row(
        children: [
          _ProfileImage(url: member.profileImageUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member.identifier.isEmpty ? '아이디 정보 없음' : member.identifier,
                  style: const TextStyle(
                    color: Color(0xFF77747E),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileImage extends StatelessWidget {
  const _ProfileImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    const fallback = CircleAvatar(
      radius: 36,
      backgroundColor: Color(0xFFF0EDFF),
      child: Icon(Icons.person_rounded, color: Color(0xFF6C63FF), size: 38),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return AdminMemberDetailSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    SizedBox(
                      width: 105,
                      child: Text(
                        row.$1,
                        style: const TextStyle(
                          color: Color(0xFF77747E),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != rows.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.member,
    required this.isLoading,
    required this.onPressed,
  });

  final AdminMember member;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final withdrawalPending = member.status == 'WITHDRAWAL_PENDING';
    final suspended = member.status == 'SUSPENDED';
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: withdrawalPending || isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: suspended
              ? const Color(0xFF6C63FF)
              : const Color(0xFFE85D68),
          disabledBackgroundColor: const Color(0xFFE2DFE6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                withdrawalPending
                    ? Icons.block_rounded
                    : suspended
                    ? Icons.person_add_alt_1_rounded
                    : Icons.person_off_rounded,
              ),
        label: Text(
          withdrawalPending
              ? '탈퇴 신청 처리 중'
              : suspended
              ? '정지 해제'
              : '회원 정지',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.countSuffix = '개',
  });
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final String countSuffix;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF77747E),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$count$countSuffix',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.count,
  });
  final IconData icon;
  final String title;
  final String? count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AdminMemberDetailSurface(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: Icon(icon, color: const Color(0xFF6C63FF)),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          trailing: _ExpandTrailing(count: count),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.title,
    required this.records,
    required this.labelBuilder,
  });
  final String title;
  final List<AdminAiRecord> records;
  final String Function(AdminAiRecord) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AdminMemberDetailSurface(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          trailing: _ExpandTrailing(count: '${records.length}건'),
          shape: const Border(),
          collapsedShape: const Border(),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (records.isEmpty)
              const _EmptyText('사용 기록이 없습니다.')
            else
              ...records.map(
                (record) => _RecordTile(
                  icon: Icons.history_rounded,
                  title: labelBuilder(record),
                  subtitle: _formatTimestamp(record.data['createdAt']),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpandTrailing extends StatelessWidget {
  const _ExpandTrailing({this.count});
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count != null)
          Text(
            count!,
            style: const TextStyle(color: Color(0xFF77747E), fontSize: 12),
          ),
        const SizedBox(width: 5),
        const Icon(Icons.expand_more_rounded),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF756CE0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Color(0xFF99949E),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrText extends StatelessWidget {
  const _EmptyOrText({required this.value, required this.emptyMessage});
  final String value;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return value.isEmpty
        ? _EmptyText(emptyMessage)
        : Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF5D5962),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        value,
        style: const TextStyle(color: Color(0xFF99949E), fontSize: 12),
      ),
    );
  }
}

bool _showsStatusButton(String status) {
  return status == 'ACTIVE' ||
      status == 'SUSPENDED' ||
      status == 'WITHDRAWAL_PENDING';
}

BoxDecoration _decoration() => BoxDecoration(
  color: Colors.white.withValues(alpha: 0.95),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xFFECE9F0)),
);

String _studyPlanLabel(AdminAiRecord record) {
  final data = record.data;
  final certificate = _value(data['certificateName'], data['certificatename']);
  final examDate = _formatValueDate(data['examStartAt']);
  final studyStart = _value(
    data['recommendedStudyStartDate'],
    data['studyStartDate'],
  );
  final steps = data['totalStepCount']?.toString() ?? '0';
  return '${certificate.isEmpty ? '자격증 미지정' : certificate}'
      ' · 시험일 ${examDate.isEmpty ? '-' : examDate}'
      ' · 시작일 ${studyStart.isEmpty ? '-' : studyStart}'
      ' · $steps단계';
}

String _quizLabel(AdminAiRecord record) {
  final data = record.data;
  return [
    _value(data['certificationName']).isEmpty
        ? '자격증 미지정'
        : _value(data['certificationName']),
    if (_value(data['subject']).isNotEmpty) _value(data['subject']),
    if (_value(data['examType']).isNotEmpty) _value(data['examType']),
  ].join(' · ');
}

String _roadmapLabel(AdminAiRecord record) {
  final job = _value(record.data['job']);
  final certificates = record.data['certificates'];
  return '${job.isEmpty ? '직무 미지정' : job} · '
      '자격증 ${certificates is List ? certificates.length : 0}개';
}

String _summaryLabel(AdminAiRecord record) {
  final certificate = _value(record.data['certificateName']);
  return certificate.isEmpty ? '업로드 자료' : certificate;
}

String _value(dynamic first, [dynamic second]) {
  final firstValue = first?.toString().trim() ?? '';
  return firstValue.isNotEmpty ? firstValue : second?.toString().trim() ?? '';
}

String _formatValueDate(dynamic value) {
  return value is Timestamp
      ? _formatDate(value.toDate())
      : value?.toString().trim() ?? '';
}

String _formatTimestamp(dynamic value) {
  return value is Timestamp ? _formatDateTime(value.toDate()) : '날짜 정보 없음';
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '정보 없음';
  return '${value.year}.${_two(value.month)}.${_two(value.day)} '
      '${_two(value.hour)}:${_two(value.minute)}';
}

String _formatDate(DateTime value) {
  return '${value.year}.${_two(value.month)}.${_two(value.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
