import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileSummary {
  const UserProfileSummary({
    required this.uid,
    required this.nickname,
    required this.profileImageUrl,
    required this.introduction,
    required this.status,
  });

  final String uid;
  final String nickname;
  final String profileImageUrl;
  final String introduction;
  final String status;

  bool get isDeleted => status == 'DELETED';

  UserProfileSummary copyWith({String? nickname}) {
    return UserProfileSummary(
      uid: uid,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl,
      introduction: introduction,
      status: status,
    );
  }

  factory UserProfileSummary.fromData(String uid, Map<String, dynamic> data) {
    return UserProfileSummary(
      uid: uid,
      nickname: _firstText(data, const [
        'nickname',
        'nickName',
        'userNickname',
        'name',
        'displayName',
      ]),
      profileImageUrl: _firstText(data, const [
        'profileImageUrl',
        'profileUrl',
        'photoUrl',
        'photoURL',
      ]),
      introduction: _firstText(data, const ['introduction', 'bio']),
      status: data['status']?.toString().trim().toUpperCase() ?? '',
    );
  }

  static String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final String value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }

    return '';
  }
}

class UserProfileCacheService {
  UserProfileCacheService({
    FirebaseFirestore? firestore,
    this.cacheDuration = const Duration(minutes: 30),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static final UserProfileCacheService instance = UserProfileCacheService();

  final FirebaseFirestore _firestore;
  final Duration cacheDuration;
  final Map<String, _CachedUserProfile> _cache = {};
  final Map<String, Future<UserProfileSummary?>> _pendingRequests = {};

  Future<UserProfileSummary?> getProfile(
    String uid, {
    bool forceRefresh = false,
  }) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Future<UserProfileSummary?>.value(null);
    }

    if (!forceRefresh) {
      final _CachedUserProfile? cached = _cache[normalizedUid];
      if (cached != null && !cached.isExpired(cacheDuration)) {
        return Future<UserProfileSummary?>.value(cached.profile);
      }
    } else {
      _cache.remove(normalizedUid);
    }

    return _pendingRequests.putIfAbsent(normalizedUid, () async {
      try {
        final UserProfileSummary? profile = await _loadProfile(normalizedUid);
        _cache[normalizedUid] = _CachedUserProfile(profile);
        return profile;
      } finally {
        _pendingRequests.remove(normalizedUid);
      }
    });
  }

  Future<String> resolveNickname({
    required String uid,
    String fallback = '사용자',
    bool forceRefresh = false,
  }) async {
    final UserProfileSummary? profile = await getProfile(
      uid,
      forceRefresh: forceRefresh,
    );

    if (profile?.isDeleted == true) {
      return '탈퇴한 사용자';
    }

    final String currentNickname = profile?.nickname.trim() ?? '';
    if (currentNickname.isNotEmpty) {
      return currentNickname;
    }

    final String savedNickname = fallback.trim();
    return savedNickname.isNotEmpty ? savedNickname : '사용자';
  }

  void updateNickname(String uid, String nickname) {
    final String normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return;
    }

    final UserProfileSummary? cached = _cache[normalizedUid]?.profile;
    if (cached == null) {
      _cache.remove(normalizedUid);
      return;
    }

    _cache[normalizedUid] = _CachedUserProfile(
      cached.copyWith(nickname: nickname.trim()),
    );
  }

  void invalidate(String uid) {
    _cache.remove(uid.trim());
  }

  void invalidateAll(Iterable<String> uids) {
    for (final String uid in uids) {
      invalidate(uid);
    }
  }

  Future<UserProfileSummary?> _loadProfile(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> directSnapshot =
        await _firestore.collection('users').doc(uid).get();

    if (directSnapshot.exists) {
      return UserProfileSummary.fromData(
        uid,
        directSnapshot.data() ?? <String, dynamic>{},
      );
    }

    final QuerySnapshot<Map<String, dynamic>> legacySnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (legacySnapshot.docs.isEmpty) {
      return null;
    }

    return UserProfileSummary.fromData(uid, legacySnapshot.docs.first.data());
  }
}

class _CachedUserProfile {
  _CachedUserProfile(this.profile) : cachedAt = DateTime.now();

  final UserProfileSummary? profile;
  final DateTime cachedAt;

  bool isExpired(Duration duration) {
    return DateTime.now().difference(cachedAt) >= duration;
  }
}
