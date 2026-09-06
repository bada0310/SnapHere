package com.snaphere.api.visit;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.visit.dto.VisitResponse;
import com.snaphere.api.visit.entity.VisitEntity;
import com.snaphere.api.visit.repository.VisitRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 내 방문 기록 조회 — VST-003
 *
 * <p>장소를 한 번에 모아 붙이는지와 커서 규약이 이 서비스의 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class VisitQueryServiceTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");

    @Mock private VisitRepository visits;
    @Mock private PlaceRepository places;

    private VisitQueryService service;

    @BeforeEach
    void setUp() {
        service = new VisitQueryService(visits, places, new PagingProperties(20, 50));
        when(places.findAllById(any())).thenReturn(List.of(place(5L, "경복궁"), place(6L, "창덕궁")));
    }

    private static PlaceEntity place(long placeId, String title) {
        PlaceEntity place = PlaceEntity.userPlace(title, "서울", 37.5, 127.0, 1, 11, USER);
        ReflectionTestUtils.setField(place, "placeId", placeId);
        return place;
    }

    private static VisitEntity visit(long visitId, long placeId, LocalDate on) {
        VisitEntity visit = new VisitEntity() {
        };
        ReflectionTestUtils.setField(visit, "visitId", visitId);
        ReflectionTestUtils.setField(visit, "userId", USER);
        ReflectionTestUtils.setField(visit, "placeId", placeId);
        ReflectionTestUtils.setField(visit, "postId", 100L + visitId);
        ReflectionTestUtils.setField(visit, "visitedOn", on);
        ReflectionTestUtils.setField(visit, "createdAt", OffsetDateTime.now());
        return visit;
    }

    @Test
    @DisplayName("장소는 한 번에 모아 붙인다 — 방문마다 조회하면 페이지 크기만큼 쿼리가 늘어난다")
    void loadsPlacesInOneQuery() {
        when(visits.findMine(eq(USER), isNull(), isNull(), any(Pageable.class)))
                .thenReturn(List.of(visit(3L, 5L, LocalDate.of(2026, 9, 4)),
                        visit(2L, 6L, LocalDate.of(2026, 9, 3)),
                        visit(1L, 5L, LocalDate.of(2026, 9, 2))));

        CursorPage<VisitResponse> page = service.myVisits(USER, null, null);

        assertThat(page.items()).hasSize(3);
        assertThat(page.items().get(0).place().title()).isEqualTo("경복궁");
        verify(places, times(1)).findAllById(any());
    }

    @Test
    @DisplayName("요청 크기보다 하나 더 읽어 다음 페이지를 판단하고, 마지막 행으로 커서를 만든다")
    void paginates() {
        List<VisitEntity> rows = new ArrayList<>();
        for (int i = 20; i >= 0; i--) {
            rows.add(visit(100 + i, 5L, LocalDate.of(2026, 9, 1).plusDays(i)));
        }
        when(visits.findMine(eq(USER), isNull(), isNull(), any(Pageable.class))).thenReturn(rows);

        CursorPage<VisitResponse> page = service.myVisits(USER, null, null);

        assertThat(page.items()).hasSize(20);
        assertThat(page.hasNext()).isTrue();
        assertThat(VisitCursor.decode(page.nextCursor()).visitId()).isEqualTo(101L);
    }

    @Test
    @DisplayName("방문이 없으면 빈 페이지고 장소 조회도 하지 않는다")
    void emptyPage() {
        when(visits.findMine(any(), any(), any(), any(Pageable.class))).thenReturn(List.of());

        CursorPage<VisitResponse> page = service.myVisits(USER, null, null);

        assertThat(page.items()).isEmpty();
        assertThat(page.hasNext()).isFalse();
        verify(places, never()).findAllById(any());
    }

    @Test
    @DisplayName("커서를 받으면 날짜와 2차 키를 조회에 넘긴다")
    void passesCursorKeys() {
        String cursor = new VisitCursor(LocalDate.of(2026, 9, 4), 55L).encode();
        when(visits.findMine(any(), any(), any(), any(Pageable.class))).thenReturn(List.of());

        service.myVisits(USER, cursor, null);

        verify(visits).findMine(eq(USER), eq(LocalDate.of(2026, 9, 4)), eq(55L),
                any(Pageable.class));
    }
}
