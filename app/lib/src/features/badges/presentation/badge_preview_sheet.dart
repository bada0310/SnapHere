import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/core/ui/paged_sliver.dart';
import 'package:snap_here/src/features/badges/application/badge_preview_providers.dart';
import 'package:snap_here/src/features/badges/application/badge_providers.dart';
import 'package:snap_here/src/features/badges/domain/badge_models.dart';

class BadgePreviewSheet extends ConsumerStatefulWidget {
  const BadgePreviewSheet({super.key});

  @override
  ConsumerState<BadgePreviewSheet> createState() => _BadgePreviewSheetState();
}

class _BadgePreviewSheetState extends ConsumerState<BadgePreviewSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final collection = ref.watch(badgeCollectionProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height:
            (media.size.height - media.viewInsets.bottom - media.padding.top) *
            .75,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '획득할 뱃지 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('이 화면의 미리보기는 실제 획득 기록에 저장되지 않아요.'),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('badge-preview-search'),
                  decoration: const InputDecoration(
                    labelText: '뱃지 이름 검색',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: collection.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => RetryMessage(
                      message: '뱃지를 불러오지 못했어요',
                      onRetry: () => ref.invalidate(badgeCollectionProvider),
                    ),
                    data: (data) => _choices(data.items),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choices(List<CollectedBadge> items) {
    final candidates = items.where((badge) => !badge.earned).toList();
    final matches = candidates
        .where((badge) => badge.name.toLowerCase().contains(_query))
        .toList();
    if (matches.isEmpty) {
      return Center(
        child: Text(candidates.isEmpty ? '미리보기할 미획득 뱃지가 없어요' : '검색 결과가 없어요'),
      );
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final badge = matches[index];
        return ListTile(
          key: Key('badge-preview-choice-${badge.id}'),
          title: Text(badge.name),
          subtitle: badge.description == null ? null : Text(badge.description!),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            ref.read(badgePreviewProvider.notifier).select(badge);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
