package com.snaphere.api.badge.dto;

import com.snaphere.api.post.dto.BadgeSummaryResponse;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * 명세: 4. 응답 스키마 &gt; BadgeCollection. (BDG-009 ~ BDG-012)
 *
 * <p>기능 명세: 4.4 뱃지 수집함
 *
 * <p>{@code obtainableCount} 는 "지금 획득 가능한 전체" 다. 이미 받은 뱃지 중 기간이 끝난 것은
 * 이 분모에서 빠지므로 {@code earnedCount} 가 분모보다 클 수 있다 — 그때 진행률은 1.0 으로
 * 자른다. 화면에 120% 가 뜨는 쪽이 더 이상하다.
 */
public record BadgeCollectionResponse(
        int earnedCount,
        int obtainableCount,
        BigDecimal progress,
        List<BadgeSummaryResponse> items
) {
    public static BadgeCollectionResponse of(int earnedCount, int obtainableCount,
                                             List<BadgeSummaryResponse> items) {
        return new BadgeCollectionResponse(earnedCount, obtainableCount,
                progress(earnedCount, obtainableCount), items);
    }

    private static BigDecimal progress(int earned, int obtainable) {
        if (obtainable <= 0) {
            return BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal ratio = BigDecimal.valueOf(earned)
                .divide(BigDecimal.valueOf(obtainable), 2, RoundingMode.HALF_UP);
        return ratio.compareTo(BigDecimal.ONE) > 0 ? BigDecimal.ONE.setScale(2) : ratio;
    }
}
