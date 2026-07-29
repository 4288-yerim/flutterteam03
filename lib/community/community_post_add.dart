import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';
import 'community_models.dart';
import 'community_service.dart';

extension _CommunityAddColors on BuildContext {
  AppColors get communityColors {
    return Theme.of(this).extension<AppColors>() ?? AppColors.light;
  }
}

class CommunityPostAddPage extends StatefulWidget {
  final CommunityService? service;

  const CommunityPostAddPage({
    super.key,
    this.service,
  });

  @override
  State<CommunityPostAddPage> createState() {
    return _CommunityPostAddPageState();
  }
}

class _CommunityPostAddPageState
    extends State<CommunityPostAddPage> {
  static const int _maxImageCount = 5;
  static const int _maxFileCount = 3;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxFileBytes = 20 * 1024 * 1024;

  late final CommunityService _service;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController =
  TextEditingController();
  final TextEditingController _contentController =
  TextEditingController();
  final TextEditingController _certificateController =
  TextEditingController();

  final List<PlatformFile> _selectedImages = [];
  final List<PlatformFile> _selectedFiles = [];

  CommunityBoardType _selectedBoard = CommunityBoardType.free;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _certificateController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isSaving) {
      return;
    }

    int remaining = _maxImageCount - _selectedImages.length;

    if (remaining <= 0) {
      _showMessage('사진은 최대 $_maxImageCount장까지 첨부할 수 있어요.');
      return;
    }

    FilePickerResult? result =
    await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (!mounted || result == null) {
      return;
    }

    List<PlatformFile> accepted = [];

    for (PlatformFile file in result.files) {
      if (file.bytes == null) {
        continue;
      }

      if (file.size > _maxImageBytes) {
        _showMessage('${file.name}은 10MB를 초과해 제외했어요.');
        continue;
      }

      if (_containsFile(_selectedImages, file) ||
          _containsFile(accepted, file)) {
        continue;
      }

      accepted.add(file);

      if (accepted.length == remaining) {
        break;
      }
    }

    if (accepted.isEmpty) {
      return;
    }

    setState(() {
      _selectedImages.addAll(accepted);
    });
  }

  Future<void> _pickFiles() async {
    if (_isSaving) {
      return;
    }

    int remaining = _maxFileCount - _selectedFiles.length;

    if (remaining <= 0) {
      _showMessage('파일은 최대 $_maxFileCount개까지 첨부할 수 있어요.');
      return;
    }

    FilePickerResult? result =
    await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'hwp',
        'hwpx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'zip',
      ],
      allowMultiple: true,
      withData: true,
    );

    if (!mounted || result == null) {
      return;
    }

    List<PlatformFile> accepted = [];

    for (PlatformFile file in result.files) {
      if (file.bytes == null) {
        continue;
      }

      if (file.size > _maxFileBytes) {
        _showMessage('${file.name}은 20MB를 초과해 제외했어요.');
        continue;
      }

      if (_containsFile(_selectedFiles, file) ||
          _containsFile(accepted, file)) {
        continue;
      }

      accepted.add(file);

      if (accepted.length == remaining) {
        break;
      }
    }

    if (accepted.isEmpty) {
      return;
    }

    setState(() {
      _selectedFiles.addAll(accepted);
    });
  }

  bool _containsFile(
      List<PlatformFile> files,
      PlatformFile target,
      ) {
    return files.any((file) {
      return file.name == target.name && file.size == target.size;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _savePost() async {
    if (_isSaving) {
      return;
    }

    bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 후 게시글을 작성할 수 있어요.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    String nickname = user.displayName?.trim() ?? '';

    if (nickname.isEmpty) {
      String email = user.email?.trim() ?? '';

      nickname = email.contains('@')
          ? email.split('@').first
          : '사용자';
    }

    String postId = _service.createPostId();
    List<String> uploadedPaths = [];

    try {
      _AttachmentUploadResult attachments =
      await _uploadAttachments(
        postId: postId,
        userUid: user.uid,
        uploadedPaths: uploadedPaths,
      );

      await _service.addPost(
        postId: postId,
        boardType: _selectedBoard,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        writerUid: user.uid,
        writerNickname: nickname,
        writerProfileImageUrl: user.photoURL ?? '',
        isCertifiedWriter: false,
        certificateTags: _readCertificateTags(),
        imageAttachments: attachments.images,
        fileAttachments: attachments.files,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, postId);
    } catch (error, stackTrace) {
      await _deleteUploadedFiles(uploadedPaths);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      debugPrint('커뮤니티 게시글 저장 실패: $error');
      debugPrintStack(stackTrace: stackTrace);

      String message =
          '게시글을 저장하지 못했어요. 다시 시도해 주세요.';

      if (error is FirebaseException) {
        if (error.code == 'unauthorized' ||
            error.code == 'permission-denied') {
          message = '사진 또는 파일 업로드 권한이 없어요. '
              'Firebase 규칙을 확인해 주세요.';
        } else if (error.code == 'retry-limit-exceeded') {
          message = '인터넷 연결이 불안정해요. '
              '잠시 후 다시 시도해 주세요.';
        }
      }

      _showMessage(message);
    }
  }

  List<CommunityCertificateTag> _readCertificateTags() {
    List<String> names = _certificateController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .take(3)
        .toList();

    return names.map((name) {
      String certificateId = name
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '-');

      return CommunityCertificateTag(
        certificateId: certificateId,
        certificateName: name,
      );
    }).toList();
  }

  Future<_AttachmentUploadResult> _uploadAttachments({
    required String postId,
    required String userUid,
    required List<String> uploadedPaths,
  }) async {
    List<Map<String, dynamic>> images = [];
    List<Map<String, dynamic>> files = [];
    FirebaseStorage storage = FirebaseStorage.instance;

    for (int index = 0;
    index < _selectedImages.length;
    index++) {
      PlatformFile file = _selectedImages[index];
      String path =
          'community/posts/$postId/images/'
          '${DateTime.now().microsecondsSinceEpoch}_${index}_'
          '${_safeFileName(file.name)}';

      Reference reference = storage.ref(path);

      await reference.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _imageContentType(file.extension),
          customMetadata: {
            'uploaderUid': userUid,
          },
        ),
      );

      uploadedPaths.add(path);

      images.add({
        'url': await reference.getDownloadURL(),
        'path': path,
      });
    }

    for (int index = 0;
    index < _selectedFiles.length;
    index++) {
      PlatformFile file = _selectedFiles[index];
      String path =
          'community/posts/$postId/files/'
          '${DateTime.now().microsecondsSinceEpoch}_${index}_'
          '${_safeFileName(file.name)}';

      Reference reference = storage.ref(path);

      await reference.putData(
        file.bytes!,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {
            'originalName': file.name,
            'uploaderUid': userUid,
          },
        ),
      );

      uploadedPaths.add(path);

      files.add({
        'name': file.name,
        'url': await reference.getDownloadURL(),
        'path': path,
      });
    }

    return _AttachmentUploadResult(
      images: images,
      files: files,
    );
  }

  Future<void> _deleteUploadedFiles(
      List<String> uploadedPaths,
      ) async {
    for (String path in uploadedPaths) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (error) {
        // 저장 실패 정리 중 일부 파일이 이미 없어도 계속 진행합니다.
      }
    }
  }

  String _safeFileName(String name) {
    return name.replaceAll(
      RegExp(r'[^a-zA-Z0-9가-힣._-]'),
      '_',
    );
  }

  String _imageContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: const AppTopBar(
          title: '게시글 작성',
        ),
        body: AppMainBackground(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                4,
                20,
                40,
              ),
              children: [
                _buildGuideCard(),
                const SizedBox(height: 16),
                _buildPostForm(),
                const SizedBox(height: 16),
                _buildAttachmentCard(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.communityColors.pinkSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: context.communityColors.pinkStart,
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '자격증 태그와 학습 자료를 함께 올리면 '
                  '필요한 사람에게 글이 더 잘 보여요.',
              style: TextStyle(
                color: context.communityColors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostForm() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle('게시판'),
          const SizedBox(height: 9),
          DropdownButtonFormField<CommunityBoardType>(
            value: _selectedBoard,
            isExpanded: true,
            decoration: _inputDecoration(
              hintText: '게시판을 선택해 주세요.',
            ),
            items: CommunityBoardType.values
                .where((board) {
              return board != CommunityBoardType.all;
            }).map((board) {
              return DropdownMenuItem<CommunityBoardType>(
                value: board,
                child: Text(board.label),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (board) {
              if (board == null) {
                return;
              }

              setState(() {
                _selectedBoard = board;
              });
            },
          ),
          const SizedBox(height: 20),
          _buildFieldTitle('관련 자격증 (선택)'),
          const SizedBox(height: 5),
          Text(
            '쉼표로 구분해 최대 3개까지 입력해 주세요.',
            style: TextStyle(
              color: context.communityColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _certificateController,
            enabled: !_isSaving,
            maxLength: 80,
            buildCounter: _buildInsideCounter,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: '예: 정보처리기사, 컴퓨터활용능력',
              hasInsideCounter: true,
            ),
            validator: (value) {
              int count = (value ?? '')
                  .split(',')
                  .map((name) => name.trim())
                  .where((name) => name.isNotEmpty)
                  .toSet()
                  .length;

              if (count > 3) {
                return '자격증 태그는 최대 3개까지 입력해 주세요.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildFieldTitle('제목'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _titleController,
            enabled: !_isSaving,
            maxLength: 60,
            buildCounter: _buildInsideCounter,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: '제목을 입력해 주세요.',
              hasInsideCounter: true,
            ),
            validator: (value) {
              String title = value?.trim() ?? '';

              if (title.isEmpty) {
                return '제목을 입력해 주세요.';
              }

              if (title.length < 2) {
                return '제목을 2자 이상 입력해 주세요.';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildFieldTitle('내용'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _contentController,
            enabled: !_isSaving,
            minLines: 10,
            maxLines: 16,
            maxLength: 3000,
            buildCounter: _buildInsideCounter,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: _inputDecoration(
              hintText: '내용을 입력해 주세요.',
              hasInsideCounter: true,
            ),
            validator: (value) {
              String content = value?.trim() ?? '';

              if (content.isEmpty) {
                return '내용을 입력해 주세요.';
              }

              if (content.length < 5) {
                return '내용을 5자 이상 입력해 주세요.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldTitle('첨부'),
          const SizedBox(height: 5),
          Text(
            '사진은 최대 5장·각 10MB, 파일은 최대 3개·각 20MB예요.',
            style: TextStyle(
              color: context.communityColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickImages,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    '사진 ${_selectedImages.length}/$_maxImageCount',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickFiles,
                  icon: const Icon(
                    Icons.attach_file_rounded,
                  ),
                  label: Text(
                    '파일 ${_selectedFiles.length}/$_maxFileCount',
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 15),
            _buildSelectedImages(),
          ],
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 15),
            _buildSelectedFiles(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedImages() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 9);
        },
        itemBuilder: (context, index) {
          PlatformFile file = _selectedImages[index];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  file.bytes!,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: _isSaving
                      ? null
                      : () {
                    setState(() {
                      _selectedImages.removeAt(index);
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedFiles() {
    return Column(
      children: List.generate(
        _selectedFiles.length,
            (index) {
          PlatformFile file = _selectedFiles[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(
              left: 12,
              top: 7,
              bottom: 7,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                          context.communityColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(file.size),
                        style: TextStyle(
                          color:
                          context.communityColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '첨부 삭제',
                  onPressed: _isSaving
                      ? null
                      : () {
                    setState(() {
                      _selectedFiles.removeAt(index);
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 19,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }

    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }

  Widget _buildFieldTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.communityColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    bool hasInsideCounter = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: context.communityColors.textSecondary,
        fontSize: 13,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: EdgeInsets.fromLTRB(
        14,
        14,
        14,
        hasInsideCounter ? 32 : 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkSoft,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkSoft,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.communityColors.pinkStart,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }

  Widget? _buildInsideCounter(
      BuildContext context, {
        required int currentLength,
        required bool isFocused,
        required int? maxLength,
      }) {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.only(right: 3),
        child: Text(
          '$currentLength/${maxLength ?? 0}',
          style: TextStyle(
            color: context
                .communityColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _isSaving ? null : _savePost,
        style: FilledButton.styleFrom(
          backgroundColor: context.communityColors.pinkStart,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          context.communityColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isSaving
            ? const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text('업로드 중'),
          ],
        )
            : const Text(
          '게시글 등록',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AttachmentUploadResult {
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> files;

  const _AttachmentUploadResult({
    required this.images,
    required this.files,
  });
}
