package com.snaphere.api.event.dto;

import java.time.OffsetDateTime;

/**
 * 명세: 4. 응답 스키마 &gt; EventRegionSummary. 시도 칩 한 개. (EVT-007, EVT-008)
 *
 * <p>{@code newCount} 가 0 보다 크면 앱이 그 시도 버튼에 테두리와 NEW·별표를 붙인다.
 * 서버는 강조 여부를 직접 말하지 않고 근거만 준다 — 열람 후 해제는 앱 로컬이 기억하므로
 * (EVT-009) 서버가 boolean 을 주면 두 상태가 충돌한다.
 */
public record EventRegionSummaryResponse(
        int areaCode,
        String areaName,
        int eventCount,
        int newCount,
        OffsetDateTime latestAddedAt
) {
}
