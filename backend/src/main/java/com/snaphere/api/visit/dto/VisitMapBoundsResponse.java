package com.snaphere.api.visit.dto;

/**
 * 명세: 3. 응답 스키마 &gt; VisitMap.bounds — 전체 마커 경계.
 *
 * <p>마커가 하나도 없으면 이 값은 {@code null} 이다. 0,0 같은 기본값을 주면 지도가 기니 만
 * 앞바다를 비춘다.
 *
 * <p>마커가 한 점뿐이면 네 값이 모두 같다. 그 경우 화면이 어느 배율로 볼지는 클라이언트가
 * 정한다 — 서버가 임의로 여백을 붙이면 줌 정책이 두 곳에 흩어진다.
 */
public record VisitMapBoundsResponse(
        double south,
        double west,
        double north,
        double east
) {
}
