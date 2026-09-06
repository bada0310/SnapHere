package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.dto.EventDetailResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.PlaceType;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.tier.VerifyRadiusResolver;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.BeanUtils;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

/**
 * 행사 상세 — EVT-011, EVT-012, EVT-013, EVT-023
 *
 * <p>이 서비스의 판단은 셋이다 — 숨긴 행사를 없는 것으로 볼 것, 장소를 함께 실을 것,
 * 인증 반경을 미리 확정할 것.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EventDetailServiceTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Mock
    private EventRepository events;
    @Mock
    private PlaceRepository places;
    @Mock
    private com.snaphere.api.place.RegionRadiusReader regionRadius;
    @Mock
    private EventBadgeReader badges;

    private EventDetailService service;

    @BeforeEach
    void setUp() {
        service = new EventDetailService(events, places,
                new VerifyRadiusResolver(regionRadius), badges);
        when(badges.findByEventId(anyLong(), any())).thenReturn(Optional.empty());
        when(regionRadius.defaultEventVerifyRadiusM(org.mockito.ArgumentMatchers.anyInt()))
                .thenReturn(Optional.empty());
    }

    @Test
    @DisplayName("상세는 장소와 고정 태그를 함께 싣는다 — 지도 버튼이 좌표를 다시 조회하지 않는다")
    void 상세() {
        given(event(3_000, List.of("서울", "경복궁야간개장")), place());

        EventDetailResponse detail = service.detail(1L, null);

        assertThat(detail.event().eventId()).isEqualTo("evt_1");
        assertThat(detail.place().lat()).isEqualTo(37.5796170);
        assertThat(detail.fixedTags()).hasSize(2);
        assertThat(detail.fixedTags()).allMatch(t -> t.locked());
        assertThat(detail.overview()).isNotBlank();
    }

    @Test
    @DisplayName("이벤트별 반경이 있으면 그 값이 최우선 (PLC-022)")
    void 반경_이벤트() {
        given(event(3_000, List.of()), place());

        assertThat(service.detail(1L, null).verifyRadiusM()).isEqualTo(3_000);
    }

    @Test
    @DisplayName("이벤트별 반경이 없으면 지역 기본값")
    void 반경_지역() {
        given(event(null, List.of()), place());
        when(regionRadius.defaultEventVerifyRadiusM(1)).thenReturn(Optional.of(1_500));

        assertThat(service.detail(1L, null).verifyRadiusM()).isEqualTo(1_500);
    }

    @Test
    @DisplayName("지역 기본값도 없으면 2,000m (EVT-023)")
    void 반경_폴백() {
        given(event(null, List.of()), place());

        assertThat(service.detail(1L, null).verifyRadiusM())
                .isEqualTo(VerifyRadiusResolver.EVENT_FALLBACK_RADIUS_M);
    }

    @Test
    @DisplayName("뱃지 도메인이 아직 없어 badge 는 null — 계약은 지킨다")
    void 뱃지_없음() {
        given(event(3_000, List.of()), place());

        assertThat(service.detail(1L, null).badge()).isNull();
    }

    @Test
    @DisplayName("없는 행사는 404")
    void 없는_행사() {
        when(events.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.detail(9L, null))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.EVENT_NOT_FOUND));
    }

    @Test
    @DisplayName("숨긴 행사도 404 — 403 을 주면 존재 자체가 새어 나간다")
    void 숨긴_행사() {
        LocalDate today = LocalDate.now(KST);
        when(events.findById(1L)).thenReturn(Optional.of(
                EventFixtures.hidden(1L, today, today.plusDays(3), OffsetDateTime.now(KST))));

        assertThatThrownBy(() -> service.detail(1L, null))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.EVENT_NOT_FOUND));
    }

    @Test
    @DisplayName("행사장이 숨겨졌으면 404 — 상세를 그릴 수 없다")
    void 숨긴_장소() {
        when(events.findById(1L)).thenReturn(Optional.of(event(3_000, List.of())));
        when(places.findByPlaceIdAndStatus(anyLong(), any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.detail(1L, null))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.PLACE_NOT_FOUND));
    }

    // ─────────────────────────────────────────────────────────────

    private void given(EventEntity event, PlaceEntity place) {
        when(events.findById(1L)).thenReturn(Optional.of(event));
        when(places.findByPlaceIdAndStatus(anyLong(), any())).thenReturn(Optional.of(place));
    }

    private static EventEntity event(Integer verifyRadiusM, List<String> fixedTags) {
        LocalDate today = LocalDate.now(KST);
        return EventFixtures.detailed(1L, today.minusDays(1), today.plusDays(3),
                OffsetDateTime.now(KST), 101L, verifyRadiusM, fixedTags);
    }

    private static PlaceEntity place() {
        PlaceEntity place = BeanUtils.instantiateClass(PlaceEntity.class);
        ReflectionTestUtils.setField(place, "placeId", 101L);
        ReflectionTestUtils.setField(place, "placeType", PlaceType.OFFICIAL);
        ReflectionTestUtils.setField(place, "title", "경복궁");
        ReflectionTestUtils.setField(place, "addr1", "서울특별시 종로구 사직로 161");
        ReflectionTestUtils.setField(place, "lat", 37.5796170);
        ReflectionTestUtils.setField(place, "lng", 126.9770410);
        ReflectionTestUtils.setField(place, "verifyRadiusM", 500);
        ReflectionTestUtils.setField(place, "areaCode", 1);
        ReflectionTestUtils.setField(place, "status", PlaceStatus.ACTIVE);
        ReflectionTestUtils.setField(place, "postCount", 0);
        ReflectionTestUtils.setField(place, "visitCount", 0);
        return place;
    }
}
