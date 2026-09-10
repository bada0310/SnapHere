import 'package:flutter/material.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/post/domain/post_models.dart';

/// 위치 신뢰 등급 배지 (PST-046).
///
/// 명세가 "등급 이름만으로는 뜻이 통하지 않는다. 아래 기준 안내와 반드시 짝으로
/// 만든다"고 못박아서 배지 단독으로는 쓰지 않고 항상 눌러서 기준을 열 수 있게 한다.
class TierBadge extends StatelessWidget {
  const TierBadge({required this.result, super.key});

  final TierResult result;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(result.tier);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: () => showTierCriteriaSheet(context, result),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 12, color: palette.foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '위치 ${result.tier.label}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

({Color background, Color foreground}) _paletteOf(TrustTier tier) =>
    switch (tier) {
      TrustTier.high => (
        background: AppColors.brandSubtle,
        foreground: const Color(0xFF127C8F),
      ),
      TrustTier.medium => (
        background: const Color(0xFFFFF4E0),
        foreground: const Color(0xFF9A6B12),
      ),
      TrustTier.low => (
        background: const Color(0xFFF1F3F5),
        foreground: AppColors.textSecondary,
      ),
    };

/// 세 등급의 판정 기준과 이 게시글이 그 등급을 받은 이유를 보여준다
/// (PST-047, PST-049). 낮음이면 올리는 방법을 함께 안내하고 '인증 실패' 어조는 쓰지 않는다.
Future<void> showTierCriteriaSheet(BuildContext context, TierResult result) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _TierCriteriaSheet(result: result),
    );

class _TierCriteriaSheet extends StatelessWidget {
  const _TierCriteriaSheet({required this.result});

  final TierResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('위치 신뢰도 ${result.tier.label}', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _reasonOf(result),
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('등급은 이렇게 정해져요', style: text.labelLarge),
            const SizedBox(height: AppSpacing.md),
            const _CriteriaRow(
              tier: TrustTier.high,
              description: '촬영 좌표가 있고 인증 반경 안에서 바로 올린 사진',
            ),
            const _CriteriaRow(
              tier: TrustTier.medium,
              description: '촬영 좌표가 있고 인증 반경 안이지만 며칠 지나 올린 사진',
            ),
            const _CriteriaRow(
              tier: TrustTier.low,
              description: '촬영 좌표가 없거나 인증 반경 밖에서 올린 사진',
            ),
            if (result.improvementHints.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('다음엔 이렇게 해보세요', style: text.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              for (final hint in result.improvementHints)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('· $hint', style: text.bodyMedium),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CriteriaRow extends StatelessWidget {
  const _CriteriaRow({required this.tier, required this.description});

  final TrustTier tier;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            tier.label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

String _reasonOf(TierResult result) {
  final parts = <String>[];
  if (result.distanceM != null && result.verifyRadiusM != null) {
    parts.add(
      result.withinRadius
          ? '장소에서 ${result.distanceM}m 안에서 찍었어요 (인증 반경 ${result.verifyRadiusM}m)'
          : '장소에서 ${result.distanceM}m 떨어진 곳에서 찍었어요 (인증 반경 ${result.verifyRadiusM}m)',
    );
  } else {
    parts.add('사진에 촬영 좌표가 없어요');
  }
  final days = result.daysSinceTaken;
  if (days != null) {
    parts.add(days < 1 ? '촬영 당일에 올렸어요' : '촬영하고 $days일 뒤에 올렸어요');
  }
  return parts.join(' · ');
}
