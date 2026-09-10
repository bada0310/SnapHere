import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/router/login_navigation.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  static const _labels = ['홈', '커뮤니티', '업로드', '이벤트', '마이'];
  static const _icons = ['home', 'community', '', 'events', 'profile'];

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authControllerProvider).value?.isGuest == true;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var index = 0; index < 5; index++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: index == _navigationIndex,
                      label: _labels[index],
                      child: InkResponse(
                        onTap: () =>
                            _selectDestination(context, index, isGuest),
                        child: SizedBox(
                          height: 64,
                          child: Center(
                            child: index == 2
                                ? _buildUploadButton()
                                : _buildBranchButton(index),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDestination(BuildContext context, int index, bool isGuest) {
    if (isGuest && (index == 2 || index == 4)) {
      requestLogin(context, returnTo: index == 2 ? '/upload' : '/profile');
      return;
    }
    if (index == 2) {
      context.push('/upload');
      return;
    }
    final branchIndex = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  Widget _buildUploadButton() => Container(
    width: 48,
    height: 48,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.brand,
      shape: BoxShape.circle,
    ),
    child: const DesignIcon('plus', color: Colors.white),
  );

  Widget _buildBranchButton(int index) {
    final selected = index == _navigationIndex;
    final color = selected ? AppColors.brand : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignIcon(_icons[index], color: color),
        const SizedBox(height: 4),
        Text(
          _labels[index],
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int get _navigationIndex {
    final index = navigationShell.currentIndex;
    return index > 1 ? index + 1 : index;
  }
}
