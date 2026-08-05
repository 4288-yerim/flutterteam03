import 'package:flutter/material.dart';

import '../services/user_profile_cache_service.dart';

typedef CachedUserProfileWidgetBuilder =
    Widget Function(BuildContext context, UserProfileSummary? profile);

class CachedUserProfileBuilder extends StatelessWidget {
  const CachedUserProfileBuilder({
    super.key,
    required this.uid,
    required this.builder,
    this.forceRefresh = false,
  });

  final String uid;
  final CachedUserProfileWidgetBuilder builder;
  final bool forceRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileSummary?>(
      future: UserProfileCacheService.instance.getProfile(
        uid,
        forceRefresh: forceRefresh,
      ),
      builder: (context, snapshot) => builder(context, snapshot.data),
    );
  }
}

class CachedNicknameBuilder extends StatelessWidget {
  const CachedNicknameBuilder({
    super.key,
    required this.uid,
    required this.builder,
    this.fallback = '사용자',
    this.forceRefresh = false,
  });

  final String uid;
  final String fallback;
  final Widget Function(BuildContext context, String nickname) builder;
  final bool forceRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserProfileCacheService.instance.resolveNickname(
        uid: uid,
        fallback: fallback,
        forceRefresh: forceRefresh,
      ),
      initialData: fallback.trim().isNotEmpty ? fallback.trim() : '사용자',
      builder: (context, snapshot) {
        return builder(context, snapshot.data ?? '사용자');
      },
    );
  }
}

class CachedNicknameText extends StatelessWidget {
  const CachedNicknameText({
    super.key,
    required this.uid,
    this.fallback = '사용자',
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String uid;
  final String fallback;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return CachedNicknameBuilder(
      uid: uid,
      fallback: fallback,
      builder: (context, nickname) {
        return Text(
          '$prefix$nickname$suffix',
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
        );
      },
    );
  }
}
