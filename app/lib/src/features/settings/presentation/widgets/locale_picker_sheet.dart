import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/settings/domain/app_locale.dart';

/// 표시 언어 고르기. 명세가 정한 네 가지만 보여준다
/// (`ko-KR | en-US | zh-CN | ja-JP`).
Future<AppLocale?> showLocalePickerSheet(
  BuildContext context, {
  required AppLocale selected,
}) => showModalBottomSheet<AppLocale>(
  context: context,
  backgroundColor: AppColors.card,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
  ),
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Text('언어', style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        for (final locale in AppLocale.values)
          ListTile(
            title: Text(locale.label),
            trailing: locale == selected
                ? const Icon(Icons.check, color: AppColors.brand)
                : null,
            onTap: () => Navigator.of(context).pop(locale),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  ),
);
