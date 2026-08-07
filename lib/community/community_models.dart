import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityBoardType {
  all,
  free,
  question,
  passReview,
  examReview,
  studyShare,
  bookReview,
  tip,
  groupRecruit,
}

extension CommunityBoardTypeX on CommunityBoardType {
  String get code {
    switch (this) {
      case CommunityBoardType.all:
        return 'ALL';
      case CommunityBoardType.free:
        return 'FREE';
      case CommunityBoardType.question:
        return 'QUESTION';
      case CommunityBoardType.passReview:
        return 'PASS_REVIEW';
      case CommunityBoardType.examReview:
        return 'EXAM_REVIEW';
      case CommunityBoardType.studyShare:
        return 'STUDY_SHARE';
      case CommunityBoardType.bookReview:
        return 'BOOK_REVIEW';
      case CommunityBoardType.tip:
        return 'TIP';
      case CommunityBoardType.groupRecruit:
        return 'GROUP_RECRUIT';
    }
  }

  String get label {
    switch (this) {
      case CommunityBoardType.all:
        return '전체';
      case CommunityBoardType.free:
        return '자유';
      case CommunityBoardType.question:
        return '질문';
      case CommunityBoardType.passReview:
        return '합격 후기';
      case CommunityBoardType.examReview:
        return '시험 후기';
      case CommunityBoardType.studyShare:
        return '학습 자료';
      case CommunityBoardType.bookReview:
        return '교재·인강';
      case CommunityBoardType.tip:
        return '학습 팁';
      case CommunityBoardType.groupRecruit:
        return '스터디 모집';
    }
  }

  static CommunityBoardType fromCode(String value) {
    for (CommunityBoardType type in CommunityBoardType.values) {
      if (type.code == value) {
        return type;
      }
    }
    return CommunityBoardType.free;
  }
}

enum CommunityPostSort { latest, views, likes, comments }

extension CommunityPostSortX on CommunityPostSort {
  String get label {
    switch (this) {
      case CommunityPostSort.latest:
        return '최신순';
      case CommunityPostSort.views:
        return '조회순';
      case CommunityPostSort.likes:
        return '좋아요순';
      case CommunityPostSort.comments:
        return '댓글순';
    }
  }
}

class CommunityCertificateTag {
  final String certificateId;
  final String certificateName;

  const CommunityCertificateTag({
    required this.certificateId,
    required this.certificateName,
  });

  factory CommunityCertificateTag.fromMap(Map<String, dynamic> data) {
    return CommunityCertificateTag(
      certificateId: data['certificateId']?.toString() ?? '',
      certificateName: data['certificateName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'certificateId': certificateId,
      'certificateName': certificateName,
    };
  }
}

class CommunityImageAttachment {
  final String url;
  final String path;

  const CommunityImageAttachment({
    required this.url,
    required this.path,
  });

  factory CommunityImageAttachment.fromMap(Map<String, dynamic> data) {
    return CommunityImageAttachment(
      url: data['url']?.toString() ?? '',
      path: data['path']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'url': url, 'path': path};
  }
}

class CommunityFileAttachment {
  final String name;
  final String url;
  final String path;

  const CommunityFileAttachment({
    required this.name,
    required this.url,
    required this.path,
  });

  factory CommunityFileAttachment.fromMap(Map<String, dynamic> data) {
    return CommunityFileAttachment(
      name: data['name']?.toString() ?? '첨부파일',
      url: data['url']?.toString() ?? '',
      path: data['path']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url, 'path': path};
  }
}

class CommunityPost {
  final String id;
  final CommunityBoardType boardType;
  final String title;
  final String content;
  final String writerUid;
  final String writerNickname;
  final String writerProfileImageUrl;
  final bool isCertifiedWriter;
  final List<CommunityCertificateTag> certificateTags;
  final List<CommunityImageAttachment> imageAttachments;
  final List<CommunityFileAttachment> fileAttachments;
  final int viewCount;
  final int commentCount;
  final int likeCount;
  final int bookmarkCount;
  final String questionStatus;
  final String recruitStatus;
  final String postStatus;
  final String visibility;
  final String studyGroupId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const CommunityPost({
    required this.id,
    required this.boardType,
    required this.title,
    required this.content,
    required this.writerUid,
    required this.writerNickname,
    required this.writerProfileImageUrl,
    required this.isCertifiedWriter,
    required this.certificateTags,
    required this.imageAttachments,
    required this.fileAttachments,
    required this.viewCount,
    required this.commentCount,
    required this.likeCount,
    required this.bookmarkCount,
    required this.questionStatus,
    required this.recruitStatus,
    required this.postStatus,
    required this.visibility,
    required this.studyGroupId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  bool get hasAttachment {
    return imageAttachments.isNotEmpty || fileAttachments.isNotEmpty;
  }

  String get thumbnailUrl {
    return imageAttachments.isEmpty ? '' : imageAttachments.first.url;
  }

  factory CommunityPost.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    Map<String, dynamic> data = document.data();

    return CommunityPost(
      id: document.id,
      boardType: CommunityBoardTypeX.fromCode(
        data['boardType']?.toString() ?? 'FREE',
      ),
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      writerUid: data['writerUid']?.toString() ?? '',
      writerNickname: data['writerNickname']?.toString() ?? '사용자',
      writerProfileImageUrl:
      data['writerProfileImageUrl']?.toString() ?? '',
      isCertifiedWriter: data['isCertifiedWriter'] == true,
      certificateTags: _readCertificateTags(data['certificateTags']),
      imageAttachments: _readImageAttachments(data['imageAttachments']),
      fileAttachments: _readFileAttachments(data['fileAttachments']),
      viewCount: _readInt(data['viewCount']),
      commentCount: _readInt(data['commentCount']),
      likeCount: _readInt(data['likeCount']),
      bookmarkCount: _readInt(data['bookmarkCount']),
      questionStatus: data['questionStatus']?.toString() ?? '',
      recruitStatus: data['recruitStatus']?.toString() ?? '',
      postStatus: data['postStatus']?.toString() ?? 'NORMAL',
      visibility: data['visibility']?.toString() ?? 'PUBLIC',
      studyGroupId: data['studyGroupId']?.toString() ?? '',
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      deletedAt: _readDateTime(data['deletedAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static List<CommunityCertificateTag> _readCertificateTags(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.whereType<Map>().map((item) {
      return CommunityCertificateTag.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static List<CommunityImageAttachment> _readImageAttachments(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.whereType<Map>().map((item) {
      return CommunityImageAttachment.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static List<CommunityFileAttachment> _readFileAttachments(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.whereType<Map>().map((item) {
      return CommunityFileAttachment.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }
}
