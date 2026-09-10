import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/core/ui/remote_image.dart';
import 'package:snap_here/src/core/ui/state_views.dart';
import 'package:snap_here/src/features/place/application/place_providers.dart';

/// Figma `07_장소_상세`의 `사진` 섹션. 3열 정사각 격자다 (PLC-013).
class PlacePhotoGrid extends ConsumerWidget {
  const PlacePhotoGrid({required this.placeId, super.key});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(placePostsProvider(placeId));
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '사진',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('최신순', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          posts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LoadErrorView(
                title: '사진을 불러올 수 없어요',
                onRetry: () => ref.invalidate(placePostsProvider(placeId)),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: EmptyStateView(
                      title: '아직 이 장소의 사진이 없어요',
                      description: '첫 사진을 올려 보세요',
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                          ),
                      itemBuilder: (_, index) => GestureDetector(
                        onTap: () =>
                            context.push('/photos/${items[index].postId}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: RemoteImage(url: items[index].thumbnailUrl),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
