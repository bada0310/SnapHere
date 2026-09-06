package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.dto.EventUploadContextResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.PlaceType;
import com.snaphere.api.place.RegionRadiusReader;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.dto.TagSummaryResponse;
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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

/**
 * 행사 참여 업로드 컨텍스트 — EVT-012, EVT-016 ~ EVT-020
 *
 * <p>이 서비스의 판단은 둘이다 — 고정 태그를 잠긴 상태로 줄 것, 자유 태그 칸 수를 서버가 셀 것.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EventUploadContextServiceTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final UUID USER = UUID.fromString("11111111-1111-1111-1111-111111111111");

    @Mock
    private EventRepository events;
    @Mock
    private PlaceRepository places;
    @Mock
    private RegionRadiusReader regionRadius;
    @Mock
    private EventBadgeReader badges;

    private EventUploadContextService service;

    @BeforeEach
    void setUp() {
        service = new EventUploadContextService(events, places,
                new VerifyRadiusResolver(regionRadius), badges);
        when(badges.findByEventId(anyLong(), any())).thenReturn(Optional.empty());
        when(regionRadius.defaultEventVerifyRadiusM(anyInt())).thenReturn(Optional.empty());
        when(places.findByPlaceIdAndStatus(anyLong(), any())).thenReturn(Optional.of(place()));
    }

    @Test
    @DisplayName("장소가 프리필된다 (EVT-016)")
    void 장소_프리필() {
        given(List.of("서울", "경복궁야간개장"), null);

        EventUploadContextResponse context = service.of(1L, USER);

        assertThat(context.place().title()).isEqualTo("경복궁");
        assertThat(context.place().lat()).isEqualTo(37.5796170);
    }

    @Test
    @DisplayName("고정 태그는 잠긴 상태로 나간다 (EVT-017, EVT-018)")
    void 고정_태그() {
        given(List.of("서울", "경복궁야간개장"), null);

        List<TagSummaryResponse> tags = service.of(1L, USER).fixedTags();

        assertThat(tags).hasSize(2);
        assertThat(tags).allMatch(TagSummaryResponse::locked);
    }

    @Test
    @DisplayName("자유 태그 칸은 10에서 고정 개수를 뺀 값 (EVT-020)")
    void 자유_태그_칸() {
        given(List.of("서울", "경복궁야간개장"), null);

        assertThat(service.of(1L, USER).freeTagSlots()).isEqualTo(8);
    }

    @Test
    @DisplayName("고정 태그가 없는 행사면 10칸 전부 쓴다 — 8로 굳히면 두 칸이 사라진다")
    void 고정_없는_행사() {
        given(List.of(), null);

        assertThat(service.of(1L, USER).freeTagSlots()).isEqualTo(10);
        assertThat(service.of(1L, USER).fixedTags()).isEmpty();
    }

    @Test
    @DisplayName("적용 반경은 이벤트 → 지역 → 2,000m 순서로 확정된다 (EVT-023)")
    void 적용_반경() {
        given(List.of(), 3_000);
        assertThat(service.of(1L, USER).verifyRadiusM()).isEqualTo(3_000);

        given(List.of(), null);
        assertThat(service.of(1L, USER).verifyRadiusM())
                .isEqualTo(VerifyRadiusResolver.EVENT_FALLBACK_RADIUS_M);
    }

    @Test
    @DisplayName("숨긴 행사는 404 — 업로드 진입 자체를 막는다")
    void 숨긴_행사() {
        LocalDate today = LocalDate.now(KST);
        when(events.findById(1L)).thenReturn(Optional.of(
                EventFixtures.hidden(1L, today, today.plusDays(3), OffsetDateTime.now(KST))));

        assertThatThrownBy(() -> service.of(1L, USER))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.EVENT_NOT_FOUND));
    }

    @Test
    @DisplayName("행사장이 숨겨졌으면 404 — 프리필할 장소가 없다")
    void 숨긴_장소() {
        given(List.of(), null);
        when(places.findByPlaceIdAndStatus(anyLong(), any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.of(1L, USER))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.PLACE_NOT_FOUND));
    }

    // ─────────────────────────────────────────────────────────────

    private void given(List<String> fixedTags, Integer verifyRadiusM) {
        LocalDate today = LocalDate.now(KST);
        EventEntity event = EventFixtures.detailed(1L, today.minusDays(1), today.plusDays(3),
                OffsetDateTime.now(KST), 101L, verifyRadiusM, fixedTags);
        when(events.findById(1L)).thenReturn(Optional.of(event));
    }

    private static PlaceEntity place() {
        PlaceEntity place = BeanUtils.instantiateClass(PlaceEntity.class);
        ReflectionTestUtils.setField(place, "placeId", 101L);
        ReflectionTestUtils.setField(place, "placeType", PlaceType.OFFICIAL);
        ReflectionTestUtils.setField(place, "title", "경복궁");
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
