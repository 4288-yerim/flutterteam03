import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme.dart';
import '../widgets/app_main_background.dart';
import '../widgets/app_top_bar.dart';

class PassRiskDetailScreen extends StatelessWidget {
  final String certificateName;

  const PassRiskDetailScreen({super.key, required this.certificateName});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppTopBar(title: '$certificateName 합격 예측'),
      body: AppMainBackground(
        child: SafeArea(
          child: user == null
              ? Center(child: Text('로그인이 필요합니다.'))
              : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: user.uid)
                .limit(1)
                .get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: context.colors.pinkStart,
                  ),
                );
              }

              if (userSnapshot.data!.docs.isEmpty) {
                return Center(child: Text('사용자 정보를 찾을 수 없습니다.'));
              }

              final userDocRef = userSnapshot.data!.docs.first.reference;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDocRef
                    .collection('analysis')
                    .doc('passRisk')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: context.colors.pinkStart,
                      ),
                    );
                  }

                  final data = snapshot.data?.data();

                  if (data == null) {
                    return Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '아직 분석 데이터가 없습니다.\n학습 계획을 진행하면 분석이 시작돼요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    );
                  }

                  final passProbability =
                      (data['passProbability'] as num?)?.toInt() ?? 0;
                  final riskLevel =
                      (data['riskLevel'] as String?)?.trim() ?? 'UNKNOWN';
                  final factors =
                      data['factors'] as Map<String, dynamic>? ?? {};

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '예상 합격 가능성',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '$passProbability%',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: context.colors.pinkStart,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '위험도: $riskLevel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          '분석 요인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...factors.entries.map(
                              (entry) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}