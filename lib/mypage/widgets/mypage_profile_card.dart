import 'package:flutter/material.dart';

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
          const CircleAvatar(
            radius: 34,
            child: Icon(
              Icons.person,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loginId,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '목표 자격증: $targetCertificate',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditPressed,
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),
        ],
      ),
    );
  }
}