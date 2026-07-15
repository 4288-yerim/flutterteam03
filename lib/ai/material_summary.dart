import 'package:flutter/material.dart';

import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class MaterialSummaryPage extends StatefulWidget {
  const MaterialSummaryPage({super.key});

  @override
  State<MaterialSummaryPage> createState() =>
      _MaterialSummaryPageState();
}

class _MaterialSummaryPageState extends State<MaterialSummaryPage> {
  static const Color _textColor = Color(0xFF302C2E);
  static const Color _subTextColor = Color(0xFF817B7D);
  static const Color _pinkColor = Color(0xFFF4869D);

  // 실제 파일 선택 기능을 연결하기 전 사용하는 임시 상태
  final List<String> _selectedFileNames = [];
  bool _isSummaryGenerated = false;

  void _selectFiles() {
    setState(() {
      _selectedFileNames
        ..clear()
        ..addAll([
          '정보처리기사_네트워크.pdf',
          'OSI_7계층_정리.png',
          '네트워크_기출문제.jpg',
        ]);

      _isSummaryGenerated = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('현재는 샘플 파일 3개가 선택됩니다.'),
      ),
    );
  }

  void _removeFile(String fileName) {
    setState(() {
      _selectedFileNames.remove(fileName);
      _isSummaryGenerated = false;
    });
  }

  void _removeAllFiles() {
    setState(() {
      _selectedFileNames.clear();
      _isSummaryGenerated = false;
    });
  }

  void _generateSummary() {
    if (_selectedFileNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요약할 사진이나 파일을 먼저 선택해주세요.'),
        ),
      );

      return;
    }

    setState(() {
      _isSummaryGenerated = true;
    });
  }

  void _saveSummaryNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약 노트 저장 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  void _downloadSummaryNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('요약본 다운로드 기능은 추후 연결될 예정입니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: const AppTopBar(
        title: '자료 요약',
        centerTitle: false,
      ),
      body: AppMainBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              22,
              24,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SummaryHeader(),

                const SizedBox(height: 30),

                const _SectionTitle(
                  title: '요약할 자료를 올려주세요',
                  description: 'JPG, PNG, PDF 파일만 업로드할 수 있어요.',
                ),

                const SizedBox(height: 16),

                if (_selectedFileNames.isEmpty)
                  _UploadArea(
                    onPressed: _selectFiles,
                  )
                else ...[
                  _SelectedFilesSection(
                    fileNames: _selectedFileNames,
                    onAddPressed: _selectFiles,
                    onRemovePressed: _removeFile,
                    onRemoveAllPressed: _removeAllFiles,
                  ),
                ],

                const SizedBox(height: 24),

                _GenerateSummaryButton(
                  isEnabled: _selectedFileNames.isNotEmpty,
                  onPressed: _generateSummary,
                ),

                if (_isSummaryGenerated) ...[
                  const SizedBox(height: 38),

                  const _SectionTitle(
                    title: '구름iT 요약 노트',
                    description: '업로드한 자료의 핵심 내용을 정리했어요.',
                  ),

                  const SizedBox(height: 16),

                  const _SummaryResultCard(),

                  const SizedBox(height: 22),

                  _SummaryActionButtons(
                    onSavePressed: _saveSummaryNote,
                    onDownloadPressed: _downloadSummaryNote,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE4ED),
            Color(0xFFF2E4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '긴 학습 자료도\n핵심만 빠르게 확인해요',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                SizedBox(height: 11),
                Text(
                  '사진이나 파일을 올리면\n구름iT이 중요한 내용을 요약해드려요.',
                  style: TextStyle(
                    color: Color(0xFF817B7D),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.summarize_rounded,
            size: 74,
            color: Color(0xFFF4869D),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? description;

  const _SectionTitle({
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF302C2E),
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(
            description!,
            style: const TextStyle(
              color: Color(0xFF817B7D),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _UploadArea extends StatelessWidget {
  final VoidCallback onPressed;

  const _UploadArea({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 220,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF2CBD5),
              width: 1.5,
            ),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UploadIcon(),

              SizedBox(height: 18),

              Text(
                '사진 또는 파일 업로드',
                style: TextStyle(
                  color: Color(0xFF302C2E),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              SizedBox(height: 8),

              Text(
                '눌러서 요약할 자료를 선택해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF817B7D),
                  fontSize: 14,
                ),
              ),

              SizedBox(height: 12),

              _AllowedFileBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadIcon extends StatelessWidget {
  const _UploadIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE6EC),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.cloud_upload_outlined,
        color: Color(0xFFF4869D),
        size: 36,
      ),
    );
  }
}

class _AllowedFileBadge extends StatelessWidget {
  const _AllowedFileBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F4),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'JPG · PNG · PDF',
        style: TextStyle(
          color: Color(0xFFF4869D),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SelectedFilesSection extends StatelessWidget {
  final List<String> fileNames;
  final VoidCallback onAddPressed;
  final ValueChanged<String> onRemovePressed;
  final VoidCallback onRemoveAllPressed;

  const _SelectedFilesSection({
    required this.fileNames,
    required this.onAddPressed,
    required this.onRemovePressed,
    required this.onRemoveAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFF1DDE2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '선택된 파일',
                  style: TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${fileNames.length}개',
                style: const TextStyle(
                  color: Color(0xFFF4869D),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemoveAllPressed,
                child: const Text(
                  '전체 삭제',
                  style: TextStyle(
                    color: Color(0xFF9A9295),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ...List.generate(
            fileNames.length,
                (index) {
              final fileName = fileNames[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == fileNames.length - 1 ? 0 : 10,
                ),
                child: _SelectedFileItem(
                  fileName: fileName,
                  onRemovePressed: () {
                    onRemovePressed(fileName);
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onAddPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4869D),
                side: const BorderSide(
                  color: Color(0xFFF2CBD5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 20,
              ),
              label: const Text(
                '파일 추가하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFileItem extends StatelessWidget {
  final String fileName;
  final VoidCallback onRemovePressed;

  const _SelectedFileItem({
    required this.fileName,
    required this.onRemovePressed,
  });

  IconData _getFileIcon() {
    final lowerFileName = fileName.toLowerCase();

    if (lowerFileName.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }

    return Icons.image_outlined;
  }

  String _getFileType() {
    final parts = fileName.split('.');

    if (parts.length < 2) {
      return 'FILE';
    }

    return parts.last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE6EC),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _getFileIcon(),
              color: const Color(0xFFF4869D),
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF302C2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _getFileType(),
                  style: const TextStyle(
                    color: Color(0xFF9A9295),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onRemovePressed,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF9A9295),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerateSummaryButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _GenerateSummaryButton({
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF4869D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2DADD),
          disabledForegroundColor: const Color(0xFFA49CA0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 22,
        ),
        label: const Text(
          '요약 생성하기',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SummaryResultCard extends StatelessWidget {
  const _SummaryResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF0E4E8),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryResultTitle(
            number: '1',
            title: '핵심 개념',
          ),

          SizedBox(height: 12),

          Text(
            '네트워크 계층은 서로 다른 네트워크 간에 데이터를 전달하며, '
                'IP 주소를 기반으로 최적의 경로를 선택합니다.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),

          SizedBox(height: 22),

          Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          SizedBox(height: 22),

          _SummaryResultTitle(
            number: '2',
            title: '주요 내용',
          ),

          SizedBox(height: 12),

          _SummaryBulletText(
            text: 'IP 주소를 사용하여 출발지와 목적지를 구분해요.',
          ),

          SizedBox(height: 9),

          _SummaryBulletText(
            text: '라우터가 패킷이 이동할 경로를 결정해요.',
          ),

          SizedBox(height: 9),

          _SummaryBulletText(
            text: '대표적인 프로토콜에는 IP, ICMP, ARP 등이 있어요.',
          ),

          SizedBox(height: 22),

          Divider(
            color: Color(0xFFF0E7E9),
            height: 1,
          ),

          SizedBox(height: 22),

          _SummaryResultTitle(
            number: '3',
            title: '시험 포인트',
          ),

          SizedBox(height: 12),

          Text(
            'OSI 7계층에서 네트워크 계층의 역할과 주요 장비인 '
                '라우터의 특징을 함께 정리해두는 것이 좋아요.',
            style: TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryResultTitle extends StatelessWidget {
  final String number;
  final String title;

  const _SummaryResultTitle({
    required this.number,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE6EC),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Color(0xFFF4869D),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF302C2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SummaryBulletText extends StatelessWidget {
  final String text;

  const _SummaryBulletText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFF4869D),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF595254),
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryActionButtons extends StatelessWidget {
  final VoidCallback onSavePressed;
  final VoidCallback onDownloadPressed;

  const _SummaryActionButtons({
    required this.onSavePressed,
    required this.onDownloadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onSavePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4869D),
                backgroundColor: Colors.white.withValues(alpha: 0.84),
                side: const BorderSide(
                  color: Color(0xFFF4869D),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.bookmark_add_outlined,
                size: 20,
              ),
              label: const Text(
                '요약본 저장',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onDownloadPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4869D),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(
                Icons.download_rounded,
                size: 20,
              ),
              label: const Text(
                '요약본 다운',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}