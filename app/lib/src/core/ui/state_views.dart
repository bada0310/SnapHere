import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

/// Figma `Wireframe_v3 / 08 Error & Empty States`의 공통 골격이다.
///
/// 네 프레임(`08_오류_네트워크`, `08_오류_지도로딩`, `08_상태_게시글없음`,
/// `08_상태_위치권한없음`)이 모두 원형 아이콘 · 제목 · 설명 · 행동 하나를 쌓은
/// 같은 구조라서 배치를 여기 한 번만 둔다. 화면마다 다른 것은 아이콘 색과 문구뿐이다.
class StateView extends StatelessWidget {
  const StateView({
    required this.icon,
    required this.title,
    this.description,
    this.iconColor,
    this.iconBackground,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color? iconColor;
  final Color? iconBackground;

  /// 프레임마다 버튼 형태가 달라서(외곽선 · 채움 · 없음) 위젯째 받는다.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StateIcon(
              icon: icon,
              color: iconColor,
              background: iconBackground,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, this.color, this.background});

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: BoxDecoration(
      color: background ?? AppColors.brandSubtle,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 28, color: color ?? AppColors.textSecondary),
  );
}

/// `08_오류_네트워크`. 화면 전체가 비었을 때 쓴다.
class NetworkErrorView extends StatelessWidget {
  const NetworkErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateView(
    icon: Icons.cloud_off_outlined,
    title: '네트워크에 연결할 수 없어요',
    description: '인터넷 연결을 확인하고 다시 시도해 주세요',
    action: OutlinedButton(
      onPressed: onRetry,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
      ),
      child: const Text('다시 시도'),
    ),
  );
}

/// `08_오류_지도로딩`. 화면 일부만 실패했을 때 쓴다 — 버튼이 채움형이고 폭이 좁다.
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    required this.title,
    required this.onRetry,
    this.description = '잠시 후 다시 시도해 주세요',
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StateView(
    icon: Icons.warning_amber_rounded,
    title: title,
    description: description,
    action: FilledButton(
      onPressed: onRetry,
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
      child: const Text('다시 시도'),
    ),
  );
}

/// `08_상태_게시글없음`. 실패가 아니라 '아직 없음'이라 어조를 권유형으로 둔다.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.title,
    this.description,
    this.icon = Icons.photo_camera_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StateView(
    icon: icon,
    title: title,
    description: description,
    action: actionLabel == null || onAction == null
        ? null
        : FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: Text(actionLabel!),
          ),
  );
}

/// `08_상태_위치권한없음`. 거절해도 화면은 계속 쓸 수 있어야 해서 '나중에'가 있다.
///
/// 반환값은 사용자가 설정으로 가기를 선택했는지다. 실제 설정 이동은 호출한 화면이
/// 정한다 — 권한 플러그인을 이 위젯이 알 필요가 없다.
Future<bool> showPermissionPromptDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = '설정에서 허용하기',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: AppColors.card,
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      content: StateView(
        icon: Icons.place_outlined,
        title: title,
        description: description,
        iconColor: AppColors.error,
        iconBackground: const Color(0xFFFDECEC),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: Text(confirmLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('나중에'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
