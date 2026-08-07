import 'package:flutter/material.dart';

import '../../theme.dart';

import '../../widgets/app_card.dart';

class MyPageProfileCard extends StatelessWidget {
  final String nickname;
  final String loginId;
  final String targetCertificate;
  final VoidCallback onEditPressed;

  const MyPageProfileCard({
    super.key,
    required this.nickname,
    required this.loginId,
    required this.targetCertificate,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: context.colors.pinkSoft,
            child: Icon(
              Icons.person,
              size: 36,
              color: context.colors.pinkStart,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  loginId,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '목표 자격증: $targetCertificate',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditPressed,
            icon: Icon(Icons.edit_outlined, color: context.colors.pinkStart),
          ),
        ],
      ),
    );
  }
}
