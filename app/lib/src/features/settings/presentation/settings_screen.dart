import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/auth/domain/auth_repository.dart';
import 'package:snap_here/src/features/settings/application/settings_providers.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/account_deletion_dialog.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/settings_section.dart';

/// Figma `Wireframe_v3 / 07 Shared Detail / 07_설정`.
///
/// 자동 번역은 후속 기능이므로 동작하지 않는 번역 스위치는 노출하지 않는다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;
  bool _signingOutAll = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final canAct = !auth.isLoading && !_signingOut && !_signingOutAll;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('설정'),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xxl,
        ),
        children: [
          SettingsSection(
            title: '계정',
            children: [
              SettingsRow(
                label: '프로필 편집',
                onTap: () => context.push('/profile/edit'),
              ),
              SettingsRow(
                label: '내 활동',
                onTap: () => context.push('/me/activity'),
              ),
              SettingsRow(
                label: _signingOut ? '로그아웃 중...' : '로그아웃',
                trailingText: _signingOut ? '처리 중' : null,
                enabled: canAct,
                onTap: _signOut,
              ),
              SettingsRow(
                label: _signingOutAll ? '모든 기기에서 로그아웃 중...' : '모든 기기에서 로그아웃',
                trailingText: _signingOutAll ? '처리 중' : null,
                enabled: canAct,
                onTap: _signOutAll,
              ),
            ],
          ),
          const SettingsSection(
            title: '알림',
            children: [_PushNotificationRow()],
          ),
          SettingsSection(
            title: '서비스',
            children: [
              SettingsRow(
                label: '이용약관',
                onTap: () => context.push('/legal/terms'),
              ),
              SettingsRow(
                label: '개인정보 처리방침',
                onTap: () => context.push('/legal/privacy-policy'),
              ),
              SettingsRow(
                label: '오픈소스 라이선스',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'SnapHere',
                  applicationVersion: appVersionName,
                ),
              ),
            ],
          ),
          const SettingsSection(
            title: '앱 정보',
            children: [SettingsRow(label: '버전', trailingText: appVersionName)],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: TextButton(
              onPressed: canAct
                  ? () => confirmAccountDeletion(context, ref)
                  : null,
              child: Text(
                '계정 삭제',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// API-AUTH-005. 서버 세션을 모두 끊은 뒤 이 기기도 로그아웃한다.
  Future<void> _signOutAll() async {
    if (_signingOut || _signingOutAll) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOutAll = true);
    try {
      await ref.read(activityRepositoryProvider).logoutAllDevices();
      final result = await ref
          .read(authControllerProvider.notifier)
          .signOut(serverSessionAlreadyEnded: true);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.googleSessionEnded
                  ? '모든 기기에서 로그아웃했어요.'
                  : '모든 기기에서 로그아웃했어요. Google 연결 종료는 확인하지 못했어요.',
            ),
          ),
        );
      }
    } on AuthFailure catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ActivityFailure catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOutAll = false);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut || _signingOutAll) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingOut = true);
    try {
      final result = await ref.read(authControllerProvider.notifier).signOut();
      if (messenger.mounted) {
        final message = !result.serverSessionEnded
            ? '이 기기에서 로그아웃했어요. 서버 세션 종료는 확인하지 못했어요.'
            : !result.googleSessionEnded
            ? '앱에서 로그아웃했어요. Google 연결 종료는 확인하지 못했어요.'
            : '로그아웃했어요.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } on AuthFailure catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

/// 서버는 좋아요·팔로우·뱃지를 따로 두지만 화면은 한 줄이라 셋을 함께 켜고 끈다.
class _PushNotificationRow extends ConsumerWidget {
  const _PushNotificationRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    return SettingsSwitchRow(
      label: '푸시 알림',
      value: settings.value?.notifications.anyEnabled ?? false,
      onChanged: settings.isLoading
          ? null
          : (value) => _set(context, ref, value),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(userSettingsProvider.notifier)
        .setPushEnabled(value);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
