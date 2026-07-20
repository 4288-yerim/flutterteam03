import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import 'community_models.dart';
import 'community_service.dart';

// theme.dart를 수정하지 않고 커뮤니티에서 테마 색상 사용
extension _CommunityContextColors on BuildContext {
  AppColors get communityColors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }
}

class CommunityMainPage extends StatefulWidget {
  final CommunityService? service;
  final ValueChanged<String>? onPostTap;
  final VoidCallback? onWritePressed;

  const CommunityMainPage({
    super.key,
    this.service,
    this.onPostTap,
    this.onWritePressed,
  });

  @override
  State<CommunityMainPage> createState() => _CommunityMainPageState();
}

class _CommunityMainPageState extends State<CommunityMainPage> {
  late final CommunityService _service;

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  CommunityBoardType _selectedBoard = CommunityBoardType.all;
  CommunityPostSort _selectedSort = CommunityPostSort.latest;

  String _selectedCertificateId = '';
  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CommunityService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  void _openPost(String postId) {
    if (widget.onPostTap != null) {
      widget.onPostTap!(postId);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '게시글 상세 화면은 다음 단계에서 연결할게요.',
        ),
      ),
    );
  }

  void _openWriter() {
    if (widget.onWritePressed != null) {
      widget.onWritePressed!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '게시글 작성 화면은 다음 단계에서 연결할게요.',
        ),
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();

    setState(() {
      _selectedBoard = CommunityBoardType.all;
      _selectedSort = CommunityPostSort.latest;
      _selectedCertificateId = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.communityColors;

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '커뮤니티',
        actions: [
          IconButton(
            tooltip: '검색',
            onPressed: () {
              _searchFocusNode.requestFocus();
            },
            icon: Icon(
              Icons.search_rounded,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: AppMainBackground(
        child: Padding(
          padding: const EdgeInsets.only(
            top: kToolbarHeight,
          ),
          child: StreamBuilder<List<CommunityPost>>(
            key: ValueKey(_streamVersion),
            stream: _service.watchPosts(),
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

              if (!snapshot.hasData) {
                return const AppLoadingView(
                  message: '커뮤니티를 불러오는 중이에요.',
                );
              }

              return _buildContent(snapshot.data!);
            },
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWriter,
        backgroundColor: colors.pinkStart,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text(
          '글쓰기',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      List<CommunityPost> allPosts,
      ) {
    List<CommunityPost> posts =
    _service.filterAndSortPosts(
      posts: allPosts,
      boardType: _selectedBoard,
      sort: _selectedSort,
      keyword: _searchController.text,
      certificateId: _selectedCertificateId,
    );

    List<CommunityCertificateTag> certificates =
    _service.collectCertificateTags(allPosts);

    return RefreshIndicator(
      color: context.communityColors.pinkStart,
      onRefresh: () async {
        setState(() {
          _streamVersion++;
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          110,
        ),
        children: [
          _buildIntroCard(),

          const SizedBox(height: 16),

          _buildSearchField(),

          const SizedBox(height: 14),

          _buildBoardChips(),

          if (certificates.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCertificateChips(certificates),
          ],

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBoard ==
                          CommunityBoardType.all
                          ? '전체 게시글'
                          : '${_selectedBoard.label} 게시판',
                      style: TextStyle(
                        color: context
                            .communityColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${posts.length}개의 글',
                      style: TextStyle(
                        color: context
                            .communityColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              _buildSortMenu(),
            ],
          ),

          const SizedBox(height: 12),

          if (allPosts.isEmpty)
            _buildEmptyCard(
              message: '아직 게시글이 없어요.',
              description:
              '첫 번째 이야기를 남겨 보세요.',
              buttonText: '첫 글 작성하기',
              onPressed: _openWriter,
            )
          else if (posts.isEmpty)
            _buildEmptyCard(
              message: '조건에 맞는 게시글이 없어요.',
              description:
              '검색어나 필터를 바꿔 보세요.',
              buttonText: '필터 초기화',
              onPressed: _resetFilters,
            )
          else
            ...posts.map(
                  (post) {
                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 12),
                  child: _CommunityPostCard(
                    post: post,
                    onTap: () {
                      _openPost(post.id);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      backgroundColor:
      context.communityColors.pinkSoft,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: context.communityColors.pinkStart,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '함께하면 공부가 더 쉬워져요',
                  style: TextStyle(
                    color: context
                        .communityColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '질문, 합격 후기, 공부 팁과 스터디를 나눠 보세요.',
                  style: TextStyle(
                    color: context
                        .communityColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: '제목, 내용, 작성자, 자격증 검색',
        hintStyle: TextStyle(
          color:
          context.communityColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color:
          context.communityColors.textSecondary,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
          tooltip: '검색어 지우기',
          onPressed: () {
            _searchController.clear();
            setState(() {});
          },
          icon: const Icon(
            Icons.close_rounded,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color:
            context.communityColors.pinkSoft,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color:
            context.communityColors.pinkStart,
          ),
        ),
      ),
    );
  }

  Widget _buildBoardChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount:
        CommunityBoardType.values.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          CommunityBoardType board =
          CommunityBoardType.values[index];

          bool selected =
              board == _selectedBoard;

          return ChoiceChip(
            label: Text(board.label),
            selected: selected,
            showCheckmark: false,
            onSelected: (value) {
              setState(() {
                _selectedBoard = board;
              });
            },
            selectedColor:
            context.communityColors.pinkStart,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? context
                  .communityColors.pinkStart
                  : context
                  .communityColors.pinkSoft,
            ),
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : context
                  .communityColors.textPrimary,
              fontSize: 12,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCertificateChips(
      List<CommunityCertificateTag> certificates,
      ) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CertificateFilterChip(
            label: '자격증 전체',
            selected:
            _selectedCertificateId.isEmpty,
            onTap: () {
              setState(() {
                _selectedCertificateId = '';
              });
            },
          ),

          ...certificates.map(
                (tag) {
              return Padding(
                padding:
                const EdgeInsets.only(left: 7),
                child: _CertificateFilterChip(
                  label:
                  '#${tag.certificateName}',
                  selected:
                  _selectedCertificateId ==
                      tag.certificateId,
                  onTap: () {
                    setState(() {
                      _selectedCertificateId =
                          tag.certificateId;
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<CommunityPostSort>(
      tooltip: '정렬 방식',
      initialValue: _selectedSort,
      onSelected: (sort) {
        setState(() {
          _selectedSort = sort;
        });
      },
      itemBuilder: (context) {
        return CommunityPostSort.values.map(
              (sort) {
            return PopupMenuItem<CommunityPostSort>(
              value: sort,
              child: Text(sort.label),
            );
          },
        ).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
            context.communityColors.pinkSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedSort.label,
              style: TextStyle(
                color: context
                    .communityColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required String message,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 390,
        child: AppEmptyView(
          message: message,
          description: description,
          buttonText: buttonText,
          onButtonPressed: onPressed,
        ),
      ),
    );
  }
}

class _CertificateFilterChip
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CertificateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.communityColors.lavender
              : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color:
            context.communityColors.lavender,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? context
                .communityColors.textPrimary
                : context
                .communityColors.textSecondary,
            fontSize: 12,
            fontWeight: selected
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CommunityPostCard
    extends StatelessWidget {
  final CommunityPost post;
  final VoidCallback onTap;

  const _CommunityPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BoardBadge(
                    boardType: post.boardType,
                  ),

                  const SizedBox(width: 7),

                  if (post.boardType ==
                      CommunityBoardType.question)
                    _StatusBadge(
                      label: _questionStatusLabel(
                        post.questionStatus,
                      ),
                      backgroundColor: context
                          .communityColors.softBlue,
                    ),

                  if (post.boardType ==
                      CommunityBoardType
                          .groupRecruit)
                    _StatusBadge(
                      label: _recruitStatusLabel(
                        post.recruitStatus,
                      ),
                      backgroundColor: context
                          .communityColors.mint,
                    ),

                  const Spacer(),

                  if (post.hasAttachment)
                    Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: context
                          .communityColors
                          .textSecondary,
                    ),
                ],
              ),

              const SizedBox(height: 11),

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context
                                .communityColors
                                .textPrimary,
                            fontSize: 16,
                            height: 1.35,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          post.content
                              .replaceAll(
                            RegExp(r'\s+'),
                            ' ',
                          )
                              .trim(),
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context
                                .communityColors
                                .textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (post.thumbnailUrl.isNotEmpty) ...[
                    const SizedBox(width: 11),

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(12),
                      child: Image.network(
                        post.thumbnailUrl,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return Container(
                            width: 68,
                            height: 68,
                            color: context
                                .communityColors
                                .pinkSoft,
                            child: const Icon(
                              Icons
                                  .image_not_supported_outlined,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              if (post.certificateTags.isNotEmpty) ...[
                const SizedBox(height: 10),

                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: post.certificateTags
                      .take(3)
                      .map(
                        (tag) {
                      return Text(
                        '#${tag.certificateName}',
                        style: TextStyle(
                          color: context
                              .communityColors
                              .textPrimary,
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      );
                    },
                  ).toList(),
                ),
              ],

              const SizedBox(height: 13),

              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.writerNickname,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context
                            .communityColors
                            .textPrimary,
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  if (post.isCertifiedWriter) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: context
                          .communityColors
                          .pinkStart,
                    ),
                  ],

                  const SizedBox(width: 7),

                  Text(
                    _formatCreatedAt(
                      post.createdAt,
                    ),
                    style: TextStyle(
                      color: context
                          .communityColors
                          .textSecondary,
                      fontSize: 11,
                    ),
                  ),

                  const Spacer(),

                  _PostCount(
                    icon:
                    Icons.remove_red_eye_outlined,
                    value: post.viewCount,
                  ),

                  const SizedBox(width: 7),

                  _PostCount(
                    icon:
                    Icons.chat_bubble_outline,
                    value: post.commentCount,
                  ),

                  const SizedBox(width: 7),

                  _PostCount(
                    icon: Icons.favorite_border,
                    value: post.likeCount,
                  ),

                  const SizedBox(width: 7),

                  _PostCount(
                    icon: Icons.bookmark_border,
                    value: post.bookmarkCount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardBadge extends StatelessWidget {
  final CommunityBoardType boardType;

  const _BoardBadge({
    required this.boardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: context.communityColors.pinkSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        boardType.label,
        style: TextStyle(
          color:
          context.communityColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const _StatusBadge({
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
          context.communityColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PostCount extends StatelessWidget {
  final IconData icon;
  final int value;

  const _PostCount({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color:
          context.communityColors.textSecondary,
        ),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: TextStyle(
            color: context
                .communityColors.textSecondary,
            fontSize: 10,
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

  Duration difference =
  DateTime.now().difference(dateTime);

  if (!difference.isNegative &&
      difference.inMinutes < 1) {
    return '방금 전';
  }

  if (!difference.isNegative &&
      difference.inHours < 1) {
    return '${difference.inMinutes}분 전';
  }

  if (!difference.isNegative &&
      difference.inDays < 1) {
    return '${difference.inHours}시간 전';
  }

  if (!difference.isNegative &&
      difference.inDays < 7) {
    return '${difference.inDays}일 전';
  }

  String month =
  dateTime.month.toString().padLeft(2, '0');

  String day =
  dateTime.day.toString().padLeft(2, '0');

  return '$month.$day';
}