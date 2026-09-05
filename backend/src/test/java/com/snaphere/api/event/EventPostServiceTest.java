package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.post.PostCursor;
import com.snaphere.api.post.PostResponseAssembler;
import com.snaphere.api.post.dto.PostSummaryResponse;
import com.snaphere.api.post.entity.PostEntity;
import com.snaphere.api.post.repository.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 행사 참여 게시글 — EVT-014 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EventPostServiceTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Mock
    private EventRepository events;
    @Mock
    private PostRepository posts;
    @Mock
    private PostResponseAssembler assembler;

    private EventPostService service;

    @BeforeEach
    void setUp() {
        service = new EventPostService(events, posts, assembler, new PagingProperties(20, 50));
        LocalDate today = LocalDate.now(KST);
        when(events.findById(1L)).thenReturn(Optional.of(
                EventFixtures.event(1L, today.minusDays(1), today.plusDays(3),
                        OffsetDateTime.now(KST))));
        when(assembler.summaries(any(), any())).thenAnswer(inv -> {
            List<PostEntity> rows = inv.getArgument(0);
            List<PostSummaryResponse> out = new ArrayList<>();
            for (int i = 0; i < rows.size(); i++) {
                out.add(null);
            }
            return out;
        });
    }

    @Test
    @DisplayName("요청 크기보다 한 건 더 읽는다")
    void 한_건_더() {
        when(posts.findEventPosts(anyLong(), any(), any(), any())).thenReturn(List.of());

        service.postsOf(1L, null, 5, Optional.empty());

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(posts).findEventPosts(anyLong(), any(), any(), pageable.capture());
        assertThat(pageable.getValue().getPageSize()).isEqualTo(6);
    }

    @Test
    @DisplayName("더 있으면 마지막 행으로 커서를 만들고 여분은 버린다")
    void 다음_페이지() {
        when(posts.findEventPosts(anyLong(), any(), any(), any())).thenReturn(page(3));

        CursorPage<PostSummaryResponse> result = service.postsOf(1L, null, 2, Optional.empty());

        assertThat(result.items()).hasSize(2);
        assertThat(result.hasNext()).isTrue();
        assertThat(PostCursor.decode(result.nextCursor()).postId()).isEqualTo(2L);
    }

    @Test
    @DisplayName("참여 게시글이 없으면 빈 페이지 — 404 가 아니다")
    void 빈_페이지() {
        when(posts.findEventPosts(anyLong(), any(), any(), any())).thenReturn(List.of());

        CursorPage<PostSummaryResponse> result = service.postsOf(1L, null, 20, Optional.empty());

        assertThat(result.items()).isEmpty();
        assertThat(result.hasNext()).isFalse();
    }

    @Test
    @DisplayName("없는 행사는 404 — 상세와 엇갈리지 않게 한다")
    void 없는_행사() {
        when(events.findById(9L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.postsOf(9L, null, 20, Optional.empty()))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.EVENT_NOT_FOUND));
    }

    @Test
    @DisplayName("숨긴 행사도 404")
    void 숨긴_행사() {
        LocalDate today = LocalDate.now(KST);
        when(events.findById(2L)).thenReturn(Optional.of(
                EventFixtures.hidden(2L, today, today.plusDays(3), OffsetDateTime.now(KST))));

        assertThatThrownBy(() -> service.postsOf(2L, null, 20, Optional.empty()))
                .isInstanceOf(ApiException.class);
    }

    private static List<PostEntity> page(int count) {
        List<PostEntity> rows = new ArrayList<>(count);
        OffsetDateTime base = OffsetDateTime.now(KST);
        for (int i = 0; i < count; i++) {
            PostEntity post = BeanUtils.instantiateClass(PostEntity.class);
            ReflectionTestUtils.setField(post, "postId", i + 1L);
            ReflectionTestUtils.setField(post, "createdAt", base.minusMinutes(i));
            rows.add(post);
        }
        return rows;
    }
}
