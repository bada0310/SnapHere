package com.snaphere.api.visit.dto;

import com.snaphere.api.post.dto.PlaceSummaryResponse;
import com.snaphere.api.visit.entity.VisitEntity;

import java.time.LocalDate;

/**
 * 명세: 3. 응답 스키마 &gt; Visit.
 *
 * <p>{@code visitedOn} 은 시각이 아니라 날짜다. 중복 판정 단위가 하루이므로(VST-002) 시각을
 * 주면 "같은 날 한 번"이라는 규칙과 화면이 어긋나 보인다.
 */
public record VisitResponse(
        String visitId,
        PlaceSummaryResponse place,
        String postId,
        LocalDate visitedOn
) {
    public static VisitResponse of(VisitEntity visit, PlaceSummaryResponse place) {
        return new VisitResponse(
                String.valueOf(visit.getVisitId()),
                place,
                String.valueOf(visit.getPostId()),
                visit.getVisitedOn());
    }
}
