import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/event/application/event_providers.dart';
import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/event/presentation/widgets/event_image.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(eventId));
    final loadedDetail = detail.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('이벤트 상세'),
        actions: [
          IconButton(
            tooltip: '공유',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final url =
                  'https://snaphere.app/events/${Uri.encodeComponent(eventId)}';
              await Clipboard.setData(ClipboardData(text: url));
              messenger.showSnackBar(
                const SnackBar(content: Text('이벤트 공유 링크를 복사했어요.')),
              );
            },
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailError(
          message: '$error',
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (data) => _DetailBody(detail: data),
      ),
      bottomNavigationBar: loadedDetail != null
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loadedDetail.event.status == EventStatus.ended
                        ? null
                        : () => context.push('/upload?eventId=$eventId'),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      loadedDetail.event.status == EventStatus.ended
                          ? '종료된 이벤트예요'
                          : '사진 올리고 참여하기',
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final EventDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = detail.event;
    final posts = ref.watch(eventPostsProvider(event.eventId));
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              EventImage(source: event.thumbnailUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xA6000000)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(label: event.scheduleLabel),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                title: '기간',
                value: event.periodLabel,
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoRow(
                icon: Icons.place_outlined,
                title: detail.place.name,
                value: detail.place.address,
                trailing: TextButton.icon(
                  onPressed: () => context.push(
                    '/map?lat=${detail.place.latitude ?? ''}&lng=${detail.place.longitude ?? ''}',
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('지도'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('이벤트 소개', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail.overview,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.55),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tag in detail.fixedTags)
                    Chip(
                      avatar: const Icon(Icons.lock_outline, size: 14),
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (detail.badge case final badge?) ...[
                const SizedBox(height: AppSpacing.xl),
                _BadgePreview(badge: badge, radiusM: detail.verifyRadiusM),
              ],
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Text('참여 스냅', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${event.participantCount}',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppColors.brand),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              posts.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(eventPostsProvider(event.eventId)),
                  child: const Text('참여 사진 다시 불러오기'),
                ),
                data: (items) => _PostGrid(posts: items),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.brandSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.badge, required this.radiusM});

  final EventBadge badge;
  final int radiusM;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.brandSubtle, Color(0xFFFFFFFF)],
      ),
      border: Border.all(color: AppColors.brand),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium_outlined, size: 32),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('참여 뱃지', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(badge.name, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${badge.description} 현장 ${radiusM ~/ 1000}km 안에서 인증해 주세요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({required this.posts});

  final List<EventPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Text('첫 번째 참여 사진을 남겨보세요.'),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.xs,
        mainAxisSpacing: AppSpacing.xs,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return InkWell(
          onTap: () => context.push('/photos/${post.postId}'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: EventImage(source: post.thumbnailUrl),
              ),
              Positioned(
                left: AppSpacing.xs,
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      '${post.likeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          const Text('이벤트 정보를 불러오지 못했어요'),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    ),
  );
}
