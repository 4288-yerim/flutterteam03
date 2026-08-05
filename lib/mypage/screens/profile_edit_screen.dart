import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../services/user_profile_cache_service.dart';
import '../../utils/nickname_validator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_main_background.dart';
import '../../widgets/app_top_bar.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _loginIdController = TextEditingController();

  final TextEditingController _nicknameController = TextEditingController();

  final TextEditingController _introductionController = TextEditingController();

  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _nicknameController.dispose();
    _introductionController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppTopBar(
        title: '프로필 수정',
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: context.colors.textPrimary,
          ),
        ),
      ),

      body: AppMainBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileImageSection(),
                      const SizedBox(height: 20),

                      _buildAccountInfoCard(),
                      const SizedBox(height: 20),

                      _buildIntroductionCard(),
                      const SizedBox(height: 28),

                      AppButton(
                        text: _isSaving ? '저장 중...' : '변경사항 저장',
                        type: _isSaving
                            ? AppButtonType.gray
                            : AppButtonType.primaryPink,
                        onPressed: _isSaving ? null : _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.pinkSoft,
                  image:
                      _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 56,
                        color: context.colors.pinkStart,
                      )
                    : null,
              ),

              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _changeProfileImage,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.pinkStart,
                      border: Border.all(
                        color: context.colors.onPrimary,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 17,
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isUploadingImage ? null : _changeProfileImage,
            child: Text(
              _isUploadingImage ? '사진 변경 중...' : '프로필 사진 변경',
              style: TextStyle(
                color: context.colors.pinkStart,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계정 정보',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          _buildLabel('이메일'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginIdController,
            readOnly: true,
            decoration: _inputDecoration(
              hintText: '이메일',
              prefixIcon: Icons.person_outline,
              isReadOnly: true,
            ),
          ),
          const SizedBox(height: 18),

          _buildLabel('닉네임'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nicknameController,
            maxLength: NicknameValidator.maxLength,
            decoration: _inputDecoration(
              hintText: '닉네임을 입력해 주세요.',
              prefixIcon: Icons.badge_outlined,
            ),
            validator: NicknameValidator.validate,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '자기소개',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다른 사용자에게 표시될 간단한 소개를 작성해 주세요.',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _introductionController,
            minLines: 4,
            maxLines: 6,
            maxLength: 100,
            keyboardType: TextInputType.multiline,
            decoration: _inputDecoration(
              hintText: '자기소개를 입력해 주세요.',
              prefixIcon: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: isReadOnly
          ? context.colors.surfaceMuted
          : context.colors.surface,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: context.colors.textSecondary),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.pinkStart, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.incorrect),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.colors.incorrect, width: 1.5),
      ),
    );
  }

  void _changeProfileImage() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),

                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: context.colors.pinkStart,
                  ),
                  title: const Text('앨범에서 선택'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _pickAndUploadProfileImage();
                  },
                ),

                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.colors.incorrect,
                  ),
                  title: const Text('기본 이미지로 변경'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _resetProfileImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfileImage() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    try {
      final XFile? pickedImage = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        return;
      }

      if (mounted) {
        setState(() {
          _isUploadingImage = true;
        });
      }

      final String path = 'profile_images/${currentUser.uid}.jpg';
      final Reference imageReference = FirebaseStorage.instance.ref().child(
        path,
      );

      await imageReference.putFile(File(pickedImage.path));
      final String imageUrl = await imageReference.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'profileImageUrl': imageUrl,
            'profileImagePath': path,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        // 같은 Storage 경로에 덮어써도 캐시가 남지 않도록 값을 갱신합니다.
        _profileImageUrl =
            '$imageUrl&updated=${DateTime.now().millisecondsSinceEpoch}';
      });

      _showMessage('프로필 사진이 변경되었습니다.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '프로필 사진 변경에 실패했습니다.';

      if (error.code == 'permission-denied' || error.code == 'unauthorized') {
        message = '프로필 사진을 변경할 권한이 없습니다.';
      }

      _showMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('프로필 사진 변경 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _resetProfileImage() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('로그인 정보를 확인할 수 없습니다.');
      return;
    }

    try {
      setState(() {
        _isUploadingImage = true;
      });

      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final String? imagePath =
          userDocument.data()?['profileImagePath'] as String?;

      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref().child(imagePath).delete();
        } on FirebaseException catch (error) {
          // Storage에 이미 파일이 없어도 Firestore 필드는 정리합니다.
          if (error.code != 'object-not-found') {
            rethrow;
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
            'profileImageUrl': FieldValue.delete(),
            'profileImagePath': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _profileImageUrl = null;
      });

      _showMessage('기본 이미지로 변경되었습니다.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '기본 이미지 변경에 실패했습니다.';

      if (error.code == 'permission-denied' || error.code == 'unauthorized') {
        message = '프로필 사진을 변경할 권한이 없습니다.';
      }

      _showMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('기본 이미지 변경 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _loadProfile() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final Map<String, dynamic>? userData = userDocument.data();

      if (!mounted) {
        return;
      }

      final String? savedEmail = userData?['email'] as String?;

      _loginIdController.text = currentUser.email?.trim().isNotEmpty == true
          ? currentUser.email!
          : savedEmail?.trim().isNotEmpty == true
          ? savedEmail!
          : '등록된 이메일 없음';

      _nicknameController.text = (userData?['nickname'] as String?) ?? '';

      _introductionController.text = (userData?['bio'] as String?) ?? '';

      _profileImageUrl = userData?['profileImageUrl'] as String?;
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '회원 정보를 불러오지 못했습니다.';

      if (error.code == 'permission-denied') {
        message = '회원 정보를 조회할 권한이 없습니다.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 정보 조회 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보를 확인할 수 없습니다.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final String uid = currentUser.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nickname': _nicknameController.text.trim(),
        'bio': _introductionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      UserProfileCacheService.instance.updateNickname(
        uid,
        _nicknameController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 정보가 저장되었습니다.')));

      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      String message = '회원 정보 저장에 실패했습니다.';

      if (error.code == 'not-found') {
        message = '회원 정보를 찾을 수 없습니다.';
      } else if (error.code == 'permission-denied') {
        message = '회원 정보를 수정할 권한이 없습니다.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 정보 저장 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
