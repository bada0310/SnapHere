package com.snaphere.api.event.dto;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.event.EventStatus;
import com.snaphere.api.event.entity.EventEntity;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;

/**
 * 명세: 4. 응답 스키마 &gt; EventSummary. 이벤트 홈 카드가 쓰는 공통 필드. (EVT-005 ~ EVT-010)
 *
 * <p>{@code eventId} 는 {@code evt_} 외부 ID 다. 생숫자를 내보내면 그 값으로
 * {@code GET /api/v1/events/&#123;eventId&#125;} 를 부를 수 없다 — 장소에서 같은 실수를 한 번 했다.
 *
 * <p>{@code isNew} 는 앱이 "새 행사가 생긴 시도" 테두리를 강조하는 근거다 (EVT-008). 한 번
 * 열어 본 뒤의 강조 해제는 서버가 아니라 앱 로컬이 기억한다 (EVT-009) — 그래서 읽음 상태를
 * 담는 필드가 없고, 대신 판정 원본인 {@code createdAt} 을 함께 준다.
 */
public record EventSummaryResponse(
        String eventId,
        String title,
        String thumbnailUrl,
        int areaCode,
        LocalDate startDate,
        LocalDate endDate,
        String status,
        Integer dday,
        boolean isNew,
        OffsetDateTime createdAt,
        int participantCount
) {
    /** 최근 이 일수 안에 적재된 행사를 신규로 본다. (EVT-008) */
    public static final int NEW_WITHIN_DAYS = 7;

    public static EventSummaryResponse of(EventEntity event, LocalDate today, OffsetDateTime now) {
        EventStatus status = EventStatus.of(event.getStartDate(), event.getEndDate(), today);
        return new EventSummaryResponse(
                ExternalIds.event(event.getEventId()),
                event.getTitle(),
                event.getThumbnailUrl(),
                event.getAreaCode(),
                event.getStartDate(),
                event.getEndDate(),
                status.name(),
                dday(status, event.getStartDate(), today),
                isNew(event.getCreatedAt(), now),
                event.getCreatedAt(),
                event.getParticipantCount());
    }

    /**
     * 시작까지 남은 일수. 진행 중이면 0, 이미 끝났으면 null 이다.
     *
     * <p>종료 행사에 0 을 주지 않는 이유: 앱이 "D-DAY" 배지를 그려 끝난 행사가 오늘 시작하는
     * 것처럼 보인다. 값이 없다는 것을 값으로 말해야 한다.
     */
    private static Integer dday(EventStatus status, LocalDate startDate, LocalDate today) {
        return switch (status) {
            case ONGOING -> 0;
            case UPCOMING -> (int) ChronoUnit.DAYS.between(today, startDate);
            case ENDED -> null;
        };
    }

    private static boolean isNew(OffsetDateTime createdAt, OffsetDateTime now) {
        return createdAt != null && createdAt.isAfter(now.minusDays(NEW_WITHIN_DAYS));
    }
}
