import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class TutorialCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isLast;
  final bool pointUp; // true: 카드가 타겟 아래에 있음(화살표 위로) / false: 카드가 타겟 위에 있음(화살표 아래로)
  final bool showArrow;
  final double arrowAlignX; // -1.0(왼쪽) ~ 1.0(오른쪽), 0.0이 가운데

  const TutorialCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.isLast = false,
    this.pointUp = true,
    this.showArrow = true,
    this.arrowAlignX = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 270,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFFF2F5)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF06F91).withOpacity(0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF06F91), Color(0xFFFF4D6D)],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF302C2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: Color(0xFF817B7D),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (isLast) {
                  ShowcaseView.get().dismiss();
                } else {
                  ShowcaseView.get().next();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF06F91), Color(0xFFFF4D6D)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D6D).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  isLast ? '확인' : '다음',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showArrow) {
      return card;
    }

    final arrow = ClipPath(
      clipper: _TriangleClipper(pointUp: pointUp),
      child: Container(width: 22, height: 11, color: Colors.white),
    );

    // arrowAlignX: -1.0(왼쪽 끝) ~ 1.0(오른쪽 끝) 기준으로 화살표를 카드 폭(270) 안에서 이동
    const cardWidth = 270.0;
    const arrowWidth = 22.0;
    final maxOffset = (cardWidth - arrowWidth) / 2;
    final dx = maxOffset * arrowAlignX.clamp(-1.0, 1.0);

    final positionedArrow = Transform.translate(
      offset: Offset(dx, 0),
      child: arrow,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pointUp) positionedArrow,
        card,
        if (!pointUp) positionedArrow,
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  final bool pointUp;
  _TriangleClipper({required this.pointUp});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (pointUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}