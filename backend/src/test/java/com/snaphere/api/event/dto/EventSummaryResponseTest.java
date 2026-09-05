package com.snaphere.api.event.dto;

import com.snaphere.api.event.EventFixtures;
import com.snaphere.api.event.EventStatus;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/** 이벤트 카드 응답 — EVT-005, EVT-008 */
class EventSummaryResponseTest {

    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-09-05T10:00:00+09:00");
    private static final LocalDate TODAY = NOW.toLocalDate();

    @Test
    @DisplayName("진행 중이면 dday 가 0")
    void 진행중_dday() {
        EventSummaryResponse response = EventSummaryResponse.of(
                EventFixtures.event(1L, TODAY.minusDays(1), TODAY.plusDays(2), NOW), TODAY, NOW);

        assertThat(response.status()).isEqualTo(EventStatus.ONGOING.name());
        assertThat(response.dday()).isZero();
    }

    @Test
    @DisplayName("예정이면 시작까지 남은 일수")
    void 예정_dday() {
        EventSummaryResponse response = EventSummaryResponse.of(
                EventFixtures.event(1L, TODAY.plusDays(3), TODAY.plusDays(5), NOW), TODAY, NOW);

        assertThat(response.dday()).isEqualTo(3);
    }

    @Test
    @DisplayName("끝난 행사의 dday 는 null — 0 을 주면 앱이 'D-DAY' 를 그린다")
    void 종료_dday() {
        EventSummaryResponse response = EventSummaryResponse.of(
                EventFixtures.event(1L, TODAY.minusDays(5), TODAY.minusDays(1), NOW), TODAY, NOW);

        assertThat(response.status()).isEqualTo(EventStatus.ENDED.name());
        assertThat(response.dday()).isNull();
    }

    @Test
    @DisplayName("7일 안에 적재된 행사만 신규 (EVT-008)")
    void 신규() {
        assertThat(EventSummaryResponse.of(
                EventFixtures.event(1L, TODAY, TODAY.plusDays(1), NOW.minusDays(6)), TODAY, NOW)
                .isNew()).isTrue();

        assertThat(EventSummaryResponse.of(
                EventFixtures.event(2L, TODAY, TODAY.plusDays(1), NOW.minusDays(8)), TODAY, NOW)
                .isNew()).isFalse();
    }

    @Test
    @DisplayName("eventId 는 evt_ 외부 ID — 그 값으로 상세를 부를 수 있어야 한다")
    void 외부_id() {
        EventSummaryResponse response = EventSummaryResponse.of(
                EventFixtures.event(42L, TODAY, TODAY.plusDays(1), NOW), TODAY, NOW);

        assertThat(response.eventId()).startsWith("evt_");
    }
}
