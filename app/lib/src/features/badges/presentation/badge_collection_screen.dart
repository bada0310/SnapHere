import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/design_icon.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/features/badges/application/badge_preview_providers.dart';
import 'package:snap_here/src/features/badges/application/badge_providers.dart';
import 'package:snap_here/src/features/badges/domain/badge_models.dart';
import 'package:snap_here/src/features/badges/presentation/badge_preview_sheet.dart';

/// 획득한 뱃지를 이미지 중심의 정사각형 3열 격자로 표시한다.
class BadgeCollectionScreen extends ConsumerWidget {
  const BadgeCollectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(displayedBadgeCollectionProvider);
    final previewEnabled = ref.watch(badgePreviewEnabledProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('수집한 뱃지'),
        toolbarHeight: 48,
        leading: const DesignBackButton(),
        actions: [
          if (previewEnabled)
            TextButton(
              key: const Key('badge-preview-open'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const BadgePreviewSheet(),
              ),
              child: const Text('획득 미리보기'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(badgeCollectionProvider);
          await ref
              .read(badgeCollectionProvider.future)
              .then<void>((_) {}, onError: (Object _, StackTrace _) {});
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (previewEnabled)
              const SliverToBoxAdapter(child: _BadgePreviewNotice()),
            collection.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: RetryMessage(
                    message: '뱃지를 불러오지 못했어요',
                    onRetry: () => ref.invalidate(badgeCollectionProvider),
                  ),
                ),
              ),
              data: (data) {
                final earned = data.items
                    .where((badge) => badge.earned)
                    .toList();
                if (earned.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Text(
                        '아직 수집한 뱃지가 없어요\n여행 사진을 올리고 첫 뱃지를 모아 보세요.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemCount: earned.length,
                    itemBuilder: (_, index) => _BadgeTile(
                      key: Key('badge-tile-${earned[index].id}'),
                      badge: earned[index],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, super.key});
  final CollectedBadge badge;
  @override
  Widget build(BuildContext context) => Semantics(
    label: badge.name,
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => BadgeDetailSheet(badgeId: badge.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ExcludeSemantics(
            child: RemoteImage(url: badge.iconUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

class _BadgePreviewNotice extends ConsumerWidget {
  const _BadgePreviewNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(badgePreviewProvider);
    return ColoredBox(
      color: AppColors.brandSubtle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selection == null
                    ? '디버그 미리보기 모드 · 실제 획득 기록은 유지돼요'
                    : '획득 미리보기 중 · 실제 기록에 저장되지 않아요',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (selection != null)
              TextButton(
                key: const Key('badge-preview-clear'),
                onPressed: ref.read(badgePreviewProvider.notifier).clear,
                child: const Text('해제'),
              ),
          ],
        ),
      ),
    );
  }
}

class BadgeDetailSheet extends ConsumerWidget {
  const BadgeDetailSheet({required this.badgeId, super.key});
  final String badgeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: ref
          .watch(displayedBadgeDetailProvider(badgeId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => RetryMessage(
              message: '뱃지 상세를 불러오지 못했어요',
              onRetry: () => ref.invalidate(badgeDetailProvider(badgeId)),
            ),
            data: (detail) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ref.watch(badgePreviewEnabledProvider) &&
                    ref.watch(badgePreviewProvider)?.badgeId == badgeId &&
                    ref
                            .watch(badgeDetailProvider(badgeId))
                            .value
                            ?.badge
                            .earned ==
                        false) ...[
                  const Text(
                    '획득 미리보기 · 실제 기록에 저장되지 않아요',
                    key: Key('badge-preview-detail-notice'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: SizedBox.square(
                    dimension: 64,
                    child: ClipOval(
                      child: RemoteImage(url: detail.badge.iconUrl),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  detail.badge.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.badge.description case final description?) ...[
                  const SizedBox(height: 12),
                  Text(description, textAlign: TextAlign.center),
                ],
                if (detail.badge.earnedAt case final earnedAt?) ...[
                  const SizedBox(height: 12),
                  Text(
                    '획득 시각 ${_date(earnedAt)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  '진행 ${detail.currentValue} / ${detail.targetValue} · ${detail.earnedCount}명 획득',
                  textAlign: TextAlign.center,
                ),
                if (detail.sourcePostId case final postId?) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.pop();
                      context.push('/photos/$postId');
                    },
                    child: const Text('뱃지를 획득한 게시글 보기'),
                  ),
                ],
              ],
            ),
          ),
    ),
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  return '$date ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
