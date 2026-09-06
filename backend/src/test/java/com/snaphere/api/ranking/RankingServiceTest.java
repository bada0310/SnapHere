package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.place.PlaceDtos;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RankingServiceTest {
    @Mock RankingRepository repository;
    RankingService service;

    @BeforeEach
    void setUp() {
        service = new RankingService(repository);
    }

    @Test
    void 지역_랭킹은_지역코드가_필수다() {
        assertThatThrownBy(() -> service.places(
                "REGION", null, "WEEKLY", null, "ALL", null, 20, null))
                .isInstanceOf(ApiException.class);
    }

    @Test
    void 전국_랭킹은_지역코드를_무시하고_커서와_순위변동을_반환한다() {
        when(repository.rankings(eq(RankingScope.NATIONAL), isNull(), eq(RankingPeriod.WEEKLY),
                eq("ALL"), eq(RankingPlaceType.ALL), isNull(), eq(2), isNull()))
                .thenReturn(List.of(
                        new RankingRepository.RankingRow(1, 3, new BigDecimal("12.5000"),
                                "WEEKLY", "ALL", place("plc_1", null)),
                        new RankingRepository.RankingRow(2, null, new BigDecimal("10.0000"),
                                "WEEKLY", "ALL", place("plc_2", null))));

        CursorPage<RankingDtos.RankingEntry> page = service.places(
                "NATIONAL", 1, null, null, null, null, 1, null);

        assertThat(page.items()).hasSize(1);
        assertThat(page.items().getFirst().change()).isEqualTo(2);
        assertThat(page.items().getFirst().theme()).isNull();
        assertThat(page.nextCursor()).isNotNull();
        assertThat(page.hasNext()).isTrue();
    }

    @Test
    void 좌표가_있는_추천은_거리와_사유코드를_준다() {
        when(repository.recommendations(eq(1), eq(37.5), eq(127.0), eq(10), isNull()))
                .thenReturn(List.of(new RankingRepository.RecommendationRow(
                        new BigDecimal("9.5"), place("plc_1", 850))));

        List<RankingDtos.Recommendation> result =
                service.recommendations(37.5, 127.0, 1, 10, null);

        assertThat(result.getFirst().reasonCode()).isEqualTo("TRENDING_NEARBY");
        assertThat(result.getFirst().reasonParams()).containsEntry("distanceM", 850);
    }

    @Test
    void 랭킹_추천이_없으면_운영자_지정_장소로_대체한다() {
        when(repository.recommendations(isNull(), isNull(), isNull(), eq(10), isNull()))
                .thenReturn(List.of());
        when(repository.curated(isNull(), isNull(), isNull(), eq(10), isNull()))
                .thenReturn(List.of(new RankingRepository.RecommendationRow(
                        BigDecimal.ZERO, place("plc_7", null))));

        List<RankingDtos.Recommendation> result =
                service.recommendations(null, null, null, 10, null);

        assertThat(result).singleElement().satisfies(item -> {
            assertThat(item.reasonCode()).isEqualTo("CURATED");
            assertThat(item.place().placeId()).isEqualTo("plc_7");
        });
        verify(repository).curated(isNull(), isNull(), isNull(), eq(10), isNull());
    }

    @Test
    void 위도와_경도는_함께_보내야_한다() {
        assertThatThrownBy(() -> service.recommendations(37.5, null, null, 10, null))
                .isInstanceOf(ApiException.class);
    }

    private static PlaceDtos.PlaceSummary place(String id, Integer distance) {
        return new PlaceDtos.PlaceSummary(id, "OFFICIAL", "장소", "주소", null,
                37.5, 127.0, 1, 0, distance, null, null);
    }
}

