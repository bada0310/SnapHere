package com.snaphere.api.event;

import java.time.LocalDate;
import java.util.List;

/**
 * 첫 화면 정렬 그룹. (EVT-005)
 *
 * <p>명세의 "진행 중 → 임박(7일 내 시작) → 예정 → 종료" 를 정수 하나로 바꾼 것이다. SQL 의
 * {@code case} 식과 이 클래스가 <b>같은 숫자</b>를 써야 커서가 맞는다 — 두 곳에 흩어져 있으니
 * 한쪽만 고치지 않도록 상수를 여기 모아 둔다.
 */
public final class EventSortGroup {

    public static final int ONGOING = 0;
    public static final int IMMINENT = 1;
    public static final int UPCOMING = 2;
    public static final int ENDED = 3;

    /** 임박 판정 기준. SQL 파라미터 {@code soon} = today + 이 값. */
    public static final int IMMINENT_WITHIN_DAYS = 7;

    private EventSortGroup() {
    }

    public static int of(LocalDate startDate, LocalDate endDate, LocalDate today) {
        if (endDate.isBefore(today)) {
            return ENDED;
        }
        if (!startDate.isAfter(today)) {
            return ONGOING;
        }
        return startDate.isAfter(today.plusDays(IMMINENT_WITHIN_DAYS)) ? UPCOMING : IMMINENT;
    }

    /** 조회할 정렬 그룹. {@code status} 를 명시하면 {@code includeEnded} 보다 우선한다 (EVT-006). */
    public static List<Integer> filterOf(EventStatus status, boolean includeEnded) {
        if (status != null) {
            return switch (status) {
                case ONGOING -> List.of(ONGOING);
                case UPCOMING -> List.of(IMMINENT, UPCOMING);
                case ENDED -> List.of(ENDED);
            };
        }
        return includeEnded
                ? List.of(ONGOING, IMMINENT, UPCOMING, ENDED)
                : List.of(ONGOING, IMMINENT, UPCOMING);
    }
}
