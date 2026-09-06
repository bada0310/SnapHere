package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.dto.EventDetailResponse;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.dto.PlaceSummaryResponse;
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
 * API-EVT-003 — 행사 상세. (EVT-011, EVT-012, EVT-013)
 *
 * <p>기능 명세: 3.2 행사 상세
 *
 * <p>한 번의 조회로 상세 화면이 필요한 것을 모두 준다 — 행사 정보, 장소(지도 버튼이 쓸 좌표),
 * 고정 태그, 뱃지 미리보기, 적용 인증 반경. 앱이 장소를 따로 조회하지 않아도 되게 하려는 것이고,
 * 특히 인증 반경은 "반경 밖이면 뱃지가 안 나온다"는 안내의 근거라 상세에서 확정돼야 한다.
 */
@Service
public class EventDetailService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final EventRepository events;
    private final PlaceRepository places;
    private final VerifyRadiusResolver radiusResolver;
    private final EventBadgeReader badges;

    public EventDetailService(EventRepository events,
                              PlaceRepository places,
                              VerifyRadiusResolver radiusResolver,
                              EventBadgeReader badges) {
        this.events = events;
        this.places = places;
        this.radiusResolver = radiusResolver;
        this.badges = badges;
    }

    @Transactional(readOnly = true)
    public EventDetailResponse detail(long eventId, UUID viewerId) {
        EventEntity event = loadActive(eventId);
        PlaceEntity place = loadPlace(event);

        OffsetDateTime now = OffsetDateTime.now(KST);
        LocalDate today = now.toLocalDate();

        return new EventDetailResponse(
                EventSummaryResponse.of(event, today, now),
                event.getOverview(),
                PlaceSummaryResponse.from(place),
                EventFixedTags.of(event.getFixedTags()),
                badges.findByEventId(eventId, viewerId).orElse(null),
                radiusResolver.resolve(place.toSnapshot(), EventSnapshots.of(event)));
    }

    /**
     * 숨긴 행사는 없는 것으로 본다.
     *
     * <p>403 이 아니라 404 를 주는 이유: 운영이 내린 행사가 "있긴 한데 못 본다" 로 보이면
     * 존재 자체가 새어 나간다. 목록에서도 빠지므로 앱이 보는 세계와도 일치한다.
     */
    private EventEntity loadActive(long eventId) {
        return events.findById(eventId)
                .filter(event -> event.getStatus() == EventLifecycle.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.EVENT_NOT_FOUND,
                        Map.of("eventId", eventId)));
    }

    /**
     * 행사장은 필수다. {@code events.place_id} 가 NOT NULL 이므로 여기서 못 찾는다면
     * 장소가 숨겨졌거나 삭제된 것이다 — 그 경우 상세를 그릴 수 없으므로 404 로 막는다.
     */
    private PlaceEntity loadPlace(EventEntity event) {
        return places.findByPlaceIdAndStatus(event.getPlaceId(), PlaceStatus.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND,
                        Map.of("placeId", event.getPlaceId())));
    }

    /** 상세 응답에 쓰지 않는 목록용 변환. 주변 행사(EVT-015)가 재사용한다. */
    static List<EventSummaryResponse> summaries(List<EventEntity> rows,
                                                LocalDate today, OffsetDateTime now) {
        return rows.stream().map(e -> EventSummaryResponse.of(e, today, now)).toList();
    }
}
