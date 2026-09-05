package com.snaphere.api.event.dto;

import com.snaphere.api.post.dto.BadgeSummaryResponse;
import com.snaphere.api.post.dto.PlaceSummaryResponse;
import com.snaphere.api.post.dto.TagSummaryResponse;

import java.util.List;

/**
 * 명세: 4. 응답 스키마 &gt; EventDetail. (EVT-011, EVT-012, EVT-013)
 *
 * <p>기능 명세: 3.2 행사 상세
 *
 * <p>{@code place} 가 좌표를 담아 지도 버튼이 그 좌표로 이동한다 (EVT-013). 앱이 장소를 다시
 * 조회하지 않아도 되도록 상세 응답에 함께 싣는다.
 *
 * <p>{@code verifyRadiusM} 은 이미 계산된 최종값이다 — 이벤트별 값 → 지역 기본값 → 2,000m
 * 순서를 앱이 다시 밟지 않는다 (EVT-023, PLC-022). 이 값이 "반경 밖이면 뱃지가 안 나온다"는
 * 안내 문구의 근거가 된다.
 */
public record EventDetailResponse(
        EventSummaryResponse event,
        String overview,
        PlaceSummaryResponse place,
        List<TagSummaryResponse> fixedTags,
        BadgeSummaryResponse badge,
        int verifyRadiusM
) {
}
