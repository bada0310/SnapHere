package com.snaphere.api.visit.dto;

import java.util.List;

/**
 * 명세: 3. 응답 스키마 &gt; VisitStats.
 *
 * @param visitedRegionCount 방문한 시도 수
 * @param totalRegionCount   전체 시도 수. {@code regions} 테이블에서 센다 — 17 을 상수로 박으면
 *                           기준정보가 바뀔 때 진행률만 조용히 틀린다
 * @param progress           0~1. 화면이 나누기를 다시 하지 않도록 서버가 계산해 준다 (VST-009)
 * @param regions            방문한 시도만. 안 가 본 시도는 넣지 않는다 — 채색(VST-008)은 있는
 *                           것만 칠하면 되고, 17개를 다 보내면 응답이 두 배가 된다
 */
public record VisitStatsResponse(
        int visitedRegionCount,
        int totalRegionCount,
        double progress,
        List<VisitRegionStatResponse> regions
) {
}
