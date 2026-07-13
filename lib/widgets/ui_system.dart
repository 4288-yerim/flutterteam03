import 'package:flutter/material.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_button.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_card.dart';

/// 이 파일을 Android Studio에서 열고 우측 상단 ▶ 버튼(또는 main() 옆 초록 삼각형)을
/// 누르면 이 페이지만 바로 실행됩니다. Firebase 연결 필요 없어요.
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: UiSystemPage(),
  ));
}

/// PASSMATE UI SYSTEM 스타일 가이드 페이지
/// 기존에 만든 AppButton, AppBottomBar, AppMainBackground를 그대로 활용합니다.
class UiSystemPage extends StatefulWidget {
  const UiSystemPage({super.key});

  @override
  State<UiSystemPage> createState() => _UiSystemPageState();
}

class _UiSystemPageState extends State<UiSystemPage> {
  int _currentIndex = 2; // AI 탭이 선택된 상태로 시작 (이미지 기준)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: AppBottomBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
      body: AppMainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀
              const Text(
                'PASSMATE UI SYSTEM',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '파스텔 핑크 기반 통합 디자인',
                style: TextStyle(fontSize: 15, color: Color(0xFF9AA0AC)),
              ),
              const SizedBox(height: 32),

              // Color 섹션
              _SectionTitle('Color'),
              const SizedBox(height: 16),
              Row(
                children: const [
                  _ColorSwatch(color: Color(0xFFF0788F), label: 'Primary'),
                  SizedBox(width: 12),
                  _ColorSwatch(color: Color(0xFFFCE1E8), label: 'Pink Soft'),
                  SizedBox(width: 12),
                  _ColorSwatch(color: Color(0xFFE6E1FB), label: 'Lavender'),
                  SizedBox(width: 12),
                  _ColorSwatch(color: Color(0xFFE1E9FB), label: 'Soft Blue'),
                  SizedBox(width: 12),
                  _ColorSwatch(color: Color(0xFFDFF5EA), label: 'Mint'),
                ],
              ),
              const SizedBox(height: 32),

              // Buttons 섹션
              _SectionTitle('Buttons'),
              const SizedBox(height: 16),
              AppButton(
                text: 'Primary',
                type: AppButtonType.primaryPink,
                onPressed: () {},
              ),
              const SizedBox(height: 14),
              AppButton(
                text: 'Outline',
                type: AppButtonType.outlinePink,
                onPressed: () {},
              ),
              const SizedBox(height: 14),
              AppButton(
                text: 'blue',
                type: AppButtonType.primaryBlue,
                onPressed: () {},
              ),
              const SizedBox(height: 14),
              AppButton(
                text: 'Disabled',
                type: AppButtonType.gray,
                onPressed: null, // 비활성화 상태
              ),
              const SizedBox(height: 32),

              // Cards / Radius 섹션
              _SectionTitle('Cards / Radius'),
              const SizedBox(height: 16),
              const AppCard(
                title: '기본 카드',
                subtitle: 'Radius 22 / Shadow Soft',
              ),
              const SizedBox(height: 40),

              // Bottom Navigation 섹션 (실제 바는 Scaffold 하단에 고정되어 있음)
              _SectionTitle('Bottom Navigation'),
              const SizedBox(height: 80), // 화면 맨 아래 AppBottomBar와 안 겹치게 여백
            ],
          ),
        ),
      ),
    );
  }
}

/// 섹션 제목 (Color, Buttons, Cards / Radius 등)
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

/// 컬러 스와치 (색상 박스 + 라벨)
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A)),
          ),
        ],
      ),
    );
  }
}