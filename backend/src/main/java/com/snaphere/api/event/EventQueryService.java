package com.snaphere.api.event;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.event.dto.EventRegionSummaryResponse;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

/**
 * API-EVT-001 · API-EVT-006 — 이벤트 목록과 시도별 요약.
 *
 * <p>기능 명세: 3.1 이벤트 홈
 * <p>요구사항: EVT-002, EVT-005 ~ EVT-010
 */
@Service
public class EventQueryService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    /** 시도 요약의 신규 판정 기준 일수. 기본 7, 최대 30 (명세 API-EVT-006). */
    private static final int DEFAULT_NEW_WITHIN_DAYS = 7;
    private static final int MAX_NEW_WITHIN_DAYS = 30;

    private final EventRepository events;
    private final PagingProperties paging;

    public EventQueryService(EventRepository events, PagingProperties paging) {
        this.events = events;
        this.paging = paging;
    }

    /**
     * 진행 중 → 임박 → 예정 → 종료 순으로 조회한다. (EVT-005, EVT-006, EVT-007, EVT-010)
     *
     * <p>알 수 없는 {@code status} 문자열은 400 으로 막지 않고 "지정 안 함" 으로 본다. 목록이
     * 오타 하나에 실패하면 앱이 이벤트 홈을 아예 못 그린다 — 페이지 크기를 조용히 자르는 것과
     * 같은 판단이다.
     */
    @Transactional(readOnly = true)
    public CursorPage<EventSummaryResponse> list(Integer areaCode, String status,
                                                 Boolean includeEnded,
                                                 String cursor, Integer size) {
        OffsetDateTime now = OffsetDateTime.now(KST);
        LocalDate today = now.toLocalDate();
        int limit = paging.resolve(size);

        List<Integer> groups = EventSortGroup.filterOf(
                EventStatus.parseOrNull(status), Boolean.TRUE.equals(includeEnded));
        EventCursor decoded = EventCursor.decode(cursor);

        // 다음 페이지가 있는지 알려면 한 건 더 읽어야 한다. 세어 보는 쿼리를 한 번 더
        // 돌리는 것보다 싸다.
        List<EventEntity> rows = events.findPage(
                today, today.plusDays(EventSortGroup.IMMINENT_WITHIN_DAYS), areaCode, groups,
                decoded == null ? null : decoded.sortGroup(),
                decoded == null ? null : decoded.startDate(),
                decoded == null ? null : decoded.eventId(),
                limit + 1);

        boolean hasNext = rows.size() > limit;
        List<EventEntity> page = hasNext ? rows.subList(0, limit) : rows;

        List<EventSummaryResponse> items = new ArrayList<>(page.size());
        for (EventEntity event : page) {
            items.add(EventSummaryResponse.of(event, today, now));
        }

        String nextCursor = null;
        if (hasNext) {
            EventEntity last = page.get(page.size() - 1);
            nextCursor = new EventCursor(
                    EventSortGroup.of(last.getStartDate(), last.getEndDate(), today),
                    last.getStartDate(),
                    last.getEventId()).encode();
        }
        return CursorPage.of(items, nextCursor);
    }

    /** 시도별 진행·예정 수와 신규 수. 행사가 없는 시도도 0 으로 나온다. (EVT-007 ~ EVT-009) */
    @Transactional(readOnly = true)
    public List<EventRegionSummaryResponse> regionSummary(Integer newWithinDays) {
        OffsetDateTime now = OffsetDateTime.now(KST);
        int days = resolveNewWithinDays(newWithinDays);

        List<EventRepository.EventRegionSummaryRow> rows =
                events.findRegionSummary(now.toLocalDate(), now.minusDays(days));

        List<EventRegionSummaryResponse> summaries = new ArrayList<>(rows.size());
        for (EventRepository.EventRegionSummaryRow row : rows) {
            // 행사가 없는 시도에서 sum 은 null 이다. 앱은 0 을 기대하므로 여기서 메운다 —
            // 응답에 null 이 나가면 칩 강조 판정(newCount > 0)이 앱에서 터진다 (EVT-008).
            Long newCount = row.getNewCount();
            summaries.add(new EventRegionSummaryResponse(
                    row.getAreaCode(),
                    row.getAreaName(),
                    (int) row.getEventCount(),
                    newCount == null ? 0 : newCount.intValue(),
                    row.getLatestAddedAt()));
        }
        return summaries;
    }

    private int resolveNewWithinDays(Integer requested) {
        if (requested == null || requested <= 0) {
            return DEFAULT_NEW_WITHIN_DAYS;
        }
        return Math.min(requested, MAX_NEW_WITHIN_DAYS);
    }
}
