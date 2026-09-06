package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RankingPeriodTest {
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-09-05T12:00:00+09:00");

    @Test
    void 기간_시작점을_계산한다() {
        assertThat(RankingPeriod.DAILY.from(NOW)).isEqualTo(NOW.minusDays(1));
        assertThat(RankingPeriod.WEEKLY.from(NOW)).isEqualTo(NOW.minusDays(7));
        assertThat(RankingPeriod.MONTHLY.from(NOW)).isEqualTo(NOW.minusMonths(1));
        assertThat(RankingPeriod.ALL.from(NOW)).isNull();
    }

    @Test
    void 기본값과_잘못된_값을_구분한다() {
        assertThat(RankingPeriod.parse(null)).isEqualTo(RankingPeriod.WEEKLY);
        assertThatThrownBy(() -> RankingPeriod.parse("YEARLY")).isInstanceOf(ApiException.class);
    }
}

