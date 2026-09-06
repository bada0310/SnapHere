package com.snaphere.api.badge.dto;

import com.snaphere.api.post.dto.BadgeSummaryResponse;

import java.util.Map;

/**
 * 명세: 4. 응답 스키마 &gt; BadgeDetail. (BDG-013)
 *
 * @param condition    해석된 획득 조건. 저장된 JSON 을 그대로 흘리지 않는다
 * @param currentValue 조회자의 현재 진행값. 비회원이면 0 이다
 * @param targetValue  목표값
 * @param earnedCount  획득자 수. {@code badges.earned_count} 비정규화 카운터를 읽는다
 * @param sourcePostId 획득 근거 게시글. 아직 못 받았거나 근거 글이 지워졌으면 null
 */
public record BadgeDetailResponse(
        BadgeSummaryResponse badge,
        Map<String, Object> condition,
        int currentValue,
        int targetValue,
        int earnedCount,
        String sourcePostId
) {
}
