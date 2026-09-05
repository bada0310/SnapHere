package com.snaphere.api.visit;

import com.snaphere.api.place.entity.RegionEntity;
import com.snaphere.api.place.repository.RegionRepository;
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

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * 방문 통계 — VST-004, VST-008, VST-009
 *
 * <p>진행률 분모를 어디서 가져오는지와 기준정보에 없는 지역을 어떻게 다루는지가 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class VisitStatsServiceTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");

    @Mock private VisitRepository visits;
    @Mock private RegionRepository regions;

    private VisitStatsService service;

    @BeforeEach
    void setUp() {
        service = new VisitStatsService(visits, regions);
        when(regions.count()).thenReturn(17L);
    }

    /** 엔티티 생성자가 protected 라 목으로 만든다. 이 테스트가 보는 것은 코드와 이름뿐이다. */
    private static RegionEntity region(int areaCode, String nameKo) {
        RegionEntity region = mock(RegionEntity.class);
        when(region.getAreaCode()).thenReturn(areaCode);
        when(region.getNameKo()).thenReturn(nameKo);
        when(region.getNameEn()).thenReturn("Region" + areaCode);
        when(region.getDefaultEventVerifyRadiusM()).thenReturn(2000);
        return region;
    }

    private static Object[] row(int areaCode, long visitCount, long placeCount, LocalDate last) {
        return new Object[]{areaCode, visitCount, placeCount, last};
    }

    @Test
    @DisplayName("진행률은 방문 시도 수 / 전체 시도 수다. 분모는 regions 에서 센다 (VST-009)")
    void progress() {
        RegionEntity seoul = region(1, "서울특별시");
        RegionEntity busan = region(6, "부산광역시");
        when(visits.aggregateByArea(USER)).thenReturn(List.<Object[]>of(
                row(1, 10L, 4L, LocalDate.of(2026, 9, 4)),
                row(6, 3L, 2L, LocalDate.of(2026, 8, 1))));
        when(regions.findAllById(any())).thenReturn(List.of(seoul, busan));

        VisitStatsResponse stats = service.of(USER);

        assertThat(stats.visitedRegionCount()).isEqualTo(2);
        assertThat(stats.totalRegionCount()).isEqualTo(17);
        assertThat(stats.progress()).isEqualTo(2d / 17d);
        assertThat(stats.regions()).extracting(r -> r.region().nameKo())
                .containsExactly("서울특별시", "부산광역시");
        assertThat(stats.regions().get(0).visitCount()).isEqualTo(10L);
        assertThat(stats.regions().get(0).placeCount()).isEqualTo(4L);
        assertThat(stats.regions().get(0).lastVisitedOn()).isEqualTo(LocalDate.of(2026, 9, 4));
    }

    @Test
    @DisplayName("방문한 시도만 담는다 — 안 가 본 시도까지 보내면 응답이 두 배가 된다 (VST-008)")
    void onlyVisitedRegions() {
        // 목의 스텁을 먼저 끝낸다. when(...) 인수 자리에서 목을 만들면 앞의 스텁이 닫히기 전에
        // 새 스텁이 시작돼 UnfinishedStubbingException 이 난다.
        RegionEntity seoul = region(1, "서울특별시");
        when(visits.aggregateByArea(USER)).thenReturn(List.<Object[]>of(
                row(1, 1L, 1L, LocalDate.of(2026, 9, 4))));
        when(regions.findAllById(any())).thenReturn(List.of(seoul));

        assertThat(service.of(USER).regions()).hasSize(1);
    }

    @Test
    @DisplayName("방문이 없으면 0/17 이고 진행률은 0 이다")
    void noVisits() {
        when(visits.aggregateByArea(USER)).thenReturn(List.of());

        VisitStatsResponse stats = service.of(USER);

        assertThat(stats.visitedRegionCount()).isZero();
        assertThat(stats.totalRegionCount()).isEqualTo(17);
        assertThat(stats.progress()).isZero();
        assertThat(stats.regions()).isEmpty();
    }

    @Test
    @DisplayName("기준정보에 없는 지역 코드는 통계에서 빼고 진행률에도 세지 않는다")
    void skipsUnknownArea() {
        RegionEntity seoul = region(1, "서울특별시");
        when(visits.aggregateByArea(USER)).thenReturn(List.<Object[]>of(
                row(1, 5L, 2L, LocalDate.of(2026, 9, 4)),
                row(99, 1L, 1L, LocalDate.of(2026, 9, 1))));
        when(regions.findAllById(any())).thenReturn(List.of(seoul));

        VisitStatsResponse stats = service.of(USER);

        assertThat(stats.regions()).hasSize(1);
        assertThat(stats.visitedRegionCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("기준정보가 비어 있으면 0 으로 나누지 않고 진행률 0 을 준다")
    void emptyRegionMaster() {
        when(regions.count()).thenReturn(0L);
        when(visits.aggregateByArea(USER)).thenReturn(List.of());

        assertThat(service.of(USER).progress()).isZero();
    }
}
