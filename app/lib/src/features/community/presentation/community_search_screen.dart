import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/community/application/community_providers.dart';
import 'package:snap_here/src/features/community/domain/community_models.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_empty_state.dart';
import 'package:snap_here/src/features/community/presentation/widgets/community_post_card.dart';
import 'package:snap_here/src/features/community/presentation/widgets/search_sections.dart';

/// Figma `03_커뮤니티_검색_포커스` · `03_커뮤니티_검색결과` · `03_커뮤니티_검색_없음`.
///
/// 세 화면은 검색바를 공유하고 본문만 바뀌므로 한 화면에서 상태로 구분한다.
class CommunitySearchScreen extends ConsumerStatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  ConsumerState<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends ConsumerState<CommunitySearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(communityKeywordProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    _controller.text = trimmed;
    _focusNode.unfocus();
    ref.read(communityKeywordProvider.notifier).submit(trimmed);
  }

  void _clear() {
    _controller.clear();
    ref.read(communityKeywordProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = ref.watch(communityKeywordProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.lg,
        title: _SearchField(
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: _submit,
          onClear: _clear,
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('취소'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: keyword.trim().isEmpty
          ? _SuggestionsView(onKeywordTap: _submit)
          : _ResultsView(keyword: keyword, onEditKeyword: _clear),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          hintText: '검색어를 입력하세요',
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '지우기',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.cancel,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
      ),
    );
  }
}

/// `03_커뮤니티_검색_포커스` — 최근 검색어 + 추천 검색어.
class _SuggestionsView extends ConsumerWidget {
  const _SuggestionsView({required this.onKeywordTap});

  final ValueChanged<String> onKeywordTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(communitySearchSuggestionsProvider);
    final actions = ref.watch(communityRecentKeywordActionsProvider);
    final textTheme = Theme.of(context).textTheme;

    return suggestions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (data) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('최근 검색어', style: textTheme.labelLarge),
              if (data.recent.isNotEmpty)
                TextButton(
                  onPressed: actions.clearAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('전체 삭제', style: textTheme.bodySmall),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (data.recent.isEmpty)
            Text(
              '최근 검색어가 없어요.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final keyword in data.recent)
                  _RecentChip(
                    label: keyword,
                    onTap: () => onKeywordTap(keyword),
                    onRemove: () => actions.remove(keyword),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('추천 검색어', style: textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final keyword in data.recommended)
                _RecommendedChip(
                  label: keyword,
                  onTap: () => onKeywordTap(keyword),
                ),
            ],
          ),
          if (data.popularTags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('인기 태그', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.md),
            SearchTagWrap(tags: data.popularTags),
          ],
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.bodyMedium,
      onPressed: onTap,
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 14),
      deleteButtonTooltipMessage: '$label 삭제',
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

class _RecommendedChip extends StatelessWidget {
  const _RecommendedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.bodyMedium,
      onPressed: onTap,
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.brand),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

/// `03_커뮤니티_검색결과` + `03_커뮤니티_검색_없음`.
class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.keyword, required this.onEditKeyword});

  final String keyword;
  final VoidCallback onEditKeyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(communitySearchResultProvider);
    final filter = ref.watch(communitySearchFilterProvider);

    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        if (data.isEmpty) {
          // 결과가 없을 때는 필터 칩도 숨긴다 (`03_커뮤니티_검색_없음`).
          return CommunityEmptyState(
            icon: Icons.cancel_outlined,
            title: '검색 결과가 없어요',
            description: '다른 검색어로 다시 시도해 보세요.\n지역이나 구체적인 장소명을 넣으시면 도움이 됩니다.',
            actionLabel: '검색어 수정',
            onAction: onEditKeyword,
            actionStyle: CommunityEmptyActionStyle.outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterRow(
              selected: filter,
              onSelected: (value) => ref
                  .read(communitySearchFilterProvider.notifier)
                  .select(value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _ResultCount(count: data.totalCount),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  if (data.matchedRegion != null)
                    MatchedRegionCard(region: data.matchedRegion!),
                  if (data.places.isNotEmpty)
                    SearchSection(
                      title: '장소',
                      children: [
                        for (final place in data.places)
                          SearchPlaceRow(place: place),
                      ],
                    ),
                  if (data.users.isNotEmpty)
                    SearchSection(
                      title: '사용자',
                      children: [
                        for (final user in data.users)
                          SearchUserRow(user: user),
                      ],
                    ),
                  if (data.tags.isNotEmpty)
                    SearchSection(
                      title: '태그',
                      children: [SearchTagWrap(tags: data.tags)],
                    ),
                  if (data.posts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('사진', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    for (final post in data.posts) ...[
                      CommunityPostCard(
                        post: post,
                        onTap: () => context.push('/photos/${post.postId}'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final CommunitySearchFilter selected;
  final ValueChanged<CommunitySearchFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final filter in CommunitySearchFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: Text(filter.label),
                labelStyle: Theme.of(context).textTheme.bodyMedium,
                selected: filter == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(filter),
                backgroundColor: AppColors.card,
                selectedColor: AppColors.brand,
                side: BorderSide(
                  color: filter == selected
                      ? AppColors.brand
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "검색 결과 **24**건" — 숫자만 굵게 표시한다.
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: '검색 결과 '),
          TextSpan(
            text: '$count',
            style: base?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const TextSpan(text: '건'),
        ],
      ),
    );
  }
}
