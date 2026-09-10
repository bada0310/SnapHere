import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/features/activity/application/activity_providers.dart';
import 'package:snap_here/src/features/activity/domain/activity_models.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/settings/application/settings_providers.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/account_deletion_dialog.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/locale_picker_sheet.dart';
import 'package:snap_here/src/features/settings/presentation/widgets/settings_section.dart';

/// Figma `Wireframe_v3 / 07 Shared Detail / 07_설정`.
///
/// `표시` 묶음은 v3 프레임에 없다. 기존 프로필 설정 시트에 있던 `전체 번역`을
/// 이 화면으로 옮기면서 언어 선택과 짝지어 되살린 것이다 (SYS-010).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: const DesignBackButton(),
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SettingsSection(
            title: '계정',
            children: [
              SettingsRow(
                label: '프로필 편집',
                onTap: () => context.push('/profile-setup'),
              ),
              SettingsRow(
                label: '내 활동',
                onTap: () => context.push('/me/activity'),
              ),
              SettingsRow(
                label: '로그아웃',
                enabled: !auth.isLoading,
                onTap: () => _signOut(context, ref),
              ),
              SettingsRow(
                label: '모든 기기에서 로그아웃',
                enabled: !auth.isLoading,
                onTap: () => _signOutAll(context, ref),
              ),
            ],
          ),
          const SettingsSection(
            title: '표시',
            children: [_TranslateAllRow(), _LocaleRow()],
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
              onPressed: auth.isLoading
                  ? null
                  : () => confirmAccountDeletion(context, ref),
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
  Future<void> _signOutAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(activityRepositoryProvider).logoutAllDevices();
      await ref.read(authControllerProvider.notifier).signOut();
    } on ActivityFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

/// 원문 대신 번역문을 보여줄지. 서버에 필드가 없어 기기에만 남는다.
class _TranslateAllRow extends ConsumerWidget {
  const _TranslateAllRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(translateAllProvider);
    return SettingsSwitchRow(
      label: '전체 번역',
      description: '사용자 게시글과 댓글을 선택한 언어로 표시',
      value: enabled.value ?? false,
      onChanged: enabled.isLoading
          ? null
          : (value) => ref.read(translateAllProvider.notifier).set(value),
    );
  }
}

class _LocaleRow extends ConsumerWidget {
  const _LocaleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final locale = settings.value?.locale ?? AppLocale.ko;
    return SettingsRow(
      label: '언어',
      trailingText: settings.isLoading ? null : locale.label,
      enabled: !settings.isLoading,
      onTap: () => _select(context, ref, locale),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AppLocale current,
  ) async {
    final picked = await showLocalePickerSheet(context, selected: current);
    if (picked == null || picked == current || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(userSettingsProvider.notifier)
        .selectLocale(picked);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
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
