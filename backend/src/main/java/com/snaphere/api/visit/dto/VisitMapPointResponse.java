package com.snaphere.api.visit.dto;

/**
 * 명세: 3. 응답 스키마 &gt; VisitMap.points — {@code {placeId, lat, lng, visitCount}}.
 *
 * <p>{@code placeId} 는 {@code plc_} 외부 ID 다. 마커를 누르면 장소 상세로 가야 하고,
 * 그 엔드포인트가 이 형식만 받는다.
 */
public record VisitMapPointResponse(
        String placeId,
        double lat,
        double lng,
        long visitCount
) {
}
