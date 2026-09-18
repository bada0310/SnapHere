import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/badges/application/badge_providers.dart';
import 'package:snap_here/src/features/badges/domain/badge_models.dart';

const _previewRequested = bool.fromEnvironment(
  'ENABLE_BADGE_PREVIEW',
  defaultValue: false,
);

/// Release/profile 앱에서는 빌드 플래그를 켜도 미리보기를 사용할 수 없다.
final badgePreviewEnabledProvider = Provider<bool>(
  (_) => badgePreviewAllowed(requested: _previewRequested),
);

bool badgePreviewAllowed({
  required bool requested,
  bool debugBuild = kDebugMode,
}) => debugBuild && requested;

/// 실제 뱃지 정보는 복제하지 않고 선택 ID와 미리보기 시각만 메모리에 둔다.
class BadgePreviewSelection {
  const BadgePreviewSelection({required this.badgeId, required this.earnedAt});

  final String badgeId;
  final DateTime earnedAt;

  bool appliesTo(CollectedBadge badge) => badge.id == badgeId && !badge.earned;

  CollectedBadge apply(CollectedBadge badge) => !appliesTo(badge)
      ? badge
      : CollectedBadge(
          id: badge.id,
          name: badge.name,
          description: badge.description,
          iconUrl: badge.iconUrl,
          earned: true,
          earnedAt: earnedAt,
        );
}

final badgePreviewProvider =
    NotifierProvider<BadgePreviewController, BadgePreviewSelection?>(
      BadgePreviewController.new,
    );

class BadgePreviewController extends Notifier<BadgePreviewSelection?> {
  String? _ownerId;

  @override
  BadgePreviewSelection? build() {
    final enabled = ref.watch(badgePreviewEnabledProvider);
    _ownerId = enabled
        ? ref.watch(
            authControllerProvider.select(
              (auth) => auth.value?.isAuthenticated == true
                  ? auth.value?.user?.id
                  : null,
            ),
          )
        : null;
    // 인증 주인이 바뀌거나 로그아웃하면 이전 미리보기를 폐기한다.
    return null;
  }

  void select(CollectedBadge badge) {
    if (!ref.read(badgePreviewEnabledProvider) ||
        _ownerId == null ||
        badge.earned) {
      return;
    }
    state = BadgePreviewSelection(badgeId: badge.id, earnedAt: DateTime.now());
  }

  void clear() => state = null;
}

/// 서버 응답은 보존하고 화면이 읽는 값에만 미리보기 상태를 합친다.
final displayedBadgeCollectionProvider = Provider<AsyncValue<BadgeCollection>>((
  ref,
) {
  final collection = ref.watch(badgeCollectionProvider);
  if (!ref.watch(badgePreviewEnabledProvider)) return collection;
  final selection = ref.watch(badgePreviewProvider);
  if (selection == null) return collection;
  return collection.whenData((data) {
    if (!data.items.any(selection.appliesTo)) return data;
    final earnedCount = data.earnedCount + 1;
    return BadgeCollection(
      items: data.items.map(selection.apply).toList(),
      earnedCount: earnedCount,
      obtainableCount: data.obtainableCount,
      progress: data.obtainableCount == 0
          ? 0
          : (earnedCount / data.obtainableCount).clamp(0, 1),
    );
  });
});

final displayedBadgeDetailProvider = Provider.autoDispose
    .family<AsyncValue<BadgeDetail>, String>((ref, id) {
      final detail = ref.watch(badgeDetailProvider(id));
      if (!ref.watch(badgePreviewEnabledProvider)) return detail;
      final selection = ref.watch(badgePreviewProvider);
      if (selection == null) return detail;
      return detail.whenData((data) {
        if (!selection.appliesTo(data.badge)) return data;
        return BadgeDetail(
          badge: selection.apply(data.badge),
          currentValue: data.targetValue,
          targetValue: data.targetValue,
          earnedCount: data.earnedCount,
          sourcePostId: null,
        );
      });
    });
