import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../services/user_profile_cache_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import '../notification/screens/notification.dart';
import '../notification/widgets/notification_bell_button.dart';
import 'community_models.dart';
import 'community_post_add.dart';
import 'community_post_detail.dart';
import 'community_service.dart';

// theme.dart를 수정하지 않고 커뮤니티에서 테마 색상 사용
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

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();
  final Map<String, Future<Map<String, dynamic>>> _writerProfileFutures = {};

  CommunityBoardType _selectedBoard = CommunityBoardType.all;
  CommunityPostSort _selectedSort = CommunityPostSort.latest;

  String _selectedCertificateId = '';
  int _streamVersion = 0;

  List<CommunityCertificateTag> _myCertificates = [];
  Set<CommunityBoardType> _favoriteBoards = {};

  bool _showMyFeed = false;
  bool _showFavoriteSettings = false;
  bool _isPreferenceLoading = true;
  bool _isSavingFavorite = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CommunityService();
    _loadCommunityPreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<Map<String, dynamic>> _profileForUid(String writerUid) {
    if (writerUid.isEmpty) {
      return Future<Map<String, dynamic>>.value({});
    }

    return _writerProfileFutures.putIfAbsent(writerUid, () {
      return _service.getUserCommunityProfile(writerUid);
    });
  }

  void _openPost(String postId) {
    if (widget.onPostTap != null) {
      widget.onPostTap!(postId);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CommunityPostDetailPage(postId: postId, service: _service);
        },
      ),
    );
  }

  Future<void> _openWriter() async {
    if (widget.onWritePressed != null) {
      widget.onWritePressed!();
      return;
    }

    String? postId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CommunityPostAddPage(service: _service);
        },
      ),
    );

    if (!mounted || postId == null) {
      return;
    }

    _openPost(postId);
  }

  void _resetFilters() {
    _searchController.clear();

    setState(() {
      _selectedBoard = CommunityBoardType.all;
      _selectedSort = CommunityPostSort.latest;
      _selectedCertificateId = '';
      _showMyFeed = false;
    });
  }

  Future<void> _loadCommunityPreferences() async {
    String userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userUid.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreferenceLoading = false;
      });
      return;
    }

    try {
      List<CommunityCertificateTag> certificates = await _service
          .getCertifiedCertificateTags(userUid);

      Set<CommunityBoardType> favoriteBoards = await _service
          .getFavoriteCommunityBoards(userUid);

      if (!mounted) {
        return;
      }

      setState(() {
        _myCertificates = certificates;
        _favoriteBoards = favoriteBoards;
        _isPreferenceLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPreferenceLoading = false;
      });
    }
  }

  Future<void> _toggleFavoriteBoard(CommunityBoardType boardType) async {
    String userUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userUid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 관심 게시판을 저장할 수 있어요.')));
      return;
    }

    if (_isSavingFavorite) {
      return;
    }

    bool wasFavorite = _favoriteBoards.contains(boardType);

    setState(() {
      _isSavingFavorite = true;

      if (wasFavorite) {
        _favoriteBoards.remove(boardType);
      } else {
        _favoriteBoards.add(boardType);
      }
    });

    try {
      await _service.setFavoriteCommunityBoard(
        userUid: userUid,
        boardType: boardType,
        isFavorite: !wasFavorite,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (wasFavorite) {
          _favoriteBoards.add(boardType);
        } else {
          _favoriteBoards.remove(boardType);
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관심 게시판을 저장하지 못했어요.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingFavorite = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(
        title: '커뮤니티',
        centerTitle: false,
        actions: [
          NotificationBellButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
            },
          ),
        ],
      ),

      body: AppMainBackground(
        child: StreamBuilder<List<CommunityPost>>(
          key: ValueKey(_streamVersion),
          stream: _service.watchPosts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                message: '게시글을 불러오지 못했어요.',
                description: '인터넷 연결과 Firestore 규칙을 확인해 주세요.',
                onRetryPressed: () {
                  setState(() {
                    _streamVersion++;
                  });
                },
              );
            }

            if (!snapshot.hasData) {
              return const AppLoadingView(message: '커뮤니티를 불러오는 중이에요.');
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community_fab',
        onPressed: _openWriter,
        backgroundColor: context.colors.pinkStart,
        foregroundColor: context.colors.onPrimary,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('글쓰기', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildContent(List<CommunityPost> allPosts) {
    List<CommunityPost> feedPosts = _showMyFeed
        ? _service.filterMyFeedPosts(
            posts: allPosts,
            certificateTags: _myCertificates,
            favoriteBoards: _favoriteBoards,
          )
        : allPosts;

    List<CommunityPost> posts = _service.filterAndSortPosts(
      posts: feedPosts,
      boardType: _selectedBoard,
      sort: _selectedSort,
      keyword: _searchController.text,
      certificateId: _selectedCertificateId,
    );

    List<CommunityCertificateTag> certificates = _service
        .collectCertificateTags(allPosts);

    return RefreshIndicator(
      color: context.colors.pinkStart,
      onRefresh: () async {
        UserProfileCacheService.instance.invalidateAll(
          allPosts.map((CommunityPost post) => post.writerUid),
        );

        setState(() {
          _writerProfileFutures.clear();
          _streamVersion++;
        });

        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildFeedControls(),
                if (_showFavoriteSettings) ...[
                  const SizedBox(height: 8),
                  _buildFavoriteBoardChips(),
                ],
                const SizedBox(height: 14),
                _buildBoardChips(),
                if (certificates.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _buildCertificateChips(certificates),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showMyFeed
                                ? '내 맞춤 피드'
                                : _selectedBoard == CommunityBoardType.all
                                ? '전체 게시글'
                                : '${_selectedBoard.label} 게시판',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${posts.length}개의 글',
                            style: TextStyle(
                              color: context.colors.textSecondary,
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
              ]),
            ),
          ),
          if (allPosts.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverToBoxAdapter(
                child: _buildEmptyCard(
                  message: '아직 게시글이 없어요.',
                  description: '첫 번째 이야기를 남겨 보세요.',
                  buttonText: '첫 글 작성하기',
                  onPressed: _openWriter,
                ),
              ),
            )
          else if (posts.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverToBoxAdapter(
                child: _buildEmptyCard(
                  message: '조건에 맞는 게시글이 없어요.',
                  description: '검색어나 필터를 바꿔 보세요.',
                  buttonText: '필터 초기화',
                  onPressed: _resetFilters,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  CommunityPost post = posts[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommunityPostCard(
                      post: post,
                      writerProfileFuture: _profileForUid(post.writerUid),
                      onTap: () {
                        _openPost(post.id);
                      },
                    ),
                  );
                }, childCount: posts.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: '커뮤니티 검색',
          hintStyle: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.colors.textSecondary,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.pinkSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: context.colors.pinkStart, width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedControls() {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          _buildFeedTab(
            label: '전체 피드',
            selected: !_showMyFeed,
            onPressed: () {
              setState(() {
                _showMyFeed = false;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFeedTab(
            label: '맞춤 피드',
            selected: _showMyFeed,
            onPressed: _isPreferenceLoading
                ? null
                : () {
                    setState(() {
                      _showMyFeed = true;
                      _selectedBoard = CommunityBoardType.all;
                      _selectedCertificateId = '';
                    });
                  },
          ),
          const SizedBox(width: 8),
          Material(
            color: _showFavoriteSettings
                ? context.colors.pinkStart
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(19),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showFavoriteSettings = !_showFavoriteSettings;
                });
              },
              borderRadius: BorderRadius.circular(19),
              child: SizedBox(
                width: 42,
                height: 38,
                child: Icon(
                  _showFavoriteSettings
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 20,
                  color: _showFavoriteSettings
                      ? context.colors.onPrimary
                      : context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab({
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? context.colors.pinkStart
              : Theme.of(context).colorScheme.surface,
          foregroundColor: selected
              ? context.colors.onPrimary
              : context.colors.textSecondary,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteBoardChips() {
    List<CommunityBoardType> boards = CommunityBoardType.values.where((board) {
      return board != CommunityBoardType.all;
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.pinkSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '관심 게시판을 선택해 주세요.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: boards.length,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 7);
              },
              itemBuilder: (context, index) {
                CommunityBoardType board = boards[index];

                bool selected = _favoriteBoards.contains(board);

                return FilterChip(
                  label: Text(board.label),
                  avatar: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: selected
                        ? context.colors.pinkStart
                        : context.colors.textSecondary,
                  ),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: _isPreferenceLoading
                      ? null
                      : (value) {
                          _toggleFavoriteBoard(board);
                        },
                  selectedColor: context.colors.pinkSoft,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: selected
                        ? context.colors.pinkStart
                        : context.colors.pinkSoft,
                  ),
                  labelStyle: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: CommunityBoardType.values.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          CommunityBoardType board = CommunityBoardType.values[index];

          bool selected = board == _selectedBoard;

          return ChoiceChip(
            label: Text(board.label),
            selected: selected,
            showCheckmark: false,
            onSelected: (value) {
              setState(() {
                _selectedBoard = board;
              });
            },
            selectedColor: context.colors.pinkStart,
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: BorderSide.none,
            labelStyle: TextStyle(
              color: selected
                  ? context.colors.onPrimary
                  : context.colors.textPrimary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCertificateChips(List<CommunityCertificateTag> certificates) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CertificateFilterChip(
            label: '자격증 전체',
            selected: _selectedCertificateId.isEmpty,
            onTap: () {
              setState(() {
                _selectedCertificateId = '';
              });
            },
          ),

          ...certificates.map((tag) {
            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: _CertificateFilterChip(
                label: '#${tag.certificateName}',
                selected: _selectedCertificateId == tag.certificateId,
                onTap: () {
                  setState(() {
                    _selectedCertificateId = tag.certificateId;
                  });
                },
              ),
            );
          }),
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
        return CommunityPostSort.values.map((sort) {
          return PopupMenuItem<CommunityPostSort>(
            value: sort,
            child: Text(sort.label),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedSort.label,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
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

class _CertificateFilterChip extends StatelessWidget {
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
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.lavender
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: context.colors.lavender),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? context.colors.textPrimary
                : context.colors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  final CommunityPost post;
  final Future<Map<String, dynamic>> writerProfileFuture;
  final VoidCallback onTap;

  const _CommunityPostCard({
    required this.post,
    required this.writerProfileFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AppCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BoardBadge(boardType: post.boardType),

                  const SizedBox(width: 7),

                  if (post.boardType == CommunityBoardType.question)
                    _StatusBadge(
                      label: _questionStatusLabel(post.questionStatus),
                      backgroundColor: context.colors.softBlue,
                    ),

                  if (post.boardType == CommunityBoardType.groupRecruit)
                    _StatusBadge(
                      label: _recruitStatusLabel(post.recruitStatus),
                      backgroundColor: context.colors.mint,
                    ),

                  const Spacer(),

                  if (post.hasAttachment)
                    Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: context.colors.textSecondary,
                    ),
                ],
              ),

              const SizedBox(height: 9),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          post.content.replaceAll(RegExp(r'\s+'), ' ').trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (post.thumbnailUrl.isNotEmpty) ...[
                    const SizedBox(width: 11),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        post.thumbnailUrl,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 68,
                            height: 68,
                            color: context.colors.pinkSoft,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),

              if (post.certificateTags.isNotEmpty) ...[
                const SizedBox(height: 8),

                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: post.certificateTags.take(3).map((tag) {
                    return Text(
                      '#${tag.certificateName}',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 11),

              SizedBox(
                width: double.infinity,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: writerProfileFuture,
                              builder: (context, snapshot) {
                                Map<String, dynamic> profile =
                                    snapshot.data ?? {};

                                String nickname =
                                    profile['nickname']?.toString().trim() ??
                                    '';

                                if (nickname.isEmpty || nickname == '사용자') {
                                  nickname = post.writerNickname.trim();
                                }

                                if (nickname.isEmpty) {
                                  nickname = '사용자';
                                }

                                return Text(
                                  nickname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (post.isCertifiedWriter) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: context.colors.pinkStart,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatCreatedAt(post.createdAt),
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PostCount(
                          icon: Icons.remove_red_eye_outlined,
                          value: post.viewCount,
                        ),
                        const SizedBox(width: 6),
                        _PostCount(
                          icon: Icons.chat_bubble_outline,
                          value: post.commentCount,
                        ),
                        const SizedBox(width: 6),
                        _PostCount(
                          icon: Icons.favorite_border,
                          value: post.likeCount,
                        ),
                        const SizedBox(width: 6),
                        _PostCount(
                          icon: Icons.bookmark_border,
                          value: post.bookmarkCount,
                        ),
                      ],
                    ),
                  ],
                ),
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

  const _BoardBadge({required this.boardType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.pinkSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        boardType.label,
        style: TextStyle(
          color: context.colors.textPrimary,
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

  const _StatusBadge({required this.label, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.textPrimary,
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

  const _PostCount({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.colors.textSecondary),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 10),
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

  Duration difference = DateTime.now().difference(dateTime);

  if (!difference.isNegative && difference.inMinutes < 1) {
    return '방금 전';
  }

  if (!difference.isNegative && difference.inHours < 1) {
    return '${difference.inMinutes}분 전';
  }

  if (!difference.isNegative && difference.inDays < 1) {
    return '${difference.inHours}시간 전';
  }

  if (!difference.isNegative && difference.inDays < 7) {
    return '${difference.inDays}일 전';
  }

  String month = dateTime.month.toString().padLeft(2, '0');

  String day = dateTime.day.toString().padLeft(2, '0');

  return '$month.$day';
}
