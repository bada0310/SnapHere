package com.snaphere.api.event;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

/** 첫 화면 정렬 그룹 — EVT-005, EVT-006 */
class EventSortGroupTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 9, 5);

    @Test
    @DisplayName("진행 중이 가장 앞")
    void 진행() {
        assertThat(EventSortGroup.of(TODAY.minusDays(1), TODAY.plusDays(1), TODAY))
                .isEqualTo(EventSortGroup.ONGOING);
    }

    @Test
    @DisplayName("7일 안에 시작하면 임박 — 진행 중 바로 뒤")
    void 임박() {
        assertThat(EventSortGroup.of(TODAY.plusDays(1), TODAY.plusDays(9), TODAY))
                .isEqualTo(EventSortGroup.IMMINENT);
        assertThat(EventSortGroup.of(TODAY.plusDays(7), TODAY.plusDays(9), TODAY))
                .isEqualTo(EventSortGroup.IMMINENT);
    }

    @Test
    @DisplayName("8일 뒤 시작이면 예정")
    void 예정() {
        assertThat(EventSortGroup.of(TODAY.plusDays(8), TODAY.plusDays(9), TODAY))
                .isEqualTo(EventSortGroup.UPCOMING);
    }

    @Test
    @DisplayName("끝난 행사는 가장 뒤")
    void 종료() {
        assertThat(EventSortGroup.of(TODAY.minusDays(5), TODAY.minusDays(1), TODAY))
                .isEqualTo(EventSortGroup.ENDED);
    }

    @Test
    @DisplayName("기본은 진행·임박·예정만 — 종료 행사는 숨긴다 (EVT-006)")
    void 기본_필터() {
        assertThat(EventSortGroup.filterOf(null, false))
                .containsExactly(EventSortGroup.ONGOING, EventSortGroup.IMMINENT,
                        EventSortGroup.UPCOMING);
    }

    @Test
    @DisplayName("includeEnded 면 종료도 포함")
    void 종료_포함() {
        assertThat(EventSortGroup.filterOf(null, true))
                .containsExactly(EventSortGroup.ONGOING, EventSortGroup.IMMINENT,
                        EventSortGroup.UPCOMING, EventSortGroup.ENDED);
    }

    @Test
    @DisplayName("status 를 명시하면 includeEnded 보다 우선한다")
    void status_우선() {
        assertThat(EventSortGroup.filterOf(EventStatus.ONGOING, true))
                .containsExactly(EventSortGroup.ONGOING);
        assertThat(EventSortGroup.filterOf(EventStatus.ENDED, false))
                .containsExactly(EventSortGroup.ENDED);
    }

    @Test
    @DisplayName("예정은 임박과 예정 두 그룹을 함께 본다 — 화면의 '예정' 은 정렬 그룹 둘로 쪼개져 있다")
    void 예정_두_그룹() {
        assertThat(EventSortGroup.filterOf(EventStatus.UPCOMING, false))
                .containsExactly(EventSortGroup.IMMINENT, EventSortGroup.UPCOMING);
    }
}
