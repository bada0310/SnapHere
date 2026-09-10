import 'package:flutter/material.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';

/// Figma `07_설정`의 한 묶음. 회색 제목 위에 흰 카드가 붙는 형태다.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Text(title, style: Theme.of(context).textTheme.bodySmall),
        ),
        ColoredBox(
          color: AppColors.card,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const Divider(height: 1, indent: AppSpacing.lg),
                children[index],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// 스위치가 붙는 줄. `SettingsRow`와 좌우 여백을 맞춰 두 줄이 어긋나 보이지 않게 한다.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyMedium),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(description!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    this.onTap,
    this.trailingText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final String? trailingText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (trailingText != null)
              Text(trailingText!, style: text.bodySmall)
            else if (onTap != null)
              const DesignIcon('chevron', size: 18),
          ],
        ),
      ),
    );
  }
}
