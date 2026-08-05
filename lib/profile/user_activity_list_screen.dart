import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../community/community_post_detail.dart';
import '../study/study_detail.dart';
import '../services/user_profile_cache_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_state_views.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/cached_user_profile_builder.dart';
import 'user_profile_screen.dart';

enum UserActivityType { posts, comments, friends, studies }

class UserActivityListScreen extends StatefulWidget {
  final String userUid;
  final String nickname;
  final UserActivityType type;

  const UserActivityListScreen({
    super.key,
    required this.userUid,
    required this.nickname,
    required this.type,
  });

  @override
  State<UserActivityListScreen> createState() => _UserActivityListScreenState();
}

class _UserActivityListScreenState extends State<UserActivityListScreen> {
  bool _isLoading = true;
  bool _isPrivate = false;
  bool _hasError = false;
  List<_ActivityListItem> _items = const [];

  String get _typeLabel {
    switch (widget.type) {
      case UserActivityType.posts:
        return '쓴 글';
      case UserActivityType.comments:
        return '댓글';
      case UserActivityType.friends:
        return '친구';
      case UserActivityType.studies:
        return '참여 스터디';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      if (!await _canViewActivity()) {
        if (!mounted) return;
        setState(() {
          _isPrivate = true;
          _isLoading = false;
        });
        return;
      }

      final List<_ActivityListItem> items;
      switch (widget.type) {
        case UserActivityType.posts:
          items = await _loadPosts();
        case UserActivityType.comments:
          items = await _loadComments();
        case UserActivityType.friends:
          items = await _loadFriends();
        case UserActivityType.studies:
          items = await _loadStudies();
      }

      if (widget.type == UserActivityType.friends) {
        items.sort((a, b) => a.title.compareTo(b.title));
      } else {
        items.sort((a, b) => b.sortValue.compareTo(a.sortValue));
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _isPrivate = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<bool> _canViewActivity() async {
    if (FirebaseAuth.instance.currentUser?.uid == widget.userUid) return true;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get();
      final value = snapshot.data()?['profileActivityPublic'];
      return value is bool ? value : true;
    } catch (_) {
      return false;
    }
  }

  Future<List<_ActivityListItem>> _loadPosts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('writerUid', isEqualTo: widget.userUid)
        .get();

    return snapshot.docs
        .where((document) {
          final data = document.data();
          return _isPublicPost(data);
        })
        .map((document) {
          final data = document.data();
          return _ActivityListItem(
            id: document.id,
            title: _text(data['title'], '제목 없는 글'),
            subtitle: _text(data['content'], '작성한 글입니다.'),
            sortValue: _milliseconds(data['createdAt']),
            data: data,
          );
        })
        .toList();
  }

  Future<List<_ActivityListItem>> _loadComments() async {
    final posts = await FirebaseFirestore.instance
        .collection('posts')
        .where('postStatus', isEqualTo: 'NORMAL')
        .where('visibility', isEqualTo: 'PUBLIC')
        .get();
    final items = <_ActivityListItem>[];

    for (final post in posts.docs) {
      if (!_isPublicPost(post.data())) continue;
      final comments = await post.reference
          .collection('comments')
          .where('commentStatus', isEqualTo: 'NORMAL')
          .get();
      for (final comment in comments.docs) {
        final data = comment.data();
        if (data['writerUid']?.toString() != widget.userUid ||
            data['deletedAt'] != null) {
          continue;
        }
        items.add(
          _ActivityListItem(
            id: post.id,
            title: _text(post.data()['title'], '제목 없는 글'),
            subtitle: _text(data['content'], '작성한 댓글입니다.'),
            sortValue: _milliseconds(data['createdAt']),
            data: post.data(),
          ),
        );
      }
    }
    return items;
  }

  Future<List<_ActivityListItem>> _loadFriends() async {
    final snapshots = await Future.wait([
      FirebaseFirestore.instance
          .collection('friendRequests')
          .where('senderUid', isEqualTo: widget.userUid)
          .get(),
      FirebaseFirestore.instance
          .collection('friendRequests')
          .where('receiverUid', isEqualTo: widget.userUid)
          .get(),
    ]);
    final friendUids = <String>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        final data = document.data();
        if (data['status']?.toString().toUpperCase() != 'ACCEPTED') continue;
        final senderUid = data['senderUid']?.toString() ?? '';
        final receiverUid = data['receiverUid']?.toString() ?? '';
        final friendUid = senderUid == widget.userUid ? receiverUid : senderUid;
        if (friendUid.isNotEmpty) friendUids.add(friendUid);
      }
    }

    final items = <_ActivityListItem>[];
    for (final uid in friendUids) {
      final profile = await UserProfileCacheService.instance.getProfile(uid);
      if (profile == null || profile.isDeleted) continue;
      final data = <String, dynamic>{
        'nickname': profile.nickname,
        'bio': profile.introduction,
        'profileImageUrl': profile.profileImageUrl,
      };
      items.add(
        _ActivityListItem(
          id: uid,
          title: _text(data['nickname'], '닉네임 없음'),
          subtitle: _text(data['bio'], '등록된 소개가 없습니다.'),
          imageUrl: _text(data['profileImageUrl'], ''),
          sortValue: _text(
            data['nickname'],
            '',
          ).codeUnits.fold(0, (a, b) => a + b),
          data: data,
        ),
      );
    }
    return items;
  }

  Future<List<_ActivityListItem>> _loadStudies() async {
    final groups = await FirebaseFirestore.instance
        .collection('studyGroups')
        .get();
    final items = <_ActivityListItem>[];
    for (final group in groups.docs) {
      final member = await group.reference
          .collection('members')
          .doc(widget.userUid)
          .get();
      if (!member.exists ||
          member.data()?['status']?.toString().toUpperCase() != 'ACTIVE') {
        continue;
      }
      final data = group.data();
      items.add(
        _ActivityListItem(
          id: group.id,
          title: _text(data['groupName'], '스터디'),
          subtitle: _text(data['certificateName'], '공통 스터디'),
          sortValue: _milliseconds(data['createdAt']),
          data: data,
        ),
      );
    }
    return items;
  }

  bool _isPublicPost(Map<String, dynamic> data) {
    final status = (data['postStatus']?.toString() ?? 'NORMAL').toUpperCase();
    final visibility = (data['visibility']?.toString() ?? 'PUBLIC')
        .toUpperCase();
    return status == 'NORMAL' &&
        visibility == 'PUBLIC' &&
        data['deletedAt'] == null;
  }

  int _milliseconds(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _openItem(_ActivityListItem item) {
    Widget page;
    switch (widget.type) {
      case UserActivityType.posts:
      case UserActivityType.comments:
        page = CommunityPostDetailPage(postId: item.id);
      case UserActivityType.friends:
        page = UserProfileScreen(userUid: item.id);
      case UserActivityType.studies:
        page = StudyDetailPage(studyId: item.id, studyData: item.data);
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return CachedNicknameBuilder(
      uid: widget.userUid,
      fallback: widget.nickname,
      builder: (context, nickname) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppTopBar(title: '$nickname님의 $_typeLabel'),
          body: AppMainBackground(child: _buildBody()),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const AppLoadingView(message: '활동 기록을 불러오는 중입니다.');
    if (_isPrivate) {
      return const AppEmptyView(
        message: '비공개 활동입니다.',
        description: '사용자가 프로필 활동을 비공개로 설정했습니다.',
      );
    }
    if (_hasError) {
      return AppErrorView(message: '활동 기록을 불러오지 못했습니다.', onRetryPressed: _load);
    }
    if (_items.isEmpty) return AppEmptyView(message: '$_typeLabel 기록이 없습니다.');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _items[index];
        final isMe =
            widget.type == UserActivityType.friends &&
            item.id == FirebaseAuth.instance.currentUser?.uid;
        return AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            onTap: isMe ? null : () => _openItem(item),
            leading: _leading(item),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            subtitle: Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            trailing: isMe
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.pinkSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.colors.pinkBorder),
                    ),
                    child: Text(
                      '나',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.pinkDeep,
                      ),
                    ),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                  ),
          ),
        );
      },
    );
  }

  Widget _leading(_ActivityListItem item) {
    if (widget.type == UserActivityType.friends) {
      return CircleAvatar(
        backgroundColor: context.colors.pinkSoft,
        backgroundImage: item.imageUrl.isEmpty
            ? null
            : NetworkImage(item.imageUrl),
        child: item.imageUrl.isEmpty
            ? Icon(Icons.person_outline_rounded, color: context.colors.pinkDeep)
            : null,
      );
    }
    final icon = switch (widget.type) {
      UserActivityType.posts => Icons.article_outlined,
      UserActivityType.comments => Icons.chat_bubble_outline_rounded,
      UserActivityType.friends => Icons.person_outline_rounded,
      UserActivityType.studies => Icons.groups_outlined,
    };
    return CircleAvatar(
      backgroundColor: context.colors.pinkSoft,
      child: Icon(icon, color: context.colors.pinkDeep),
    );
  }
}

class _ActivityListItem {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int sortValue;
  final Map<String, dynamic> data;

  const _ActivityListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sortValue,
    required this.data,
    this.imageUrl = '',
  });
}
