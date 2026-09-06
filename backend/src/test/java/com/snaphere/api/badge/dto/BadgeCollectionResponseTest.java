package com.snaphere.api.badge.dto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** 수집함 진행률 — BDG-009 */
class BadgeCollectionResponseTest {

    @Test
    @DisplayName("획득 / 획득 가능 전체")
    void 진행률() {
        assertThat(BadgeCollectionResponse.of(7, 20, List.of()).progress())
                .isEqualByComparingTo(new BigDecimal("0.35"));
    }

    @Test
    @DisplayName("분모가 0 이면 0 — 나누지 않는다")
    void 분모_0() {
        assertThat(BadgeCollectionResponse.of(0, 0, List.of()).progress())
                .isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    @DisplayName("획득이 분모보다 많아도 1.0 을 넘지 않는다 — 기간이 끝난 뱃지는 분모에서 빠진다")
    void 분모_초과() {
        assertThat(BadgeCollectionResponse.of(12, 10, List.of()).progress())
                .isEqualByComparingTo(BigDecimal.ONE);
    }

    @Test
    @DisplayName("하나도 못 모았으면 0")
    void 획득_없음() {
        assertThat(BadgeCollectionResponse.of(0, 20, List.of()).progress())
                .isEqualByComparingTo(BigDecimal.ZERO);
    }
}
