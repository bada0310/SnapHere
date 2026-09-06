package com.snaphere.api.event;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.event.dto.EventRegionSummaryResponse;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 이벤트 목록·시도별 요약 — EVT-005 ~ EVT-010
 *
 * <p>정렬 자체는 SQL 이 한다. 여기서 확인하는 것은 서비스의 판단이다 — 한 건 더 읽어
 * 다음 페이지를 알아내는지, 마지막 행으로 커서를 만드는지, 신규 기준 일수를 규약 안으로
 * 자르는지.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EventQueryServiceTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Mock
    private EventRepository events;

    private EventQueryService service;

    @BeforeEach
    void setUp() {
        service = new EventQueryService(events, new PagingProperties(20, 50));
    }

    @Test
    @DisplayName("요청 크기보다 한 건 더 읽는다 — 다음 페이지 유무를 세는 쿼리 없이 안다")
    void 한_건_더() {
        when(events.findPage(any(), any(), any(), anyList(), any(), any(), any(), anyInt()))
                .thenReturn(List.of());

        service.list(null, null, null, null, 5);

        verify(events).findPage(any(), any(), any(), anyList(), any(), any(), any(), eq(6));
    }

    @Test
    @DisplayName("읽은 수가 요청 크기 이하면 다음 페이지가 없다")
    void 마지막_페이지() {
        LocalDate today = LocalDate.now(KST);
        when(events.findPage(any(), any(), any(), anyList(), any(), any(), any(), anyInt()))
                .thenReturn(pageOf(today, 2));

        CursorPage<EventSummaryResponse> page = service.list(null, null, null, null, 5);

        assertThat(page.items()).hasSize(2);
        assertThat(page.hasNext()).isFalse();
        assertThat(page.nextCursor()).isNull();
    }

    @Test
    @DisplayName("더 있으면 마지막 행으로 커서를 만들고 여분 한 건은 버린다")
    void 다음_페이지() {
        LocalDate today = LocalDate.now(KST);
        when(events.findPage(any(), any(), any(), anyList(), any(), any(), any(), anyInt()))
                .thenReturn(pageOf(today, 3));

        CursorPage<EventSummaryResponse> page = service.list(null, null, null, null, 2);

        assertThat(page.items()).hasSize(2);
        assertThat(page.hasNext()).isTrue();

        EventCursor cursor = EventCursor.decode(page.nextCursor());
        assertThat(cursor.eventId()).isEqualTo(2L);
    }

    @Test
    @DisplayName("커서를 받으면 정렬 키 세 개를 그대로 쿼리에 넘긴다")
    void 커서_전달() {
        LocalDate start = LocalDate.now(KST).plusDays(3);
        String cursor = new EventCursor(EventSortGroup.IMMINENT, start, 7L).encode();
        when(events.findPage(any(), any(), any(), anyList(), any(), any(), any(), anyInt()))
                .thenReturn(List.of());

        service.list(null, null, null, cursor, 20);

        verify(events).findPage(any(), any(), any(), anyList(),
                eq(EventSortGroup.IMMINENT), eq(start), eq(7L), anyInt());
    }

    @Test
    @DisplayName("status 를 명시하면 그 그룹만 조회한다 (EVT-006)")
    void status_필터() {
        when(events.findPage(any(), any(), any(), anyList(), any(), any(), any(), anyInt()))
                .thenReturn(List.of());

        service.list(null, "ENDED", false, null, 20);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Integer>> groups = ArgumentCaptor.forClass(List.class);
        verify(events).findPage(any(), any(), any(), groups.capture(), any(), any(), any(), anyInt());
        assertThat(groups.getValue()).containsExactly(EventSortGroup.ENDED);
    }

    @Test
    @DisplayName("시도 요약은 행사가 없는 시도도 0 으로 내보낸다 — sum 이 null 이어도")
    void 시도_요약() {
        when(events.findRegionSummary(any(), any())).thenReturn(List.of(
                row(1, "서울", 12, 2L, OffsetDateTime.parse("2026-08-30T04:30:00+09:00")),
                // 행사가 없는 시도: count 는 0 이지만 sum 은 null 이다 (JPQL 집계의 성질)
                row(2, "인천", 0, null, null)));

        List<EventRegionSummaryResponse> summaries = service.regionSummary(null);

        assertThat(summaries).hasSize(2);
        assertThat(summaries.get(0).newCount()).isEqualTo(2);
        assertThat(summaries.get(1).eventCount()).isZero();
        assertThat(summaries.get(1).newCount()).isZero();   // null 이 0 으로 메워진다
        assertThat(summaries.get(1).latestAddedAt()).isNull();
    }

    @Test
    @DisplayName("신규 기준 일수는 기본 7, 최대 30 — 규약 밖 값은 조용히 자른다")
    void 신규_기준_일수() {
        when(events.findRegionSummary(any(), any())).thenReturn(List.of());
        ArgumentCaptor<OffsetDateTime> since = ArgumentCaptor.forClass(OffsetDateTime.class);

        service.regionSummary(999);
        verify(events).findRegionSummary(any(), since.capture());

        OffsetDateTime now = OffsetDateTime.now(KST);
        assertThat(since.getValue()).isAfter(now.minusDays(31));
        assertThat(since.getValue()).isBefore(now.minusDays(29));
    }

    private static List<EventEntity> pageOf(LocalDate today, int count) {
        List<EventEntity> rows = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            rows.add(EventFixtures.event(i + 1L, today.minusDays(1), today.plusDays(3),
                    OffsetDateTime.now(KST)));
        }
        return rows;
    }

    private static EventRepository.EventRegionSummaryRow row(int areaCode, String areaName,
                                                             long eventCount, Long newCount,
                                                             OffsetDateTime latestAddedAt) {
        return new EventRepository.EventRegionSummaryRow() {
            @Override
            public Integer getAreaCode() {
                return areaCode;
            }

            @Override
            public String getAreaName() {
                return areaName;
            }

            @Override
            public long getEventCount() {
                return eventCount;
            }

            @Override
            public Long getNewCount() {
                return newCount;
            }

            @Override
            public OffsetDateTime getLatestAddedAt() {
                return latestAddedAt;
            }
        };
    }
}
