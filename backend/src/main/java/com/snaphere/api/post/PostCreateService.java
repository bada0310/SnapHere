package com.snaphere.api.post;

import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.BadgeAwarder;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.EventParticipationRecorder;
import com.snaphere.api.place.EventFixedTagReader;
import com.snaphere.api.place.EventSnapshot;
import com.snaphere.api.place.EventSnapshotReader;
import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.dto.BadgeSummaryResponse;
import com.snaphere.api.post.dto.CreatePostRequest;
import com.snaphere.api.post.dto.CreatePostResponse;
import com.snaphere.api.post.dto.PostDetailResponse;
import com.snaphere.api.post.dto.PostImageRequest;
import com.snaphere.api.post.dto.TierResultResponse;
import com.snaphere.api.post.entity.PostEntity;
import com.snaphere.api.post.entity.PostImageEntity;
import com.snaphere.api.post.entity.PostTagEntity;
import com.snaphere.api.post.entity.TagEntity;
import com.snaphere.api.post.event.PostCreatedEvent;
import com.snaphere.api.post.repository.PostImageRepository;
import com.snaphere.api.post.repository.PostRepository;
import com.snaphere.api.post.repository.PostTagRepository;
import com.snaphere.api.post.repository.TagRepository;
import com.snaphere.api.post.tag.TagSuggestionService;
import com.snaphere.api.post.tier.GeoDistance;
import com.snaphere.api.post.tier.TierDecision;
import com.snaphere.api.post.tier.TierDecisionLogger;
import com.snaphere.api.post.tier.TierInput;
import com.snaphere.api.post.tier.TierPolicy;
import com.snaphere.api.post.tier.TierThresholds;
import com.snaphere.api.post.tier.VerifyRadiusResolver;
import com.snaphere.api.visit.VisitRecorder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.Map;
import java.util.UUID;

/**
 * API-PST-003 — 게시글 생성. (PST-016)
 *
 * <p>기능 명세: 2.3 사진·캡션·태그 &gt; 게시글 등록
 *
 * <p>클라이언트가 보낸 등급과 지역 코드는 쓰지 않는다. 등급은 미리보기와 같은
 * {@link TierPolicy} 로 다시 판정하고(PST-022) 지역 코드는 장소에서 역산한다(PST-018).
 * 미리보기와 실제 판정이 다르면 사용자가 속았다고 느끼므로 규칙은 한 곳에만 둔다.
 */
@Service
public class PostCreateService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final PostRepository posts;
    private final PostImageRepository postImages;
    private final PostTagRepository postTags;
    private final TagRepository tags;
    private final PlaceRepository places;
    private final EventSnapshotReader events;
    private final EventFixedTagReader eventFixedTags;
    private final EventParticipationRecorder participation;
    private final VerifyRadiusResolver radiusResolver;
    private final TierDecisionLogger decisionLogger;
    private final PostCreateValidator validator;
    private final UploadLimitChecker limitChecker;
    private final TagService tagService;
    private final TagSuggestionService tagSuggestionService;
    private final PostResponseAssembler assembler;
    private final VisitRecorder visitRecorder;
    private final BadgeAwarder badgeAwarder;
    private final ApplicationEventPublisher eventPublisher;

    public PostCreateService(PostRepository posts,
                             PostImageRepository postImages,
                             PostTagRepository postTags,
                             TagRepository tags,
                             PlaceRepository places,
                             EventSnapshotReader events,
                             EventFixedTagReader eventFixedTags,
                             EventParticipationRecorder participation,
                             VerifyRadiusResolver radiusResolver,
                             TierDecisionLogger decisionLogger,
                             PostCreateValidator validator,
                             UploadLimitChecker limitChecker,
                             TagService tagService,
                             TagSuggestionService tagSuggestionService,
                             PostResponseAssembler assembler,
                             VisitRecorder visitRecorder,
                             BadgeAwarder badgeAwarder,
                             ApplicationEventPublisher eventPublisher) {
        this.posts = posts;
        this.postImages = postImages;
        this.postTags = postTags;
        this.tags = tags;
        this.places = places;
        this.events = events;
        this.eventFixedTags = eventFixedTags;
        this.participation = participation;
        this.radiusResolver = radiusResolver;
        this.decisionLogger = decisionLogger;
        this.validator = validator;
        this.limitChecker = limitChecker;
        this.tagService = tagService;
        this.tagSuggestionService = tagSuggestionService;
        this.assembler = assembler;
        this.visitRecorder = visitRecorder;
        this.badgeAwarder = badgeAwarder;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public CreatePostResponse create(UUID userId, CreatePostRequest request) {
        OffsetDateTime now = OffsetDateTime.now(KST);

        List<PostImageRequest> images = validator.validateImages(request, userId);
        PlaceEntity place = loadPlace(request.placeId());
        EventSnapshot event = loadEvent(request.eventId());
        validator.validateTakenAt(request, now);

        // 한도·정지·중복은 태그를 만들기 전에 본다. 거부될 요청 때문에 태그 마스터에 행이
        // 남는 것을 막는다 (PST-029 ~ PST-032).
        limitChecker.check(userId, place.getPlaceId(), images, now);

        // 행사 고정 태그는 서버가 다시 넣는다. 클라이언트가 빼고 보내도 되살아난다 (EVT-019).
        List<String> fixedTagNames = fixedTagNames(request.eventId());
        validator.validateFreeTagCount(request.tagNamesOrEmpty().size(), fixedTagNames.size());

        // 고정 태그를 앞에 둔다. resolveAll 이 정규화 이름으로 중복을 지우면서 순서를 지키므로,
        // 사용자가 같은 이름을 직접 쳐도 고정 쪽이 남아 잠금이 풀리지 않는다 (EVT-018).
        List<String> allTagNames = new ArrayList<>(fixedTagNames);
        allTagNames.addAll(request.tagNamesOrEmpty());

        List<TagEntity> resolvedTags = tagService.resolveAll(allTagNames);
        validator.validateTagCount(resolvedTags.size());
        Set<String> lockedNames = normalizedNames(fixedTagNames);

        TierInput tierInput = buildTierInput(request, place, event, now);
        TierDecision decision = TierPolicy.decide(tierInput, TierThresholds.DEFAULT);

        // 지역 코드는 장소에서 가져온다. 요청 본문에는 애초에 받는 필드가 없다 (PST-018).
        PostEntity post = posts.save(PostEntity.create(
                userId, place.getPlaceId(), request.eventId(), place.getAreaCode(),
                request.content(), decision.tier(),
                request.lat(), request.lng(), request.takenAt(), request.source()));

        List<PostImageEntity> savedImages = saveImages(post.getPostId(), images);
        Set<String> suggestedNames = tagSuggestionService.suggestedNormalizedNames(
                place.getPlaceId(), request.eventId());
        List<PostTagEntity> savedTagLinks =
                saveTagLinks(post.getPostId(), resolvedTags, suggestedNames, lockedNames);

        decisionLogger.record(post.getPostId(), userId, place.getPlaceId(),
                request.eventId(), tierInput, decision);
        places.addPostCount(place.getPlaceId(), 1, now);

        // 행사 참여 수. 등급과 무관하게 센다 — 반경 밖 글도 참여 목록에는 나온다 (EVT-021).
        participation.recordIfEvent(request.eventId());

        boolean visitRecorded = visitRecorder.recordIfEligible(
                userId, place.getPlaceId(), post.getPostId(),
                decision.tier().countsForVisit(), now);
        List<AwardedBadge> awarded = badgeAwarder.awardForPost(
                userId, post.getPostId(), place.getPlaceId(), request.eventId(),
                decision.tier().eligibleForBadge());

        // 썸네일·EXIF 제거·해시 계산은 응답과 분리한다. 커밋 이후에 시작하므로 후처리
        // 스레드가 방금 만든 행을 볼 수 있다 (PST-019, PST-020).
        eventPublisher.publishEvent(new PostCreatedEvent(post.getPostId(), userId));

        return buildResponse(post, place, savedImages, resolvedTags, savedTagLinks,
                decision, visitRecorded, awarded);
    }

    /** 장소는 필수이고, 숨김·삭제된 장소도 없는 것으로 본다 (PST-002, PLC-023). */
    private PlaceEntity loadPlace(Long placeId) {
        long id = validator.requirePlaceId(placeId);
        return places.findByPlaceIdAndStatus(id, PlaceStatus.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND,
                        Map.of("placeId", id)));
    }

    /** 행사가 없으면 빈 목록. 숨긴 행사도 포트가 빈 목록을 준다 (EVT-018). */
    private List<String> fixedTagNames(Long eventId) {
        return eventId == null ? List.of() : eventFixedTags.fixedTagNames(eventId);
    }

    /**
     * 잠금 판정에 쓸 정규화 이름.
     *
     * <p>정규화해서 비교하는 이유: 고정 태그가 "서울" 인데 사용자가 " 서울 " 을 쳐서 같은
     * {@code tags} 행으로 합쳐질 수 있다. 표시 이름으로 비교하면 그 태그가 잠기지 않는다.
     */
    private static Set<String> normalizedNames(List<String> rawNames) {
        Set<String> normalized = new LinkedHashSet<>();
        for (String raw : rawNames) {
            if (raw == null || raw.isBlank()) {
                continue;
            }
            String name = TagEntity.normalize(raw);
            if (!name.isEmpty()) {
                normalized.add(name);
            }
        }
        return normalized;
    }

    private EventSnapshot loadEvent(Long eventId) {
        if (eventId == null) {
            return null;
        }
        return events.findById(eventId)
                .orElseThrow(() -> new ApiException(ErrorCode.EVENT_NOT_FOUND,
                        Map.of("eventId", eventId)));
    }

    // ─────────────────────────────────────────────────────────── 등급 판정 (PST-022)

    private TierInput buildTierInput(CreatePostRequest request, PlaceEntity place,
                                     EventSnapshot event, OffsetDateTime now) {
        int radiusM = radiusResolver.resolve(place.toSnapshot(), event);
        Integer distanceM = null;
        if (request.hasCoordinate() && place.hasCoordinate()) {
            distanceM = GeoDistance.meters(place.getLat(), place.getLng(), request.lat(), request.lng());
        }
        return new TierInput(request.source(), request.takenAt(), distanceM, radiusM,
                place.hasCoordinate(), now);
    }

    // ─────────────────────────────────────────────────────────── 저장

    private List<PostImageEntity> saveImages(Long postId, List<PostImageRequest> images) {
        List<PostImageEntity> entities = new ArrayList<>(images.size());
        for (PostImageRequest image : images) {
            entities.add(PostImageEntity.create(
                    postId, image.imageKey(), image.sortOrder(),
                    image.aspectRatio(), image.imageHash()));
        }
        List<PostImageEntity> saved = new ArrayList<>(postImages.saveAll(entities));
        saved.sort((a, b) -> Short.compare(a.getSortOrder(), b.getSortOrder()));
        return saved;
    }

    /**
     * 태그 연결과 사용 횟수 증가.
     *
     * <p>{@code isSuggested} 는 서버가 이 장소·행사에서 추천했을 태그와 겹치는지로 정한다
     * (CMU-029). 요청에 "추천에서 골랐다"는 표시를 받지 않는 이유는, 추천 칩을 누른 경우와 같은
     * 글자를 직접 타이핑한 경우를 서버가 구분할 수 없고 구분할 필요도 없기 때문이다 — 지표로 알고
     * 싶은 것은 "추천이 실제로 쓰였는가"다.
     *
     * <p>{@code isLocked} 는 행사 고정 태그에 붙는다 (EVT-018). 앱은 이 태그의 삭제 버튼을
     * 감추고, 서버는 등록 때마다 같은 태그를 다시 주입한다 — 두 장치가 함께 있어야 클라이언트를
     * 고쳐도 고정 태그가 빠지지 않는다 (EVT-019).
     */
    private List<PostTagEntity> saveTagLinks(Long postId, List<TagEntity> resolved,
                                             Set<String> suggestedNormalizedNames,
                                             Set<String> lockedNormalizedNames) {
        List<PostTagEntity> links = new ArrayList<>(resolved.size());
        List<Long> tagIds = new ArrayList<>(resolved.size());
        for (TagEntity tag : resolved) {
            boolean suggested = suggestedNormalizedNames.contains(tag.getNormalizedName());
            boolean locked = lockedNormalizedNames.contains(tag.getNormalizedName());
            links.add(PostTagEntity.of(postId, tag.getTagId(), locked, suggested));
            tagIds.add(tag.getTagId());
        }
        List<PostTagEntity> saved = new ArrayList<>(postTags.saveAll(links));
        tags.addUsageCount(tagIds, 1);
        return saved;
    }

    // ─────────────────────────────────────────────────────────── 응답 조립

    private CreatePostResponse buildResponse(PostEntity post, PlaceEntity place,
                                             List<PostImageEntity> images,
                                             List<TagEntity> resolvedTags,
                                             List<PostTagEntity> tagLinks,
                                             TierDecision decision,
                                             boolean visitRecorded,
                                             List<AwardedBadge> awarded) {
        TierResultResponse tierResult = TierResultResponse.from(decision);
        PostDetailResponse detail = assembler.detailOf(
                post, place, images, resolvedTags, tagLinks, tierResult);

        List<BadgeSummaryResponse> badges = new ArrayList<>(awarded.size());
        for (AwardedBadge badge : awarded) {
            badges.add(BadgeSummaryResponse.from(badge));
        }
        return new CreatePostResponse(detail, tierResult, visitRecorded, badges);
    }
}
