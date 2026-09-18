import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/features/auth/presentation/auth_ui.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 80).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthAppLogo(),
                    const Spacer(),
                    const _Highlight(
                      icon: Icons.location_on_outlined,
                      title: '지도에서 관광지를 탐색하세요',
                      description: '전국 방방곡곡 숨겨진 명소와 포토존 정보를 편리하게 찾아보실 수 있습니다.',
                    ),
                    const SizedBox(height: 24),
                    const _Highlight(
                      icon: Icons.photo_camera_outlined,
                      title: '여행 사진을 공유하고 랭킹에 참여하세요',
                      description: '나만 알기 아까운 순간을 업로드하고 이달의 우수 스냅에 도전해 보세요.',
                    ),
                    const SizedBox(height: 24),
                    const _Highlight(
                      icon: Icons.workspace_premium_outlined,
                      title: '행사 뱃지를 수집하세요',
                      description:
                          '지역 곳곳에서 열리는 챌린지 미션을 완수하고 한정판 공식 스냅 뱃지를 받아보세요.',
                    ),
                    const Spacer(),
                    AuthPrimaryButton(
                      label: '로그인 또는 둘러보기',
                      onPressed: () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAFBFE),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: const Color(0xFF43C3DF)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AuthColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AuthColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
