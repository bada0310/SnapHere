import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_here/src/features/auth/application/auth_controller.dart';
import 'package:snap_here/src/features/upload/data/device_upload_repository.dart';
import 'package:snap_here/src/features/upload/data/fake_upload_repository.dart';
import 'package:snap_here/src/features/upload/domain/upload_failure.dart';
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

abstract final class UploadLimits {
  static const photoCount = 4;
  static const tagCount = 10;
  static const userTagCount = 8;
}

@immutable
class UploadState {
  const UploadState({
    required this.recentPhotos,
    this.step = UploadStep.gallery,
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
  final UploadStep step;
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

  List<String> get automaticTags =>
      eventContext?.fixedTags ??
      [
        if (selectedPlace case final place? when place.tagName.isNotEmpty)
          place.tagName,
      ];

  int get userTagLimit =>
      (UploadLimits.tagCount - (eventContext?.fixedTags.length ?? 1)).clamp(
        0,
        UploadLimits.tagCount,
      );

  List<UploadPhoto> get selectedPhotos => selectedPhotoIds
      .map((id) => recentPhotos.firstWhere((photo) => photo.id == id))
      .toList();

  UploadPhoto? get primaryPhoto {
    final id = primaryPhotoId;
    if (id == null) return null;
    return recentPhotos.where((photo) => photo.id == id).firstOrNull;
  }

  UploadState copyWith({
    List<UploadPhoto>? recentPhotos,
    UploadStep? step,
    List<String>? selectedPhotoIds,
    String? primaryPhotoId,
    bool clearPrimaryPhoto = false,
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
    step: step ?? this.step,
    selectedPhotoIds: selectedPhotoIds ?? this.selectedPhotoIds,
    primaryPhotoId: clearPrimaryPhoto
        ? null
        : primaryPhotoId ?? this.primaryPhotoId,
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
  int _locationMatchGeneration = 0;

  UploadRepository get _repository => ref.read(uploadRepositoryProvider);

  Future<void> openMediaSettings() => _repository.openMediaSettings();

  @override
  Future<UploadState> build() async {
    return UploadState(recentPhotos: await _repository.fetchGallery());
  }

  bool addCapturedPhoto(UploadPhoto photo) {
    final current = state.requireValue;
    if (_hasReachedPhotoLimit(current)) return false;
    final selected = [...current.selectedPhotoIds, photo.id];
    state = AsyncData(
      current.copyWith(
        recentPhotos: [photo, ...current.recentPhotos],
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
      selected.remove(id);
    } else {
      if (_hasReachedPhotoLimit(current)) return;
      selected.add(id);
    }
    state = AsyncData(
      current.copyWith(
        selectedPhotoIds: selected,
        primaryPhotoId:
            selected.isNotEmpty && selected.contains(current.primaryPhotoId)
            ? current.primaryPhotoId
            : selected.firstOrNull,
        clearPrimaryPhoto: selected.isEmpty,
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
    final generation = ++_locationMatchGeneration;
    try {
      final places = await _repository.matchPlaces(primary);
      if (!ref.mounted || generation != _locationMatchGeneration) return;
      _setData(
        state.requireValue.copyWith(
          placeMatches: places,
          selectedPlace: places.firstOrNull,
          clearSelectedPlace: places.isEmpty,
          isMatchingLocation: false,
          locationMessage: places.isEmpty ? '장소를 검색해 선택해 주세요.' : null,
          clearLocationMessage: places.isNotEmpty,
        ),
      );
    } catch (error) {
      if (!ref.mounted || generation != _locationMatchGeneration) return;
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
    _locationMatchGeneration++;
    _setData(
      current.copyWith(
        selectedPlace: place,
        showValidation: false,
        isMatchingLocation: false,
        clearLocationMessage: true,
      ),
    );
  }

  void applyEventContext(UploadEventContext context) {
    final current = state.requireValue;
    if (current.eventContext?.eventId == context.eventId) return;
    _locationMatchGeneration++;
    _setData(
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
    if (current.isSubmitting || current.step == UploadStep.complete) return;
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
    } catch (error) {
      if (!ref.mounted) return;
      _setData(
        state.requireValue.copyWith(
          isSubmitting: false,
          submitMessage: error is UploadFailure
              ? error.message
              : const UploadFailure(UploadFailureReason.resultUnknown).message,
        ),
      );
    }
  }

  bool _hasReachedPhotoLimit(UploadState current) =>
      current.selectedPhotoIds.length >= UploadLimits.photoCount;

  bool _canAddUserTag(UploadState current, String tag) =>
      normalizeUploadTag(tag).isNotEmpty &&
      current.userTags.length < current.userTagLimit &&
      ![...current.userTags, ...current.automaticTags].any(
        (existing) => normalizeUploadTag(existing) == normalizeUploadTag(tag),
      );

  bool _hasValidForm(UploadState current) =>
      current.title.trim().isNotEmpty &&
      current.selectedPlace != null &&
      (current.eventContext != null ||
          current.selectedPlace!.tagName.isNotEmpty);

  UploadDraft _createDraft(UploadState current, UploadPhoto primary) =>
      UploadDraft(
        photos: current.selectedPhotos,
        primaryPhoto: primary,
        title: current.title.trim(),
        description: current.description.trim(),
        place: current.selectedPlace!,
        eventId: current.eventContext?.eventId,
        fixedTags: current.automaticTags,
        userTags: current.userTags,
      );

  void _setData(UploadState value) {
    final seen = value.automaticTags.map(normalizeUploadTag).toSet();
    final userTags = value.userTags
        .where(
          (tag) =>
              normalizeUploadTag(tag).isNotEmpty &&
              seen.add(normalizeUploadTag(tag)),
        )
        .take(value.userTagLimit)
        .toList();
    state = AsyncData(value.copyWith(userTags: userTags));
  }
}
