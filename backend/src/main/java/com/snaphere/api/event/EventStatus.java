package com.snaphere.api.event;

import java.time.LocalDate;

/**
 * 행사 진행 상태. (EVT-005, EVT-006)
 *
 * <p>테이블에 저장하지 않고 오늘 날짜로 매번 계산한다. 저장하면 자정마다 갱신 배치가 필요하고,
 * 배치가 한 번 밀리면 종료된 행사가 첫 화면에 남는다.
 *
 * <p>명세: 3. 응답 스키마 &gt; EventSummary.status
 */
public enum EventStatus {

    UPCOMING,
    ONGOING,
    ENDED;

    public static EventStatus of(LocalDate startDate, LocalDate endDate, LocalDate today) {
        if (endDate.isBefore(today)) {
            return ENDED;
        }
        return startDate.isAfter(today) ? UPCOMING : ONGOING;
    }

    /** 잘못된 값이면 null. 호출자가 400 으로 돌릴지 무시할지 정한다. */
    public static EventStatus parseOrNull(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException unknown) {
            return null;
        }
    }
}
