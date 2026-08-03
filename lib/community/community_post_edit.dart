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

class CommunityPostEditPage extends StatefulWidget {
  final CommunityPost post;
  final CommunityService? service;

  const CommunityPostEditPage({
    super.key,
    required this.post,
    this.service,
  });

  @override
  State<CommunityPostEditPage> createState() {
    return _CommunityPostEditPageState();
  }
}

class _CommunityPostEditPageState extends State<CommunityPostEditPage> {
  static const int _maxImageCount = 5;
  static const int _maxFileCount = 3;
  static const int _maxImageBytes = 10 * 1024 * 1024;
  static const int _maxFileBytes = 20 * 1024 * 1024;

  late final CommunityService _service;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<CommunityImageAttachment> _existingImages = [];
  final List<CommunityFileAttachment> _existingFiles = [];
  final List<PlatformFile> _newImages = [];
  final List<PlatformFile> _newFiles = [];

  late CommunityBoardType _selectedBoard;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
    _selectedBoard = widget.post.boardType;
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content);
    _existingImages.addAll(widget.post.imageAttachments);
    _existingFiles.addAll(widget.post.fileAttachments);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  int get _totalImageCount => _existingImages.length + _newImages.length;
  int get _totalFileCount => _existingFiles.length + _newFiles.length;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImages() async {
    if (_isSaving) {
      return;
    }

    int remaining = _maxImageCount - _totalImageCount;

    if (remaining <= 0) {
      _showMessage('사진은 최대 $_maxImageCount장까지 첨부할 수 있어요.');
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      if (_containsFile(_newImages, file) || _containsFile(accepted, file)) {
        continue;
      }

      accepted.add(file);
      if (accepted.length == remaining) {
        break;
      }
    }

    if (accepted.isNotEmpty) {
      setState(() {
        _newImages.addAll(accepted);
      });
    }
  }

  Future<void> _pickFiles() async {
    if (_isSaving) {
      return;
    }

    int remaining = _maxFileCount - _totalFileCount;

    if (remaining <= 0) {
      _showMessage('파일은 최대 $_maxFileCount개까지 첨부할 수 있어요.');
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
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
      if (_containsFile(_newFiles, file) || _containsFile(accepted, file)) {
        continue;
      }

      accepted.add(file);
      if (accepted.length == remaining) {
        break;
      }
    }

    if (accepted.isNotEmpty) {
      setState(() {
        _newFiles.addAll(accepted);
      });
    }
  }

  bool _containsFile(List<PlatformFile> files, PlatformFile target) {
    return files.any((file) {
      return file.name == target.name && file.size == target.size;
    });
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

    if (user == null || user.uid != widget.post.writerUid) {
      _showMessage('작성자만 게시글을 수정할 수 있어요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
    });

    List<String> newlyUploadedPaths = [];

    try {
      _AttachmentUploadResult uploaded = await _uploadNewAttachments(
        userUid: user.uid,
        uploadedPaths: newlyUploadedPaths,
      );

      List<Map<String, dynamic>> images = [
        ..._existingImages.map((image) => image.toMap()),
        ...uploaded.images,
      ];
      List<Map<String, dynamic>> files = [
        ..._existingFiles.map((file) => file.toMap()),
        ...uploaded.files,
      ];

      await _service.updatePost(
        postId: widget.post.id,
        boardType: _selectedBoard,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        writerUid: user.uid,
        imageAttachments: images,
        fileAttachments: files,
      );

      await _deleteRemovedAttachments();

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      await _deleteStoragePaths(newlyUploadedPaths);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      debugPrint('커뮤니티 게시글 수정 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('게시글을 수정하지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<_AttachmentUploadResult> _uploadNewAttachments({
    required String userUid,
    required List<String> uploadedPaths,
  }) async {
    List<Map<String, dynamic>> images = [];
    List<Map<String, dynamic>> files = [];
    FirebaseStorage storage = FirebaseStorage.instance;

    for (int index = 0; index < _newImages.length; index++) {
      PlatformFile file = _newImages[index];
      String path =
          'community/posts/${widget.post.id}/images/'
          '${DateTime.now().microsecondsSinceEpoch}_${index}_'
          '${_safeFileName(file.name)}';
      Reference reference = storage.ref(path);

      await reference.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _imageContentType(file.extension),
          customMetadata: {'uploaderUid': userUid},
        ),
      );

      uploadedPaths.add(path);
      images.add({'url': await reference.getDownloadURL(), 'path': path});
    }

    for (int index = 0; index < _newFiles.length; index++) {
      PlatformFile file = _newFiles[index];
      String path =
          'community/posts/${widget.post.id}/files/'
          '${DateTime.now().microsecondsSinceEpoch}_${index}_'
          '${_safeFileName(file.name)}';
      Reference reference = storage.ref(path);

      await reference.putData(
        file.bytes!,
        SettableMetadata(
          contentType: _fileContentType(file.extension),
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

    return _AttachmentUploadResult(images: images, files: files);
  }

  Future<void> _deleteRemovedAttachments() async {
    Set<String> remainingPaths = {
      ..._existingImages.map((image) => image.path),
      ..._existingFiles.map((file) => file.path),
    };
    List<String> removedPaths = [
      ...widget.post.imageAttachments.map((image) => image.path),
      ...widget.post.fileAttachments.map((file) => file.path),
    ].where((path) {
      return path.isNotEmpty && !remainingPaths.contains(path);
    }).toList();

    await _deleteStoragePaths(removedPaths);
  }

  Future<void> _deleteStoragePaths(List<String> paths) async {
    for (String path in paths) {
      if (path.isEmpty) {
        continue;
      }

      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (error) {
        // 이미 삭제됐거나 권한이 없는 파일은 다음 파일 정리를 계속합니다.
      }
    }
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9가-힣._-]'), '_');
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

  String _fileContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: const AppTopBar(title: '게시글 수정'),
        body: AppMainBackground(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
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
      backgroundColor: context.colors.pinkSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_rounded, color: context.colors.pinkStart, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '게시판, 제목, 내용과 첨부파일을 수정할 수 있어요.',
              style: TextStyle(
                color: context.colors.textPrimary,
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
            decoration: _inputDecoration(hintText: '게시판을 선택해 주세요.'),
            items: CommunityBoardType.values
                .where((board) => board != CommunityBoardType.all)
                .map((board) {
              return DropdownMenuItem<CommunityBoardType>(
                value: board,
                child: Text(board.label),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (board) {
              if (board != null) {
                setState(() {
                  _selectedBoard = board;
                });
              }
            },
          ),
          const SizedBox(height: 20),
          _buildFieldTitle('제목'),
          const SizedBox(height: 9),
          TextFormField(
            controller: _titleController,
            enabled: !_isSaving,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(hintText: '제목을 입력해 주세요.'),
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
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: _inputDecoration(hintText: '내용을 입력해 주세요.'),
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
          Row(
            children: [
              Expanded(child: _buildFieldTitle('첨부')),
              Text(
                '사진 $_totalImageCount/$_maxImageCount  ·  파일 $_totalFileCount/$_maxFileCount',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickImages,
                  icon: const Icon(Icons.image_outlined, size: 19),
                  label: const Text('사진 추가'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickFiles,
                  icon: const Icon(Icons.attach_file_rounded, size: 19),
                  label: const Text('파일 추가'),
                ),
              ),
            ],
          ),
          if (_totalImageCount > 0) ...[
            const SizedBox(height: 16),
            _buildImageAttachments(),
          ],
          if (_totalFileCount > 0) ...[
            const SizedBox(height: 14),
            _buildFileAttachments(),
          ],
        ],
      ),
    );
  }

  Widget _buildImageAttachments() {
    List<Widget> items = [];

    for (int index = 0; index < _existingImages.length; index++) {
      CommunityImageAttachment image = _existingImages[index];
      items.add(
        _AttachmentThumbnail(
          child: Image.network(
            image.url,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image_outlined);
            },
          ),
          onRemove: _isSaving
              ? null
              : () {
            setState(() {
              _existingImages.removeAt(index);
            });
          },
        ),
      );
    }

    for (int index = 0; index < _newImages.length; index++) {
      PlatformFile image = _newImages[index];
      items.add(
        _AttachmentThumbnail(
          child: Image.memory(
            image.bytes!,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
          ),
          onRemove: _isSaving
              ? null
              : () {
            setState(() {
              _newImages.removeAt(index);
            });
          },
        ),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: items);
  }

  Widget _buildFileAttachments() {
    List<Widget> items = [];

    for (int index = 0; index < _existingFiles.length; index++) {
      CommunityFileAttachment file = _existingFiles[index];
      items.add(
        _buildFileItem(
          name: file.name,
          onRemove: _isSaving
              ? null
              : () {
            setState(() {
              _existingFiles.removeAt(index);
            });
          },
        ),
      );
    }

    for (int index = 0; index < _newFiles.length; index++) {
      PlatformFile file = _newFiles[index];
      items.add(
        _buildFileItem(
          name: file.name,
          onRemove: _isSaving
              ? null
              : () {
            setState(() {
              _newFiles.removeAt(index);
            });
          },
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildFileItem({
    required String name,
    required VoidCallback? onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 5, 8),
      decoration: BoxDecoration(
        color: context.colors.softBlue,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 19,
            color: context.colors.pinkStart,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: '첨부 제거',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: context.colors.textSecondary,
        fontSize: 13,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.pinkSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.pinkSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.pinkStart, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.incorrect),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.incorrect),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _isSaving ? null : _savePost,
        style: FilledButton.styleFrom(
          backgroundColor: context.colors.pinkStart,
          foregroundColor: context.colors.onPrimary,
          disabledBackgroundColor: context.colors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isSaving
            ? SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.3,
            color: context.colors.onPrimary,
          ),
        )
            : const Text(
          '수정 완료',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

class _AttachmentThumbnail extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRemove;

  const _AttachmentThumbnail({
    required this.child,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 92, height: 92, child: child),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.close_rounded, size: 17),
            ),
          ),
        ),
      ],
    );
  }
}
