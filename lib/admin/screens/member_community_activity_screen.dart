import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../community/community_post_detail.dart';
import '../../widgets/app_main_background.dart';
import '../services/admin_member_service.dart';
import '../widgets/member_community_activity_widgets.dart';

class MemberCommunityActivityScreen extends StatefulWidget {
  const MemberCommunityActivityScreen({
    super.key,
    required this.memberNickname,
    required this.initialType,
    required this.posts,
    required this.comments,
  });

  final String memberNickname;
  final AdminCommunityActivityType initialType;
  final List<AdminCommunityActivity> posts;
  final List<AdminCommunityActivity> comments;

  @override
  State<MemberCommunityActivityScreen> createState() =>
      _MemberCommunityActivityScreenState();
}

class _MemberCommunityActivityScreenState
    extends State<MemberCommunityActivityScreen> {
  String _selectedBoard = 'ALL';

  List<AdminCommunityActivity> get _activities =>
      widget.initialType == AdminCommunityActivityType.post
      ? widget.posts
      : widget.comments;

  @override
  Widget build(BuildContext context) {
    final isPost = widget.initialType == AdminCommunityActivityType.post;
    final filtered = _selectedBoard == 'ALL'
        ? _activities
        : _activities
              .where((activity) => activity.boardType == _selectedBoard)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPost ? '작성한 글' : '작성한 댓글',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppMainBackground(
        child: Column(
          children: [
            AdminCommunityCategoryTabs(
              activities: _activities,
              selectedBoard: _selectedBoard,
              onSelected: (board) => setState(() => _selectedBoard = board),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        isPost ? '작성한 게시글이 없습니다.' : '작성한 댓글이 없습니다.',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final activity = filtered[index];
                        return AdminCommunityActivityTile(
                          activity: activity,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPostDetailPage(
                                postId: activity.postId,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
