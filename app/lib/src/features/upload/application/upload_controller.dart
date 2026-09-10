import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/upload/data/device_upload_repository.dart';
import 'package:snap_here/src/features/upload/data/fake_upload_repository.dart';
import 'package:snap_here/src/features/upload/domain/upload_models.dart';
import 'package:snap_here/src/features/upload/domain/upload_repository.dart';

const _useFakeUpload = bool.fromEnvironment(
  'USE_FAKE_UPLOAD',
  defaultValue: false,
);

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  if (_useFakeUpload) return FakeUploadRepository();
  return DeviceUploadRepository(
    accessToken: ref.watch(authControllerProvider).value?.accessToken,
  );
});

enum UploadStep { gallery, review, form, complete }

enum UploadGalleryTab { recent, drafts }

abstract final class UploadLimits {
  static const photoCount = 4;
  static const userTagCount = 8;
}

@immutable
class UploadState {
  const UploadState({
    required this.recentPhotos,
    required this.draftPhotos,
    this.step = UploadStep.gallery,
    this.galleryTab = UploadGalleryTab.recent,
    this.selectedPhotoIds = const [],
    this.primaryPhotoId,
    this.title = '',
    this.description = '',
    this.placeMatches = const [],
    this.selectedPlace,
    this.locationMessage,
    this.isMatchingLocation = false,
    this.showValidation = false,
    this.isSubmitting = false,
    this.submitMessage,
    this.result,
    this.eventContext,
    this.userTags = const [],
  });

  final List<UploadPhoto> recentPhotos;
  final List<UploadPhoto> draftPhotos;
  final UploadStep step;
  final UploadGalleryTab galleryTab;
  final List<String> selectedPhotoIds;
  final String? primaryPhotoId;
  final String title;
  final String description;
  final List<UploadPlace> placeMatches;
  final UploadPlace? selectedPlace;
  final String? locationMessage;
  final bool isMatchingLocation;
  final bool showValidation;
  final bool isSubmitting;
  final String? submitMessage;
  final UploadResult? result;
  final UploadEventContext? eventContext;
  final List<String> userTags;

  List<UploadPhoto> get photos => [...recentPhotos, ...draftPhotos];

  List<UploadPhoto> get visiblePhotos => switch (galleryTab) {
    UploadGalleryTab.recent => recentPhotos,
    UploadGalleryTab.drafts => draftPhotos,
  };

  List<UploadPhoto> get selectedPhotos => selectedPhotoIds
      .map((id) => photos.firstWhere((photo) => photo.id == id))
      .toList();

  UploadPhoto? get primaryPhoto {
    final id = primaryPhotoId;
    if (id == null) return null;
    return photos.where((photo) => photo.id == id).firstOrNull;
  }

  UploadState copyWith({
    List<UploadPhoto>? recentPhotos,
    List<UploadPhoto>? draftPhotos,
    UploadStep? step,
    UploadGalleryTab? galleryTab,
    List<String>? selectedPhotoIds,
    String? primaryPhotoId,
    String? title,
    String? description,
    List<UploadPlace>? placeMatches,
    UploadPlace? selectedPlace,
    bool clearSelectedPlace = false,
    String? locationMessage,
    bool clearLocationMessage = false,
    bool? isMatchingLocation,
    bool? showValidation,
    bool? isSubmitting,
    String? submitMessage,
    bool clearSubmitMessage = false,
    UploadResult? result,
    UploadEventContext? eventContext,
    List<String>? userTags,
  }) => UploadState(
    recentPhotos: recentPhotos ?? this.recentPhotos,
    draftPhotos: draftPhotos ?? this.draftPhotos,
    step: step ?? this.step,
    galleryTab: galleryTab ?? this.galleryTab,
    selectedPhotoIds: selectedPhotoIds ?? this.selectedPhotoIds,
    primaryPhotoId: primaryPhotoId ?? this.primaryPhotoId,
    title: title ?? this.title,
    description: description ?? this.description,
    placeMatches: placeMatches ?? this.placeMatches,
    selectedPlace: clearSelectedPlace
        ? null
        : selectedPlace ?? this.selectedPlace,
    locationMessage: clearLocationMessage
        ? null
        : locationMessage ?? this.locationMessage,
    isMatchingLocation: isMatchingLocation ?? this.isMatchingLocation,
    showValidation: showValidation ?? this.showValidation,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitMessage: clearSubmitMessage
        ? null
        : submitMessage ?? this.submitMessage,
    result: result ?? this.result,
    eventContext: eventContext ?? this.eventContext,
    userTags: userTags ?? this.userTags,
  );
}

final uploadControllerProvider =
    AsyncNotifierProvider<UploadController, UploadState>(UploadController.new);

class UploadController extends AsyncNotifier<UploadState> {
  UploadRepository get _repository => ref.read(uploadRepositoryProvider);

  Future<void> openMediaSettings() => _repository.openMediaSettings();

  @override
  Future<UploadState> build() async {
    final results = await Future.wait([
      _repository.fetchGallery(),
      _repository.fetchDraftGallery(),
    ]);
    final recent = results[0];
    final drafts = results[1];
    final first = (recent.isNotEmpty ? recent : drafts).firstOrNull;
    return UploadState(
      recentPhotos: recent,
      draftPhotos: drafts,
      galleryTab: recent.isEmpty && drafts.isNotEmpty
          ? UploadGalleryTab.drafts
          : UploadGalleryTab.recent,
      selectedPhotoIds: first == null ? const [] : [first.id],
      primaryPhotoId: first?.id,
    );
  }

  void selectGalleryTab(UploadGalleryTab tab) {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(galleryTab: tab));
  }

  bool addCapturedPhoto(UploadPhoto photo) {
    final current = state.requireValue;
    if (_hasReachedPhotoLimit(current)) return false;
    final selected = [...current.selectedPhotoIds, photo.id];
    state = AsyncData(
      current.copyWith(
        recentPhotos: [photo, ...current.recentPhotos],
        galleryTab: UploadGalleryTab.recent,
        selectedPhotoIds: selected,
        primaryPhotoId: photo.id,
      ),
    );
    return true;
  }

  void togglePhoto(String id) {
    final current = state.requireValue;
    final selected = [...current.selectedPhotoIds];
    if (selected.contains(id)) {
      if (selected.length == 1) return;
      selected.remove(id);
    } else {
      if (_hasReachedPhotoLimit(current)) return;
      selected.add(id);
    }
    state = AsyncData(
      current.copyWith(
        selectedPhotoIds: selected,
        primaryPhotoId: selected.contains(current.primaryPhotoId)
            ? current.primaryPhotoId
            : selected.first,
      ),
    );
  }

  void setPrimary(String id) {
    final current = state.requireValue;
    if (!current.selectedPhotoIds.contains(id)) return;
    state = AsyncData(current.copyWith(primaryPhotoId: id));
  }

  void removePhoto(String id) => togglePhoto(id);

  void showReview() {
    final current = state.requireValue;
    if (current.selectedPhotoIds.isEmpty || current.primaryPhoto == null) {
      return;
    }
    state = AsyncData(current.copyWith(step: UploadStep.review));
  }

  void showGallery() {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(step: UploadStep.gallery));
  }

  Future<void> showForm() async {
    final current = state.requireValue;
    final primary = current.primaryPhoto;
    if (primary == null) return;
    _setData(
      current.copyWith(
        step: UploadStep.form,
        title: current.title.isEmpty ? primary.suggestedTitle ?? '' : null,
        isMatchingLocation: current.eventContext == null,
        clearLocationMessage: true,
        clearSubmitMessage: true,
      ),
    );
    if (current.eventContext != null) return;
    await _matchPlace(primary);
  }

  Future<void> _matchPlace(UploadPhoto primary) async {
    try {
      final places = await _repository.matchPlaces(primary);
      if (!ref.mounted) return;
      _setData(
        state.requireValue.copyWith(
          placeMatches: places,
          selectedPlace: places.firstOrNull,
          clearSelectedPlace: places.isEmpty,
          isMatchingLocation: false,
          locationMessage: places.isEmpty ? '주변 장소를 찾지 못했어요.' : null,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      _setData(
        state.requireValue.copyWith(
          placeMatches: const [],
          clearSelectedPlace: true,
          isMatchingLocation: false,
          locationMessage: '$error',
        ),
      );
    }
  }

  void updateTitle(String value) {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(title: value, showValidation: false));
  }

  void updateDescription(String value) {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(description: value));
  }

  void selectPlace(UploadPlace place) {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(selectedPlace: place, showValidation: false),
    );
  }

  void applyEventContext(UploadEventContext context) {
    final current = state.requireValue;
    if (current.eventContext?.eventId == context.eventId) return;
    state = AsyncData(
      current.copyWith(
        eventContext: context,
        placeMatches: [context.place],
        selectedPlace: context.place,
        clearLocationMessage: true,
        isMatchingLocation: false,
      ),
    );
  }

  void addUserTag(String value) {
    final current = state.requireValue;
    final normalized = value.trim().replaceFirst(RegExp(r'^#'), '');
    if (!_canAddUserTag(current, normalized)) return;
    state = AsyncData(
      current.copyWith(userTags: [...current.userTags, normalized]),
    );
  }

  void removeUserTag(String value) {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        userTags: current.userTags.where((tag) => tag != value).toList(),
      ),
    );
  }

  Future<List<UploadPlace>> searchPlaces(String keyword) =>
      _repository.searchPlaces(keyword);

  Future<void> submit() async {
    final current = state.requireValue;
    if (!_hasValidForm(current)) {
      _setData(current.copyWith(showValidation: true));
      return;
    }
    final primary = current.primaryPhoto;
    if (primary == null) return;
    _setData(current.copyWith(isSubmitting: true, clearSubmitMessage: true));
    try {
      final result = await _repository.createPost(
        _createDraft(current, primary),
      );
      if (!ref.mounted) return;
      _setData(
        current.copyWith(
          step: UploadStep.complete,
          isSubmitting: false,
          result: result,
          clearSubmitMessage: true,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      _setData(
        state.requireValue.copyWith(
          isSubmitting: false,
          submitMessage: '게시물을 등록하지 못했어요. 잠시 후 다시 시도해 주세요.',
        ),
      );
    }
  }

  bool _hasReachedPhotoLimit(UploadState current) =>
      current.selectedPhotoIds.length >= UploadLimits.photoCount;

  bool _canAddUserTag(UploadState current, String tag) =>
      tag.isNotEmpty &&
      current.userTags.length < UploadLimits.userTagCount &&
      !current.userTags.contains(tag) &&
      current.eventContext?.fixedTags.contains(tag) != true;

  bool _hasValidForm(UploadState current) =>
      current.title.trim().isNotEmpty && current.selectedPlace != null;

  UploadDraft _createDraft(UploadState current, UploadPhoto primary) =>
      UploadDraft(
        photos: current.selectedPhotos,
        primaryPhoto: primary,
        title: current.title.trim(),
        description: current.description.trim(),
        place: current.selectedPlace!,
        eventId: current.eventContext?.eventId,
        fixedTags: current.eventContext?.fixedTags ?? const [],
        userTags: current.userTags,
      );

  void _setData(UploadState value) => state = AsyncData(value);
}
