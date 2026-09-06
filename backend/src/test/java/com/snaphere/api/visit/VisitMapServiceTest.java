package com.snaphere.api.visit;

import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.CollectedBadgeReader;
import com.snaphere.api.visit.dto.VisitMapResponse;
import com.snaphere.api.visit.dto.VisitStatsResponse;
import com.snaphere.api.visit.repository.VisitRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.when;

/**
 * 방문 지도 — VST-007, VST-008, VST-009, VST-010
 *
 * <p>경계 계산과 마커 식별자 형식이 이 서비스의 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class VisitMapServiceTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");

    @Mock private VisitRepository visits;
    @Mock private VisitStatsService stats;
    @Mock private CollectedBadgeReader badges;

    private VisitMapService service;

    @BeforeEach
    void setUp() {
        service = new VisitMapService(visits, stats, badges);
        when(stats.of(any())).thenReturn(new VisitStatsResponse(0, 17, 0d, List.of()));
        when(badges.findCollected(any(), anyInt())).thenReturn(List.of());
    }

    private static Object[] point(long placeId, double lat, double lng, long count) {
        return new Object[]{placeId, lat, lng, count};
    }

    @Test
    @DisplayName("마커 식별자는 plc_ 외부 ID 다 — 눌러서 장소 상세로 갈 수 있어야 한다")
    void pointsUseExternalId() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.<Object[]>of(
                point(128L, 37.5796, 126.9770, 3L)));

        VisitMapResponse map = service.of(USER);

        assertThat(map.points()).singleElement()
                .satisfies(p -> {
                    assertThat(p.placeId()).isEqualTo("plc_3k");
                    assertThat(p.visitCount()).isEqualTo(3L);
                });
    }

    @Test
    @DisplayName("경계는 마커 전체를 담는다")
    void bounds() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.<Object[]>of(
                point(1L, 37.5796, 126.9770, 2L),
                point(2L, 33.4996, 126.5312, 1L),
                point(3L, 35.1796, 129.0756, 1L)));

        VisitMapResponse map = service.of(USER);

        assertThat(map.bounds().south()).isEqualTo(33.4996);
        assertThat(map.bounds().north()).isEqualTo(37.5796);
        assertThat(map.bounds().west()).isEqualTo(126.5312);
        assertThat(map.bounds().east()).isEqualTo(129.0756);
    }

    @Test
    @DisplayName("마커가 없으면 경계는 null 이다 — 0,0 을 주면 지도가 기니 만 앞바다를 비춘다")
    void emptyBoundsIsNull() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.of());

        VisitMapResponse map = service.of(USER);

        assertThat(map.points()).isEmpty();
        assertThat(map.bounds()).isNull();
    }

    @Test
    @DisplayName("마커가 하나면 경계 네 값이 모두 같다 — 여백은 클라이언트가 정한다")
    void singlePointBounds() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.<Object[]>of(
                point(1L, 37.5, 127.0, 1L)));

        VisitMapResponse map = service.of(USER);

        assertThat(map.bounds().south()).isEqualTo(map.bounds().north());
        assertThat(map.bounds().west()).isEqualTo(map.bounds().east());
    }

    @Test
    @DisplayName("뱃지 도메인이 아직 없어도 계약은 지킨다 — 빈 배열이지 null 이 아니다")
    void badgesContractHeld() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.of());

        assertThat(service.of(USER).badges()).isNotNull().isEmpty();
    }

    @Test
    @DisplayName("뱃지가 들어오면 획득 표시로 내려준다")
    void badgesMapped() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.of());
        when(badges.findCollected(any(), anyInt())).thenReturn(List.of(
                new AwardedBadge(7L, "AREA", "badge.area.seoul", "https://cdn/x.png",
                        OffsetDateTime.parse("2026-09-04T12:00:00+09:00"))));

        assertThat(service.of(USER).badges()).singleElement()
                .satisfies(b -> {
                    assertThat(b.nameKey()).isEqualTo("badge.area.seoul");
                    assertThat(b.earned()).isTrue();
                });
    }

    @Test
    @DisplayName("진행률 집계는 통계 서비스가 계산한 값을 그대로 싣는다")
    void statsIncluded() {
        when(visits.findVisitMapPoints(any(), any(Pageable.class))).thenReturn(List.of());
        when(stats.of(USER)).thenReturn(new VisitStatsResponse(2, 17, 2d / 17d, List.of()));

        assertThat(service.of(USER).stats().visitedRegionCount()).isEqualTo(2);
        assertThat(service.of(USER).stats().progress()).isEqualTo(2d / 17d);
    }
}
