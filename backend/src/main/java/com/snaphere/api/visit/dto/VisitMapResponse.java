package com.snaphere.api.visit.dto;

import com.snaphere.api.post.dto.BadgeSummaryResponse;

import java.util.List;

/**
 * 명세: 3. 응답 스키마 &gt; VisitMap.
 *
 * <p><b>{@code stats} 는 명세의 필드 표에 없다.</b> 그런데 API-VST-003 설명은 "지도 마커·방문
 * 지역 채색·하단 뱃지 요약을 한 번에 반환한다"이고, 추적표도 VST-008(시도 채색)·VST-009(진행률)를
 * 이 API 에 걸어 두었다. 표에는 채색에 쓸 값이 없어 설명과 어긋나 있었다 — 표를 보강해야 한다.
 * 화면 하나를 그리려고 {@code /me/visit-stats} 를 한 번 더 부르게 하면 "한 번에"가 무너진다.
 *
 * @param points 지도 마커. 좌표 있는 장소만 (VST-007)
 * @param bounds 전체 마커 경계. 마커가 없으면 null
 * @param stats  시도 채색·진행률에 쓰는 집계 (VST-008, VST-009)
 * @param badges 지도 하단 수집 뱃지 (VST-010)
 */
public record VisitMapResponse(
        List<VisitMapPointResponse> points,
        VisitMapBoundsResponse bounds,
        VisitStatsResponse stats,
        List<BadgeSummaryResponse> badges
) {
}
