import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import 'community_models.dart';
import 'community_service.dart';

extension _CommunityDetailColors on BuildContext {
  AppColors get communityColors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }
}

class CommunityPostDetailPage extends StatefulWidget {
  final String postId;
  final CommunityService? service;

  const CommunityPostDetailPage({
    super.key,
    required this.postId,
    this.service,
  });

  @override
  State<CommunityPostDetailPage> createState() {
    return _CommunityPostDetailPageState();
  }
}

class _CommunityPostDetailPageState
    extends State<CommunityPostDetailPage> {
  late final CommunityService _service;

  int _streamVersion = 0;
  bool _viewCountIncreased = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CommunityService();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _increaseViewCount();
    });
  }

  Future<void> _increaseViewCount() async {
    if (_viewCountIncreased) {
      return;
    }

    _viewCountIncreased = true;

    try {
      await _service.increaseViewCount(widget.postId);
    } catch (error) {
      // 조회수 증가에 실패해도 상세 화면은 정상적으로 표시합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppTopBar(
        title: '게시글 상세',
      ),
      body: AppMainBackground(
        child: Padding(
          padding: const EdgeInsets.only(
            top: kToolbarHeight,
          ),
          child: StreamBuilder<CommunityPost?>(
            key: ValueKey(_streamVersion),
            stream: _service.watchPost(widget.postId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorView(
                  message: '게시글을 불러오지 못했어요.',
                  description:
                  '인터넷 연결과 Firestore 규칙을 확인해 주세요.',
                  onRetryPressed: () {
                    setState(() {
                      _streamVersion++;
                    });
                  },
                );
              }

              if (!snapshot.hasData &&
                  snapshot.connectionState ==
                      ConnectionState.waiting) {
                return const AppLoadingView(
                  message: '게시글을 불러오는 중이에요.',
                );
              }

              CommunityPost? post = snapshot.data;

              if (post == null) {
                return AppEmptyView(
                  message: '게시글을 찾을 수 없어요.',
                  description:
                  '삭제되었거나 공개되지 않은 게시글이에요.',
                  buttonText: '돌아가기',
                  onButtonPressed: () {
                    Navigator.pop(context);
                  },
                );
              }

              return _buildContent(post);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CommunityPost post) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        50,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBoardArea(post),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              _buildWriterArea(post),
              const SizedBox(height: 17),
              Divider(
                height: 1,
                color: context.communityColors.pinkSoft,
              ),
              const SizedBox(height: 20),
              Text(
                post.content,
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
              if (post.certificateTags.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildCertificateTags(post.certificateTags),
              ],
              if (post.imageAttachments.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildImages(post.imageAttachments),
              ],
              if (post.fileAttachments.isNotEmpty) ...[
                const SizedBox(height: 22),
                _buildFiles(post.fileAttachments),
              ],
              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: context.communityColors.pinkSoft,
              ),
              const SizedBox(height: 15),
              _buildPostCounts(post),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: context.communityColors.pinkStart,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                '댓글',
                style: TextStyle(
                  color: context.communityColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${post.commentCount}',
                style: TextStyle(
                  color: context.communityColors.pinkStart,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoardArea(CommunityPost post) {
    return Row(
      children: [
        _DetailBadge(
          label: post.boardType.label,
          backgroundColor: context.communityColors.pinkSoft,
        ),
        if (post.boardType == CommunityBoardType.question) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _questionStatusLabel(post.questionStatus),
            backgroundColor: context.communityColors.softBlue,
          ),
        ],
        if (post.boardType == CommunityBoardType.groupRecruit) ...[
          const SizedBox(width: 7),
          _DetailBadge(
            label: _recruitStatusLabel(post.recruitStatus),
            backgroundColor: context.communityColors.mint,
          ),
        ],
        const Spacer(),
        if (post.hasAttachment)
          Icon(
            Icons.attach_file_rounded,
            size: 19,
            color: context.communityColors.textSecondary,
          ),
      ],
    );
  }

  Widget _buildWriterArea(CommunityPost post) {
    return Row(
      children: [
        _buildProfileImage(post.writerProfileImageUrl),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.writerNickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.communityColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (post.isCertifiedWriter) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: context.communityColors.pinkStart,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatCreatedAt(post.createdAt),
                style: TextStyle(
                  color: context.communityColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage(String imageUrl) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.communityColors.pinkSoft,
      ),
      child: imageUrl.isEmpty
          ? Icon(
        Icons.person_rounded,
        color: context.communityColors.pinkStart,
      )
          : ClipOval(
        child: Image.network(
          imageUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person_rounded,
              color: context.communityColors.pinkStart,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCertificateTags(
      List<CommunityCertificateTag> tags,
      ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: context.communityColors.lavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '#${tag.certificateName}',
            style: TextStyle(
              color: context.communityColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImages(
      List<CommunityImageAttachment> images,
      ) {
    return Column(
      children: images.map((image) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              image.url,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 180,
                  alignment: Alignment.center,
                  color: context.communityColors.pinkSoft,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: context.communityColors.textSecondary,
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFiles(
      List<CommunityFileAttachment> files,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '첨부파일',
          style: TextStyle(
            color: context.communityColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        ...files.map((file) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: context.communityColors.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: context.communityColors.pinkStart,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.communityColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPostCounts(CommunityPost post) {
    return Row(
      children: [
        Expanded(
          child: _DetailCount(
            icon: Icons.remove_red_eye_outlined,
            label: '조회',
            value: post.viewCount,
          ),
        ),
        Expanded(
          child: _DetailCount(
            icon: Icons.chat_bubble_outline_rounded,
            label: '댓글',
            value: post.commentCount,
          ),
        ),
        Expanded(
          child: _DetailCount(
            icon: Icons.favorite_border_rounded,
            label: '좋아요',
            value: post.likeCount,
          ),
        ),
        Expanded(
          child: _DetailCount(
            icon: Icons.bookmark_border_rounded,
            label: '저장',
            value: post.bookmarkCount,
          ),
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const _DetailBadge({
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.communityColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailCount extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _DetailCount({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 19,
          color: context.communityColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          '$label $value',
          style: TextStyle(
            color: context.communityColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

String _questionStatusLabel(String status) {
  switch (status) {
    case 'ANSWERED':
      return '답변 완료';
    case 'RESOLVED':
    case 'CLOSED':
      return '해결 완료';
    default:
      return '답변 대기';
  }
}

String _recruitStatusLabel(String status) {
  switch (status) {
    case 'CLOSED':
      return '모집 마감';
    case 'ACTIVE':
      return '활동 중';
    case 'COMPLETED':
      return '활동 종료';
    default:
      return '모집 중';
  }
}

String _formatCreatedAt(DateTime? dateTime) {
  if (dateTime == null) {
    return '';
  }

  String year = dateTime.year.toString();
  String month = dateTime.month.toString().padLeft(2, '0');
  String day = dateTime.day.toString().padLeft(2, '0');
  String hour = dateTime.hour.toString().padLeft(2, '0');
  String minute = dateTime.minute.toString().padLeft(2, '0');

  return '$year.$month.$day $hour:$minute';
}
