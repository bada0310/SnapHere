package com.snaphere.api.post.dto;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.place.entity.PlaceEntity;

/**
 * 명세: 3. 응답 스키마 &gt; PlaceSummary
 *
 * <p>{@code distanceM}·{@code isVerifiable} 은 주변 검색에서만 채우는 계산 필드라 게시글 응답에서는
 * 넣지 않는다.
 *
 * <p><b>{@code placeId} 는 {@code plc_} 외부 ID 다.</b> 이전에는 생숫자를 내보냈는데, 그 값으로는
 * {@code GET /api/v1/places/&#123;placeId&#125;} 를 부를 수 없었다 — PLC 도메인이 {@code plc_} 만
 * 받는다. 게시글에서 장소로 넘어가는 화면 이동이 응답 형식 하나 때문에 막혀 있었다.
 */
public record PlaceSummaryResponse(
        String placeId,
        String placeType,
        String title,
        String addr1,
        Double lat,
        Double lng,
        int postCount,
        int visitCount
) {
    public static PlaceSummaryResponse from(PlaceEntity place) {
        return new PlaceSummaryResponse(
                ExternalIds.place(place.getPlaceId()),
                place.getPlaceType().name(),
                place.getTitle(),
                place.getAddr1(),
                place.getLat(),
                place.getLng(),
                place.getPostCount(),
                place.getVisitCount());
    }
}
