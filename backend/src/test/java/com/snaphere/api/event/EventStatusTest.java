package com.snaphere.api.event;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/** 행사 진행 상태 판정 — EVT-005, EVT-006 */
class EventStatusTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 9, 5);

    @Test
    @DisplayName("시작 전이면 예정")
    void 예정() {
        assertThat(EventStatus.of(TODAY.plusDays(1), TODAY.plusDays(3), TODAY))
                .isEqualTo(EventStatus.UPCOMING);
    }

    @Test
    @DisplayName("시작일과 종료일이 오늘을 감싸면 진행 중")
    void 진행() {
        assertThat(EventStatus.of(TODAY.minusDays(1), TODAY.plusDays(1), TODAY))
                .isEqualTo(EventStatus.ONGOING);
    }

    @Test
    @DisplayName("종료일이 오늘이면 아직 진행 중이다 — 마지막 날 행사가 목록에서 사라지면 안 된다")
    void 종료일_당일() {
        assertThat(EventStatus.of(TODAY.minusDays(3), TODAY, TODAY))
                .isEqualTo(EventStatus.ONGOING);
    }

    @Test
    @DisplayName("시작일이 오늘이면 진행 중이다")
    void 시작일_당일() {
        assertThat(EventStatus.of(TODAY, TODAY.plusDays(3), TODAY))
                .isEqualTo(EventStatus.ONGOING);
    }

    @Test
    @DisplayName("종료일이 어제면 종료")
    void 종료() {
        assertThat(EventStatus.of(TODAY.minusDays(5), TODAY.minusDays(1), TODAY))
                .isEqualTo(EventStatus.ENDED);
    }

    @Test
    @DisplayName("모르는 값은 null — 오타 하나로 목록이 실패하지 않는다")
    void 파싱() {
        assertThat(EventStatus.parseOrNull("ongoing")).isEqualTo(EventStatus.ONGOING);
        assertThat(EventStatus.parseOrNull(" UPCOMING ")).isEqualTo(EventStatus.UPCOMING);
        assertThat(EventStatus.parseOrNull("RUNNING")).isNull();
        assertThat(EventStatus.parseOrNull(null)).isNull();
        assertThat(EventStatus.parseOrNull("  ")).isNull();
    }
}
