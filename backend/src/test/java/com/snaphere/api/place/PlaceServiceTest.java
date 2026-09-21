package com.snaphere.api.place;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PlaceServiceTest {

    @Mock private PlaceRepository places;
    @Mock private TourPlaceDetailClient details;
    @Mock private ViewCounterService views;
    @Mock private RecentPlaceService recentPlaces;
    @Mock private PlaceReadCache cache;
    @Mock private GoogleGeocodingClient geocoder;

    private PlaceService service;

    @BeforeEach
    void setUp() {
        service = new PlaceService(places, details, views, recentPlaces, cache, geocoder);
    }

    @Test
    @DisplayName("관광 API가 실패해도 내부 장소 기본 정보로 상세를 제공한다")
    void detailFallsBackToStoredPlaceWhenTourApiFails() {
        var place = new PlaceRepository.PlaceRecord(
                7L, "TOURIST", "tour-7", "전주시청년축제", 37, 12, 500, 10);
        var summary = new PlaceDtos.PlaceSummary(
                "plc_7", "TOURIST", "전주시청년축제", "전주시 덕진구", null,
                null, null, 3, 2, null, null, null);

        when(places.placeRecord(7L)).thenReturn(place);
        when(places.hasDetail(7L, "ko")).thenReturn(false);
        when(details.load("tour-7", "ko")).thenThrow(new IllegalStateException("tour api down"));
        when(places.detail(7L, "ko"))
                .thenReturn(new PlaceRepository.DetailRecord(null, null, null, 500, 10));
        when(cache.detail(7L, "ko")).thenReturn(Optional.empty());
        when(places.summary(7L, null)).thenReturn(summary);
        when(places.posts(7L, null, 12, null)).thenReturn(List.of());
        when(views.pending(7L)).thenReturn(0L);

        PlaceDtos.PlaceDetail result = service.detail("plc_7", "ko", null);

        assertThat(result.place()).isEqualTo(summary);
        assertThat(result.overview()).isNull();
        assertThat(result.viewCount()).isEqualTo(11);
        verify(places, never()).upsertDetail(
                org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyString(),
                org.mockito.ArgumentMatchers.any());
        verify(views).increment(7L);
    }

    @Test
    @DisplayName("최근접 장소는 사진의 원래 좌표에서 계산한 거리 순서를 그대로 쓴다")
    void nearestMatchUsesPhotoCoordinates() {
        var first = new PlaceDtos.PlaceSummary("plc_1", "TOURIST", "가까운 장소", "전주", null,
                35.0, 127.0, 0, 0, 25, true, false);
        var second = new PlaceDtos.PlaceSummary("plc_2", "TOURIST", "먼 장소", "전주", null,
                35.1, 127.1, 0, 0, 80, true, false);
        var actor = new com.snaphere.api.common.security.CurrentUser(UUID.randomUUID());
        when(places.nearby(35.814, 127.153, 20_000, 20, actor.userId()))
                .thenReturn(List.of(first, second));

        PlaceDtos.NearestPlaceMatchResult result = service.nearestMatch(
                new PlaceDtos.NearestPlaceMatchRequest(35.814, 127.153), actor);

        assertThat(result.candidates()).containsExactly(first, second);
        assertThat(result.suggestedName()).isNull();
        verify(places).nearby(35.814, 127.153, 20_000, 20, actor.userId());
    }
}
