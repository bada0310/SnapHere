package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.dto.EventUploadContextResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.dto.PlaceSummaryResponse;
import com.snaphere.api.post.dto.TagSummaryResponse;
import com.snaphere.api.post.entity.PostTagEntity;
import com.snaphere.api.post.tier.VerifyRadiusResolver;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * API-EVT-005 — 행사 참여 업로드 컨텍스트. (EVT-012, EVT-016 ~ EVT-020)
 *
 * <p>기능 명세: 3.3 행사 참여 업로드
 *
 * <p>업로드 화면이 프리필해야 할 것을 한 번에 준다. 상세(API-EVT-003)와 값이 겹치지만 별도
 * 엔드포인트인 이유는 쓰이는 시점이 다르기 때문이다 — 상세는 구경하는 화면이고 이쪽은 실제로
 * 글을 쓰기 직전이라, 앱이 상세 응답을 들고 다니지 않고 그 자리에서 최신값을 다시 받는다.
 * 행사 반경이 운영에 의해 바뀌었다면(API-ADM-007) 그 값이 여기서 반영돼야 한다.
 */
@Service
public class EventUploadContextService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final EventRepository events;
    private final PlaceRepository places;
    private final VerifyRadiusResolver radiusResolver;
    private final EventBadgeReader badges;

    public EventUploadContextService(EventRepository events,
                                     PlaceRepository places,
                                     VerifyRadiusResolver radiusResolver,
                                     EventBadgeReader badges) {
        this.events = events;
        this.places = places;
        this.radiusResolver = radiusResolver;
        this.badges = badges;
    }

    @Transactional(readOnly = true)
    public EventUploadContextResponse of(long eventId, UUID userId) {
        EventEntity event = events.findById(eventId)
                .filter(e -> e.getStatus() == EventLifecycle.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.EVENT_NOT_FOUND,
                        Map.of("eventId", eventId)));

        PlaceEntity place = places.findByPlaceIdAndStatus(event.getPlaceId(), PlaceStatus.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND,
                        Map.of("placeId", event.getPlaceId())));

        OffsetDateTime now = OffsetDateTime.now(KST);
        LocalDate today = now.toLocalDate();
        List<TagSummaryResponse> fixedTags = EventFixedTags.of(event.getFixedTags());

        return new EventUploadContextResponse(
                EventSummaryResponse.of(event, today, now),
                PlaceSummaryResponse.from(place),
                fixedTags,
                radiusResolver.resolve(place.toSnapshot(), EventSnapshots.of(event)),
                badges.findByEventId(eventId, userId).orElse(null),
                freeTagSlots(fixedTags.size()));
    }

    /**
     * 사용자가 직접 넣을 수 있는 태그 수. (EVT-020)
     *
     * <p>게시글 태그 상한에서 고정 태그를 뺀 값이다. 고정 태그가 0개인 행사(운영이 아직 안 채운
     * 경우)면 상한 그대로가 된다 — 그때 8 로 고정하면 쓸 수 있는 두 칸이 사라진다.
     */
    private static int freeTagSlots(int fixedCount) {
        return Math.max(0, PostTagEntity.MAX_PER_POST - fixedCount);
    }
}
