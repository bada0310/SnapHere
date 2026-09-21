package com.snaphere.api.feed;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.post.PostCursor;
import com.snaphere.api.post.PostResponseAssembler;
import com.snaphere.api.post.dto.PostSummaryResponse;
import com.snaphere.api.post.entity.PostEntity;
import com.snaphere.api.post.repository.PostRepository;
import com.snaphere.api.post.tier.PhotoSource;
import com.snaphere.api.post.tier.TrustTier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 최근 피드 — CMU-003, CMU-010
 *
 * <p>필터를 하나도 걸지 않는지, 커서 규약을 지키는지가 이 서비스의 판단 전부다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FeedServiceTest {

    private static final UUID AUTHOR = UUID.fromString("11111111-2222-3333-4444-555555555555");

    @Mock private PostRepository posts;
    @Mock private PostResponseAssembler assembler;

    private FeedService service;

    @BeforeEach
    void setUp() {
        service = new FeedService(posts, assembler, new PagingProperties(20, 50));
        when(assembler.summaries(any()))
                .thenAnswer(call -> Collections.<PostSummaryResponse>nCopies(
                        ((List<?>) call.getArgument(0)).size(), null));
    }

    private static PostEntity post(long postId, int minute) {
        PostEntity post = PostEntity.create(AUTHOR, 1L, null, 1, "캡션", TrustTier.HIGH,
                37.5, 127.0, null, PhotoSource.ALBUM);
        ReflectionTestUtils.setField(post, "postId", postId);
        ReflectionTestUtils.setField(post, "createdAt",
                OffsetDateTime.parse("2026-09-03T12:%02d:00Z".formatted(minute)));
        return post;
    }

    @Test
    @DisplayName("지역·장소·태그·기간 필터를 하나도 걸지 않는다 — 최근 피드는 지금 올라오는 것을 본다")
    void appliesNoFilter() {
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(post(1L, 1)));

        service.recent(null, null);

        verify(posts).findFeed(isNull(), isNull(), isNull(), isNull(),
                isNull(), isNull(), any(Pageable.class));
    }

    @Test
    @DisplayName("요청 크기보다 하나 더 읽어 다음 페이지를 판단하고, 마지막 행으로 커서를 만든다")
    void paginates() {
        List<PostEntity> rows = new ArrayList<>();
        for (int i = 20; i >= 0; i--) {
            rows.add(post(100 + i, i));
        }
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any())).thenReturn(rows);

        CursorPage<PostSummaryResponse> page = service.recent(null, null);

        assertThat(page.items()).hasSize(20);
        assertThat(page.hasNext()).isTrue();
        // 21번째(가장 오래된 100번)는 존재 판단에만 쓰고 버린다.
        assertThat(PostCursor.decode(page.nextCursor()).postId()).isEqualTo(101L);
    }

    @Test
    @DisplayName("마지막 페이지면 커서를 주지 않는다 — 앱이 무한 스크롤을 멈출 근거다")
    void lastPageHasNoCursor() {
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(post(2L, 2), post(1L, 1)));

        CursorPage<PostSummaryResponse> page = service.recent(null, null);

        assertThat(page.items()).hasSize(2);
        assertThat(page.hasNext()).isFalse();
        assertThat(page.nextCursor()).isNull();
    }

    @Test
    @DisplayName("게시글이 없으면 빈 페이지다")
    void emptyPage() {
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any())).thenReturn(List.of());

        CursorPage<PostSummaryResponse> page = service.recent(null, null);

        assertThat(page.items()).isEmpty();
        assertThat(page.hasNext()).isFalse();
    }

    @Test
    @DisplayName("size 를 넘겨 보내도 규약대로 50 으로 자른다")
    void sizeContract() {
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any())).thenReturn(List.of());

        service.recent(null, 500);

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(posts).findFeed(any(), any(), any(), any(), any(), any(), pageable.capture());
        // 한 건 더 읽으므로 51 이다.
        assertThat(pageable.getValue().getPageSize()).isEqualTo(51);
    }

    @Test
    @DisplayName("커서를 받으면 그 두 키를 조회에 넘긴다 (CMU-010)")
    void passesCursorKeys() {
        OffsetDateTime at = OffsetDateTime.parse("2026-09-03T12:10:00Z");
        String cursor = new PostCursor(at, 55L).encode();
        when(posts.findFeed(any(), any(), any(), any(), any(), any(), any())).thenReturn(List.of());

        service.recent(cursor, null);

        ArgumentCaptor<OffsetDateTime> createdAt = ArgumentCaptor.forClass(OffsetDateTime.class);
        ArgumentCaptor<Long> postId = ArgumentCaptor.forClass(Long.class);
        verify(posts).findFeed(isNull(), isNull(), isNull(), isNull(),
                createdAt.capture(), postId.capture(), any(Pageable.class));
        assertThat(createdAt.getValue().toInstant()).isEqualTo(at.toInstant());
        assertThat(postId.getValue()).isEqualTo(55L);
    }

    @Test
    @DisplayName("팔로잉 피드는 로그인 사용자를 조회 조건으로 넘긴다")
    void followingUsesViewer() {
        when(posts.findFollowingFeed(any(), any(), any(), any())).thenReturn(List.of(post(1L, 1)));

        CursorPage<PostSummaryResponse> page = service.following(AUTHOR, null, 20);

        assertThat(page.items()).hasSize(1);
        verify(posts).findFollowingFeed(org.mockito.ArgumentMatchers.eq(AUTHOR),
                isNull(), isNull(), any(Pageable.class));
    }
}
