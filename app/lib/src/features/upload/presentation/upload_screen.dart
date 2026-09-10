import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image;
import 'package:snap_here/src/app/theme/app_tokens.dart';
import 'package:snap_here/src/features/event/application/event_providers.dart';
import 'package:snap_here/src/features/event/domain/event_models.dart';
import 'package:snap_here/src/features/upload/application/upload_controller.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';

Future<String> _cropCapturedPhoto(Map<String, Object> request) async {
  final sourcePath = request['path']! as String;
  final targetRatio = request['ratio']! as double;
  final decoded = image.decodeImage(await File(sourcePath).readAsBytes());
  if (decoded == null) throw const FormatException('촬영한 사진을 읽지 못했습니다.');
  final oriented = image.bakeOrientation(decoded);
  final currentRatio = oriented.width / oriented.height;
  final int cropWidth;
  final int cropHeight;
  if (currentRatio > targetRatio) {
    cropHeight = oriented.height;
    cropWidth = (cropHeight * targetRatio).round();
  } else {
    cropWidth = oriented.width;
    cropHeight = (cropWidth / targetRatio).round();
  }
  final cropped = image.copyCrop(
    oriented,
    x: (oriented.width - cropWidth) ~/ 2,
    y: (oriented.height - cropHeight) ~/ 2,
    width: cropWidth,
    height: cropHeight,
  );
  final extensionIndex = sourcePath.lastIndexOf('.');
  final basePath = extensionIndex > 0
      ? sourcePath.substring(0, extensionIndex)
      : sourcePath;
  final outputPath = '$basePath-cropped.jpg';
  await File(outputPath).writeAsBytes(image.encodeJpg(cropped, quality: 95));
  return outputPath;
}

Future<bool> _confirmUploadCancel(BuildContext context) async {
  final shouldCancel = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('업로드를 취소할까요?'),
      content: const Text('선택한 사진과 작성 중인 내용이 사라집니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('계속 작성'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('업로드 취소'),
        ),
      ],
    ),
  );
  return shouldCancel ?? false;
}

class UploadScreen extends ConsumerWidget {
  const UploadScreen({this.eventId, super.key});

  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(uploadControllerProvider);
    final eventUpload = eventId == null
        ? null
        : ref.watch(eventUploadContextProvider(eventId!));
    if (eventUpload?.isLoading == true) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventUpload?.hasError == true) {
      return _buildEventError(ref, eventUpload!.error);
    }
    final resolvedEvent = eventUpload?.value;
    return upload.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _buildUploadError(ref, error),
      data: (state) => _buildFlow(ref, state, resolvedEvent),
    );
  }

  Widget _buildEventError(WidgetRef ref, Object? error) => Scaffold(
    appBar: AppBar(title: const Text('이벤트 참여')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(eventUploadContextProvider(eventId!)),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildUploadError(WidgetRef ref, Object error) => Scaffold(
    appBar: AppBar(title: const Text('새 게시물')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('사진을 불러오지 못했어요\n$error', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => ref.invalidate(uploadControllerProvider),
            child: const Text('다시 시도'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () =>
                ref.read(uploadControllerProvider.notifier).openMediaSettings(),
            child: const Text('앱 설정 열기'),
          ),
        ],
      ),
    ),
  );

  Widget _buildFlow(
    WidgetRef ref,
    UploadState state,
    EventUploadContext? resolvedEvent,
  ) {
    if (resolvedEvent != null &&
        state.eventContext?.eventId != resolvedEvent.event.eventId) {
      _applyEventContextAfterBuild(ref, resolvedEvent);
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _UploadFlowPopScope(
      state: state,
      child: switch (state.step) {
        UploadStep.gallery => _GalleryStep(state),
        UploadStep.review => _ReviewStep(state),
        UploadStep.form => _FormStep(state),
        UploadStep.complete => _CompleteStep(state),
      },
    );
  }

  void _applyEventContextAfterBuild(
    WidgetRef ref,
    EventUploadContext resolvedEvent,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(uploadControllerProvider.notifier)
          .applyEventContext(
            UploadEventContext(
              eventId: resolvedEvent.event.eventId,
              eventTitle: resolvedEvent.event.title,
              place: UploadPlace(
                id: resolvedEvent.place.placeId,
                name: resolvedEvent.place.name,
                address: resolvedEvent.place.address,
              ),
              fixedTags: resolvedEvent.fixedTags,
              verifyRadiusM: resolvedEvent.verifyRadiusM,
              badgeTitle: resolvedEvent.badge?.name,
            ),
          );
    });
  }
}

class _UploadFlowPopScope extends ConsumerStatefulWidget {
  const _UploadFlowPopScope({required this.state, required this.child});

  final UploadState state;
  final Widget child;

  @override
  ConsumerState<_UploadFlowPopScope> createState() =>
      _UploadFlowPopScopeState();
}

class _UploadFlowPopScopeState extends ConsumerState<_UploadFlowPopScope> {
  bool _allowPop = false;

  Future<void> _handlePop() async {
    final controller = ref.read(uploadControllerProvider.notifier);
    switch (widget.state.step) {
      case UploadStep.gallery:
        if (!await _confirmUploadCancel(context) || !mounted) return;
        setState(() => _allowPop = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
        return;
      case UploadStep.review:
        controller.showGallery();
        return;
      case UploadStep.form:
        controller.showReview();
        return;
      case UploadStep.complete:
        context.go('/home');
        return;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _handlePop();
    },
    child: widget.child,
  );
}

class _GalleryStep extends ConsumerWidget {
  const _GalleryStep(this.state);
  final UploadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(uploadControllerProvider.notifier);
    return Scaffold(
      appBar: UploadAppBar(
        title: '새 게시물',
        onClose: () => Navigator.of(context).maybePop(),
        closeTooltip: '업로드 취소',
        leadingIcon: Icons.close,
        actionLabel: '다음 (${state.selectedPhotoIds.length})',
        onAction: state.selectedPhotoIds.isEmpty ? null : controller.showReview,
      ),
      body: Column(
        children: [
          if (state.primaryPhoto case final primary?)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.34,
                ),
                child: AspectRatio(
                  aspectRatio: 412 / 310,
                  child: _PhotoImage(
                    photo: primary,
                    key: const Key('upload-primary-preview'),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            )
          else
            const SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 40),
                    SizedBox(height: AppSpacing.sm),
                    Text('사진을 선택하거나 촬영해 주세요'),
                  ],
                ),
              ),
            ),
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                _GalleryTabButton(
                  label: '최근',
                  selected: state.galleryTab == UploadGalleryTab.recent,
                  onTap: () =>
                      controller.selectGalleryTab(UploadGalleryTab.recent),
                ),
                const SizedBox(width: AppSpacing.xl),
                _GalleryTabButton(
                  label: '임시 저장 피드',
                  selected: state.galleryTab == UploadGalleryTab.drafts,
                  onTap: () =>
                      controller.selectGalleryTab(UploadGalleryTab.drafts),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                state.galleryTab == UploadGalleryTab.drafts &&
                    state.visiblePhotos.isEmpty
                ? const Center(child: Text('저장된 사진이 없어요'))
                : GridView.builder(
                    key: const Key('upload-gallery-grid'),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                    itemCount:
                        state.visiblePhotos.length +
                        (state.galleryTab == UploadGalleryTab.recent ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasCamera =
                          state.galleryTab == UploadGalleryTab.recent;
                      if (hasCamera && index == 0) {
                        return InkWell(
                          key: const Key('upload-camera-tile'),
                          onTap: () async {
                            await _capturePhoto(context, controller);
                          },
                          child: const ColoredBox(
                            color: Color(0xFF21262E),
                            child: Icon(
                              Icons.photo_camera,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }
                      final photo =
                          state.visiblePhotos[index - (hasCamera ? 1 : 0)];
                      final order = state.selectedPhotoIds.indexOf(photo.id);
                      return _GalleryTile(
                        photo: photo,
                        order: order < 0 ? null : order + 1,
                        onTap: () {
                          _togglePhoto(context, controller, photo, order);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _capturePhoto(
    BuildContext context,
    UploadController controller,
  ) async {
    if (_photoLimitReached) {
      _showSelectionMessage(context, _photoLimitMessage);
      return;
    }
    final photo = await Navigator.of(context).push<UploadPhoto>(
      MaterialPageRoute(builder: (_) => const _CameraPreviewScreen()),
    );
    if (photo == null) return;
    final added = controller.addCapturedPhoto(photo);
    if (!added && context.mounted) {
      _showSelectionMessage(context, _photoLimitMessage);
    }
  }

  void _togglePhoto(
    BuildContext context,
    UploadController controller,
    UploadPhoto photo,
    int order,
  ) {
    if (order < 0 && _photoLimitReached) {
      _showSelectionMessage(context, _photoLimitMessage);
      return;
    }
    if (order >= 0 && state.selectedPhotoIds.length == 1) {
      _showSelectionMessage(context, '사진을 한 장 이상 선택해 주세요.');
      return;
    }
    controller.togglePhoto(photo.id);
    if (order < 0) controller.setPrimary(photo.id);
  }

  bool get _photoLimitReached =>
      state.selectedPhotoIds.length >= UploadLimits.photoCount;

  static const _photoLimitMessage =
      '사진은 최대 ${UploadLimits.photoCount}장까지 선택할 수 있어요.';

  void _showSelectionMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep(this.state);
  final UploadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(uploadControllerProvider.notifier);
    return Scaffold(
      appBar: UploadAppBar(
        title: '사진 확인',
        onClose: controller.showGallery,
        closeTooltip: '사진 선택으로 돌아가기',
        leadingIcon: Icons.arrow_back,
        actionLabel: '다음',
        onAction: controller.showForm,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: state.primaryPhoto!.aspectRatio ?? 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: _PhotoImage(
                          photo: state.primaryPhoto!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const Positioned(left: 16, top: 16, child: _PrimaryBadge()),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '선택한 사진 (${state.selectedPhotoIds.length}/${UploadLimits.photoCount})',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.selectedPhotos.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == state.selectedPhotos.length) {
                      return _AddPhotoButton(controller.showGallery);
                    }
                    final photo = state.selectedPhotos[index];
                    return _SelectedThumbnail(
                      photo: photo,
                      primary: photo.id == state.primaryPhotoId,
                      canRemove: state.selectedPhotos.length > 1,
                      onSelect: () => controller.setPrimary(photo.id),
                      onRemove: () => controller.removePhoto(photo.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormStep extends ConsumerWidget {
  const _FormStep(this.state);
  final UploadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(uploadControllerProvider.notifier);
    final titleInvalid = state.showValidation && state.title.trim().isEmpty;
    final placeInvalid = state.showValidation && state.selectedPlace == null;

    Future<void> openPlaceSearch() async {
      final place = await Navigator.of(context).push<UploadPlace>(
        MaterialPageRoute(builder: (_) => const _PlaceSearchScreen()),
      );
      if (place != null) controller.selectPlace(place);
    }

    return Scaffold(
      appBar: UploadAppBar(
        title: '게시글 작성',
        onClose: controller.showReview,
        closeTooltip: '사진 확인으로 돌아가기',
        leadingIcon: Icons.arrow_back,
        actionLabel: state.isSubmitting ? '등록 중' : '게시',
        onAction: state.isSubmitting ? null : controller.submit,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (state.eventContext case final eventContext?) ...[
                _EventUploadBanner(context: eventContext),
                const SizedBox(height: AppSpacing.lg),
              ],
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.selectedPhotos.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: _PhotoImage(
                      photo: state.selectedPhotos[index],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('제목', isRequired: true),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: ValueKey('title-${state.primaryPhotoId}'),
                initialValue: state.title,
                maxLength: 80,
                onChanged: controller.updateTitle,
                decoration: InputDecoration(
                  hintText: '제목을 입력하세요',
                  errorText: titleInvalid ? '제목을 입력해 주세요' : null,
                  constraints: const BoxConstraints(minHeight: 46),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FieldLabel(
                    state.placeMatches.isEmpty ? '장소' : '장소 · GPS 자동 매칭',
                    isRequired: state.placeMatches.isEmpty,
                  ),
                  if (state.placeMatches.isNotEmpty)
                    Text(
                      '자동 매칭 완료',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.isMatchingLocation) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(child: Text('GPS로 주변 장소를 찾고 있어요')),
                      TextButton(
                        onPressed: openPlaceSearch,
                        child: const Text('직접 검색'),
                      ),
                    ],
                  ),
                ),
              ] else if (state.placeMatches.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(state.locationMessage ?? '주변 장소를 찾지 못했어요'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: openPlaceSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('장소 직접 검색'),
                  ),
                ),
              ] else ...[
                for (final place in state.placeMatches) ...[
                  _PlaceOption(
                    place,
                    selected: place.id == state.selectedPlace?.id,
                    onTap: () => controller.selectPlace(place),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    TextButton(
                      onPressed: openPlaceSearch,
                      child: const Text('장소 변경'),
                    ),
                  ],
                ),
              ],
              if (placeInvalid)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '장소를 선택해 주세요',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 20),
              const _FieldLabel('내용 (선택)'),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                initialValue: state.description,
                onChanged: controller.updateDescription,
                minLines: 4,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '사진에 대해 한마디...',
                  constraints: BoxConstraints(minHeight: 100),
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
              if (state.eventContext case final eventContext?) ...[
                const SizedBox(height: AppSpacing.lg),
                const _FieldLabel('이벤트 태그'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final tag in eventContext.fixedTags)
                      Chip(
                        avatar: const Icon(Icons.lock_outline, size: 14),
                        label: Text('#$tag'),
                      ),
                    for (final tag in state.userTags)
                      InputChip(
                        label: Text('#$tag'),
                        onDeleted: () => controller.removeUserTag(tag),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  enabled: state.userTags.length < UploadLimits.userTagCount,
                  textInputAction: TextInputAction.done,
                  onSubmitted: controller.addUserTag,
                  decoration: InputDecoration(
                    hintText: state.userTags.length < UploadLimits.userTagCount
                        ? '태그 입력 후 완료 (${state.userTags.length}/${UploadLimits.userTagCount})'
                        : '자유 태그를 모두 입력했어요',
                    prefixText: '# ',
                    constraints: const BoxConstraints(minHeight: 46),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '잠긴 태그 2개는 행사 참여 확인을 위해 변경할 수 없어요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (state.submitMessage case final message?) ...[
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventUploadBanner extends StatelessWidget {
  const _EventUploadBanner({required this.context});

  final UploadEventContext context;

  @override
  Widget build(BuildContext buildContext) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.brandSubtle,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.brand),
    ),
    child: Row(
      children: [
        const Icon(Icons.celebration_outlined, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.eventTitle,
                style: Theme.of(buildContext).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${context.place.name} · 인증 반경 ${context.verifyRadiusM}m',
                style: Theme.of(buildContext).textTheme.bodySmall,
              ),
              if (context.badgeTitle case final badge?)
                Text(
                  '획득 가능: $badge',
                  style: Theme.of(buildContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CompleteStep extends StatelessWidget {
  const _CompleteStep(this.state);
  final UploadState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: 64),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.brandSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 40,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '업로드 완료!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '게시글이 등록되었어요',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              if (result.badgeTitle != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.brand, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.brandSubtle,
                        child: Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.badgeTitle!,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            if (result.badgeDescription case final description?)
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 51,
                child: FilledButton(
                  onPressed: () {
                    final router = GoRouter.of(context);
                    router.go('/home');
                    router.push('/photos/${result.postId}');
                  },
                  child: const Text('게시글 보기'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 51,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('홈 지도에서 확인'),
                ),
              ),
              const SizedBox(height: 72),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadAppBar extends AppBar {
  UploadAppBar({
    required String title,
    required VoidCallback onClose,
    required String closeTooltip,
    required IconData leadingIcon,
    String? actionLabel,
    VoidCallback? onAction,
    super.key,
  }) : super(
         leading: IconButton(
           tooltip: closeTooltip,
           onPressed: onClose,
           icon: Icon(leadingIcon),
         ),
         titleSpacing: 0,
         title: Text(
           title,
           style: const TextStyle(
             color: AppColors.brand,
             fontSize: 18,
             fontWeight: FontWeight.w700,
           ),
         ),
         actions: [
           if (actionLabel != null)
             Padding(
               padding: const EdgeInsets.only(right: AppSpacing.lg),
               child: TextButton(
                 onPressed: onAction,
                 style: TextButton.styleFrom(
                   backgroundColor: AppColors.brandSubtle,
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(AppRadius.sm),
                   ),
                 ),
                 child: Text(actionLabel),
               ),
             ),
         ],
         bottom: const PreferredSize(
           preferredSize: Size.fromHeight(1),
           child: Divider(),
         ),
       );
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.photo,
    required this.order,
    required this.onTap,
  });
  final UploadPhoto photo;
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('gallery-${photo.id}'),
    onTap: onTap,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _PhotoImage(photo: photo, fit: BoxFit.cover),
        if (order != null)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$order',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CameraPreviewScreen extends StatefulWidget {
  const _CameraPreviewScreen();

  @override
  State<_CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

enum _CameraViewRatio {
  square('1:1', 1),
  fourThree('4:3', 3 / 4),
  sixteenNine('16:9', 9 / 16);

  const _CameraViewRatio(this.label, this.portraitAspectRatio);

  final String label;
  final double portraitAspectRatio;
}

class _CameraPreviewScreenState extends State<_CameraPreviewScreen>
    with WidgetsBindingObserver {
  static const _systemUiChannel = MethodChannel(
    'com.snaphere.snap_here/system_ui',
  );

  List<CameraDescription> _cameras = const [];
  CameraController? _cameraController;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.auto;
  String? _error;
  bool _takingPicture = false;
  bool _initializing = false;
  double _minimumZoom = 1;
  double _maximumZoom = 1;
  double _zoom = 1;
  double _zoomAtScaleStart = 1;
  _CameraViewRatio _viewRatio = _CameraViewRatio.fourThree;
  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setCameraFullscreen(enabled: true));
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    _initializeCamera();
  }

  Future<void> _setCameraFullscreen({required bool enabled}) async {
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (!Platform.isAndroid) return;
    try {
      await _systemUiChannel.invokeMethod<void>(
        enabled ? 'enterCameraFullscreen' : 'exitCameraFullscreen',
      );
    } on PlatformException {
      // SystemChrome remains the fallback on unsupported Android hosts.
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', '사용 가능한 카메라가 없습니다.');
      }
      final previous = _cameraController;
      final controller = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController = controller;
      await previous?.dispose();
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      final zoomLevels = await Future.wait([
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);
      if (mounted) {
        setState(() {
          _minimumZoom = zoomLevels[0];
          _maximumZoom = zoomLevels[1];
          _zoom = _zoom.clamp(_minimumZoom, _maximumZoom);
          _error = null;
        });
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _error = switch (error.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' =>
              '카메라 권한이 필요합니다. 기기 설정에서 카메라 접근을 허용해 주세요.',
            _ => error.description ?? '카메라를 시작하지 못했어요.',
          };
        });
      }
    } finally {
      _initializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _cameraController = null;
      if (controller != null) unawaited(controller.dispose());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_setCameraFullscreen(enabled: true));
      if (controller == null || !controller.value.isInitialized) {
        _initializeCamera();
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtScaleStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        details.pointerCount < 2) {
      return;
    }
    final nextZoom = (_zoomAtScaleStart * details.scale).clamp(
      _minimumZoom,
      _maximumZoom,
    );
    if ((nextZoom - _zoom).abs() < 0.01) return;
    setState(() => _zoom = nextZoom);
    unawaited(controller.setZoomLevel(nextZoom).catchError((_) {}));
  }

  Offset _normalizePreviewPoint(
    Offset localPosition,
    Size viewportSize,
    CameraController controller,
  ) {
    final cameraPreviewSize = controller.value.previewSize;
    if (cameraPreviewSize == null) {
      return Offset(
        (localPosition.dx / viewportSize.width).clamp(0, 1),
        (localPosition.dy / viewportSize.height).clamp(0, 1),
      );
    }

    final sourceSize = Size(cameraPreviewSize.height, cameraPreviewSize.width);
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, viewportSize);
    final sourceOffset = Offset(
      (sourceSize.width - fitted.source.width) / 2,
      (sourceSize.height - fitted.source.height) / 2,
    );
    return Offset(
      ((sourceOffset.dx +
                  localPosition.dx *
                      fitted.source.width /
                      fitted.destination.width) /
              sourceSize.width)
          .clamp(0, 1),
      ((sourceOffset.dy +
                  localPosition.dy *
                      fitted.source.height /
                      fitted.destination.height) /
              sourceSize.height)
          .clamp(0, 1),
    );
  }

  Future<void> _focusAt(TapDownDetails details, Size previewSize) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final normalizedPoint = _normalizePreviewPoint(
      details.localPosition,
      previewSize,
      controller,
    );
    final visiblePoint = Offset(
      (details.localPosition.dx / previewSize.width).clamp(0, 1),
      (details.localPosition.dy / previewSize.height).clamp(0, 1),
    );

    _focusIndicatorTimer?.cancel();
    if (mounted) setState(() => _focusPoint = visiblePoint);
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _focusPoint = null);
    });

    try {
      final focusOperations = <Future<void>>[];
      if (controller.value.focusPointSupported) {
        focusOperations.add(controller.setFocusPoint(normalizedPoint));
      }
      if (controller.value.exposurePointSupported) {
        focusOperations.add(controller.setExposurePoint(normalizedPoint));
      }
      await Future.wait(focusOperations);
    } on CameraException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.description ?? '초점을 맞추지 못했어요.')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final next = _flashMode == FlashMode.auto ? FlashMode.off : FlashMode.auto;
    await controller.setFlashMode(next);
    if (mounted) setState(() => _flashMode = next);
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return;
    }
    setState(() => _takingPicture = true);
    try {
      final file = await controller.takePicture();
      final croppedPath = await compute(_cropCapturedPhoto, {
        'path': file.path,
        'ratio': _viewRatio.portraitAspectRatio,
      });
      if (!mounted) return;
      Navigator.of(context).pop(
        UploadPhoto(
          id: 'camera-${DateTime.now().microsecondsSinceEpoch}',
          filePath: croppedPath,
          source: UploadPhotoSource.camera,
          aspectRatio: _viewRatio.portraitAspectRatio,
        ),
      );
    } on CameraException catch (error) {
      if (mounted) {
        setState(() => _error = error.description ?? '사진 촬영에 실패했어요.');
      }
    } finally {
      if (mounted) setState(() => _takingPicture = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    _cameraController?.dispose();
    unawaited(_setCameraFullscreen(enabled: false));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final ready = controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFF111317),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _viewRatio.portraitAspectRatio,
              child: _buildPreview(controller, ready),
            ),
          ),
          _buildTopControls(ready),
          _buildBottomControls(ready),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController? controller, bool ready) {
    final error = _error;
    if (error != null) return _buildCameraError(error);
    if (!ready || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (_, constraints) =>
          _buildInteractivePreview(controller, constraints.biggest),
    );
  }

  Widget _buildCameraError(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );

  Widget _buildInteractivePreview(CameraController controller, Size size) {
    final cameraSize = controller.value.previewSize!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onTapDown: (details) => _focusAt(details, size),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraSize.height,
                height: cameraSize.width,
                child: CameraPreview(controller),
              ),
            ),
            if (_focusPoint case final point?)
              _buildFocusIndicator(point, size),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.lg,
              child: Center(child: _buildZoomBadge()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusIndicator(Offset point, Size size) => Positioned(
    left: point.dx * size.width - 28,
    top: point.dy * size.height - 28,
    child: IgnorePointer(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    ),
  );

  Widget _buildTopControls(bool ready) => SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: '카메라 닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: ready ? _toggleFlash : null,
                  icon: Icon(_flashIcon, color: Colors.white),
                  label: Text(
                    _flashLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRatioSelector(),
        ],
      ),
    ),
  );

  Widget _buildBottomControls(bool ready) => SafeArea(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: _cameras.length > 1 ? _switchCamera : null,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
            _buildShutterButton(ready),
            IconButton.filledTonal(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.image_outlined),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildShutterButton(bool ready) => InkWell(
    key: const Key('upload-shutter'),
    onTap: ready && !_takingPicture ? _takePicture : null,
    customBorder: const CircleBorder(),
    child: Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    ),
  );

  IconData get _flashIcon =>
      _flashMode == FlashMode.auto ? Icons.flash_auto : Icons.flash_off;

  String get _flashLabel => _flashMode == FlashMode.auto ? '자동' : '끔';

  Widget _buildRatioSelector() => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ratio in _CameraViewRatio.values)
          TextButton(
            onPressed: () => setState(() => _viewRatio = ratio),
            style: TextButton.styleFrom(
              foregroundColor: ratio == _viewRatio
                  ? AppColors.brand
                  : Colors.white70,
              minimumSize: const Size(56, 40),
            ),
            child: Text(
              ratio.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );

  Widget _buildZoomBadge() => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      '${_zoom.toStringAsFixed(1)}x',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
  );
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_outline, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text('대표 사진', style: TextStyle(color: Colors.white, fontSize: 11)),
      ],
    ),
  );
}

class _SelectedThumbnail extends StatelessWidget {
  const _SelectedThumbnail({
    required this.photo,
    required this.primary,
    required this.canRemove,
    required this.onSelect,
    required this.onRemove,
  });
  final UploadPhoto photo;
  final bool primary;
  final bool canRemove;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onSelect,
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _PhotoImage(photo: photo, fit: BoxFit.cover),
            ),
          ),
          if (primary)
            const Positioned(left: 6, top: 6, child: _TinyIcon(Icons.star)),
          if (canRemove)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: '사진 삭제',
                onPressed: onRemove,
                icon: const _TinyIcon(Icons.close),
              ),
            ),
        ],
      ),
    ),
  );
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Colors.black54,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 11, color: Colors.white),
  );
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton(this.onTap);
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, color: AppColors.textSecondary),
          SizedBox(height: 4),
          Text('사진 추가', style: TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

class _GalleryTabButton extends StatelessWidget {
  const _GalleryTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({
    required this.photo,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final UploadPhoto photo;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.thumbnailBytes;
    if (bytes != null) {
      return Image.memory(bytes, width: width, height: height, fit: fit);
    }
    final filePath = photo.filePath;
    if (filePath != null) {
      return Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
      );
    }
    final assetPath = photo.assetPath;
    if (assetPath != null) {
      return Image.asset(assetPath, width: width, height: height, fit: fit);
    }
    return ColoredBox(
      color: AppColors.border,
      child: SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.isRequired = false});
  final String label;
  final bool isRequired;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      children: [
        if (isRequired)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error),
          ),
      ],
    ),
    style: Theme.of(context).textTheme.labelLarge,
  );
}

class _PlaceOption extends StatelessWidget {
  const _PlaceOption(this.place, {required this.selected, required this.onTap});
  final UploadPlace place;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandSubtle : AppColors.card,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: selected ? AppColors.brand : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              place.name,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          if (place.distanceMeters != null)
            Text(
              '${place.distanceMeters}m',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check, size: 16, color: AppColors.brand),
          ],
        ],
      ),
    ),
  );
}

class _PlaceSearchScreen extends ConsumerStatefulWidget {
  const _PlaceSearchScreen();
  @override
  ConsumerState<_PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<_PlaceSearchScreen> {
  final _searchController = TextEditingController();
  late Future<List<UploadPlace>> _results;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _results = Future.value(const []);
  }

  Future<List<UploadPlace>> _search(String keyword) =>
      ref.read(uploadControllerProvider.notifier).searchPlaces(keyword);

  void _submit(String keyword) {
    final query = keyword.trim();
    if (query.isEmpty) return;
    setState(() {
      _hasSearched = true;
      _results = _search(query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('장소 검색')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            key: const Key('upload-place-search'),
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: '장소 이름 또는 주소',
              constraints: BoxConstraints(minHeight: 42),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<UploadPlace>>(
              future: _results,
              builder: (_, snapshot) => _buildResults(snapshot),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildResults(AsyncSnapshot<List<UploadPlace>> snapshot) {
    if (!_hasSearched) {
      return const Center(child: Text('장소 이름이나 주소를 검색해 주세요'));
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) return _buildSearchError();
    final places = snapshot.data ?? const [];
    if (places.isEmpty) return const Center(child: Text('검색 결과가 없어요'));
    return _buildPlaceList(places);
  }

  Widget _buildSearchError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('장소 검색에 실패했어요'),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: () => _submit(_searchController.text),
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );

  Widget _buildPlaceList(List<UploadPlace> places) => ListView.separated(
    itemCount: places.length,
    separatorBuilder: (_, _) => const Divider(),
    itemBuilder: (context, index) {
      final place = places[index];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.brandSubtle,
          child: Icon(Icons.location_on_outlined, color: AppColors.brand),
        ),
        title: Text(place.name),
        subtitle: Text(place.address),
        onTap: () => Navigator.of(context).pop(place),
      );
    },
  );
}
