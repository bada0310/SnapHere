package com.snaphere.api.visit.dto;

import com.snaphere.api.place.PlaceDtos;

import java.time.LocalDate;

/**
 * 명세: 3. 응답 스키마 &gt; VisitRegionStat.
 *
 * <p>지역 표현은 place 도메인의 {@link PlaceDtos.Region} 을 그대로 쓴다. 같은 시도를
 * 화면마다 다른 모양으로 주면 클라이언트가 두 벌을 들고 있어야 한다.
 *
 * @param visitCount 방문 횟수. 같은 장소를 여러 날 가면 그만큼 센다
 * @param placeCount 방문 장소 수. 횟수와 따로 두는 이유는 한 곳을 자주 간 것과 여러 곳을 다닌
 *                   것이 화면에서 다르게 읽혀야 하기 때문이다
 */
public record VisitRegionStatResponse(
        PlaceDtos.Region region,
        long visitCount,
        long placeCount,
        LocalDate lastVisitedOn
) {
}
