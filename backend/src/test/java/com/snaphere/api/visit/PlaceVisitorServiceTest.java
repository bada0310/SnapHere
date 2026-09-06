package com.snaphere.api.visit;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.post.dto.UserSummaryResponse;
import com.snaphere.api.user.AuthorSnapshot;
import com.snaphere.api.user.AuthorSnapshotReader;
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
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 장소 방문자 조회 — VST-005
 *
 * <p>사용자 정보를 한 번에 모으는지, 탈퇴한 사용자를 어떻게 다루는지가 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PlaceVisitorServiceTest {

    private static final long PLACE_ID = 5L;
    private static final UUID A = UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final UUID B = UUID.fromString("22222222-2222-2222-2222-222222222222");

    @Mock private VisitRepository visits;
    @Mock private AuthorSnapshotReader users;

    private PlaceVisitorService service;

    @BeforeEach
    void setUp() {
        service = new PlaceVisitorService(visits, users, new PagingProperties(20, 50));
    }

    private static VisitEntity visit(long visitId, UUID userId, LocalDate on) {
        VisitEntity visit = new VisitEntity() {
        };
        ReflectionTestUtils.setField(visit, "visitId", visitId);
        ReflectionTestUtils.setField(visit, "userId", userId);
        ReflectionTestUtils.setField(visit, "placeId", PLACE_ID);
        ReflectionTestUtils.setField(visit, "postId", 100L);
        ReflectionTestUtils.setField(visit, "visitedOn", on);
        ReflectionTestUtils.setField(visit, "createdAt", OffsetDateTime.now());
        return visit;
    }

    @Test
    @DisplayName("사용자 정보를 한 번에 모아 붙이고 최근 방문 순서를 지킨다")
    void loadsUsersInOneQuery() {
        when(visits.findVisitorsOfPlace(eq(PLACE_ID), isNull(), isNull(), any(Pageable.class)))
                .thenReturn(List.of(visit(9L, B, LocalDate.of(2026, 9, 4)),
                        visit(2L, A, LocalDate.of(2026, 9, 1))));
        when(users.findAllByIds(any())).thenReturn(Map.of(
                A, new AuthorSnapshot(A, "가", null),
                B, new AuthorSnapshot(B, "나", null)));

        CursorPage<UserSummaryResponse> page = service.ofPlace(PLACE_ID, null, null);

        assertThat(page.items()).extracting(UserSummaryResponse::nickname)
                .containsExactly("나", "가");
        verify(users, times(1)).findAllByIds(any());
    }

    @Test
    @DisplayName("탈퇴해서 정보가 없는 사용자는 이름 없는 칸으로 남기지 않고 뺀다")
    void skipsMissingUser() {
        when(visits.findVisitorsOfPlace(anyLong(), any(), any(), any(Pageable.class)))
                .thenReturn(List.of(visit(9L, B, LocalDate.of(2026, 9, 4)),
                        visit(2L, A, LocalDate.of(2026, 9, 1))));
        when(users.findAllByIds(any())).thenReturn(Map.of(A, new AuthorSnapshot(A, "가", null)));

        assertThat(service.ofPlace(PLACE_ID, null, null).items())
                .extracting(UserSummaryResponse::nickname).containsExactly("가");
    }

    @Test
    @DisplayName("방문자가 없으면 빈 페이지고 사용자 조회도 하지 않는다")
    void emptyPage() {
        when(visits.findVisitorsOfPlace(anyLong(), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());

        CursorPage<UserSummaryResponse> page = service.ofPlace(PLACE_ID, null, null);

        assertThat(page.items()).isEmpty();
        verify(users, org.mockito.Mockito.never()).findAllByIds(any());
    }

    @Test
    @DisplayName("커서를 받으면 날짜와 2차 키를 조회에 넘긴다")
    void passesCursorKeys() {
        when(visits.findVisitorsOfPlace(anyLong(), any(), any(), any(Pageable.class)))
                .thenReturn(List.of());

        service.ofPlace(PLACE_ID, new VisitCursor(LocalDate.of(2026, 9, 4), 55L).encode(), null);

        verify(visits).findVisitorsOfPlace(eq(PLACE_ID), eq(LocalDate.of(2026, 9, 4)), eq(55L),
                any(Pageable.class));
    }
}
