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
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * API-EVT-004 — 행사 참여 게시글. (EVT-014)
 *
 * <p>기능 명세: 3.2 행사 상세 &gt; 참여 게시글
 *
 * <p>커서와 조립은 피드와 같은 규칙을 쓴다. 이 목록만 다른 정렬이나 다른 요약 형태를 쓰면
 * 같은 카드가 화면마다 달라 보인다.
 */
@Service
public class EventPostService {

    private final EventRepository events;
    private final PostRepository posts;
    private final PostResponseAssembler assembler;
    private final PagingProperties paging;

    public EventPostService(EventRepository events,
                            PostRepository posts,
                            PostResponseAssembler assembler,
                            PagingProperties paging) {
        this.events = events;
        this.posts = posts;
        this.assembler = assembler;
        this.paging = paging;
    }

    /**
     * @param viewerId 로그인 사용자. 비회원이면 비어 있고 {@code isLiked} 가 null 로 나간다
     */
    @Transactional(readOnly = true)
    public CursorPage<PostSummaryResponse> postsOf(long eventId, String cursor, Integer size,
                                                   Optional<UUID> viewerId) {
        requireActiveEvent(eventId);

        int pageSize = paging.resolve(size);
        PostCursor decoded = PostCursor.decode(cursor);

        // 한 건 더 읽어 다음 페이지가 있는지 본다 — 피드와 같은 방식이다.
        List<PostEntity> rows = posts.findEventPosts(eventId,
                decoded == null ? null : decoded.createdAt(),
                decoded == null ? null : decoded.postId(),
                PageRequest.of(0, pageSize + 1));

        boolean hasNext = rows.size() > pageSize;
        List<PostEntity> page = hasNext ? rows.subList(0, pageSize) : rows;
        if (page.isEmpty()) {
            return CursorPage.empty();
        }

        PostEntity last = page.get(page.size() - 1);
        String nextCursor = hasNext
                ? new PostCursor(last.getCreatedAt(), last.getPostId()).encode()
                : null;
        return CursorPage.of(assembler.summaries(page, viewerId), nextCursor);
    }

    /**
     * 없는 행사면 404 다. 빈 목록으로 돌려주지 않는다 — 앱이 "참여 게시글이 아직 없는 행사"와
     * "잘못된 링크"를 구분해야 하고, 상세 화면이 이미 404 로 막히는데 이 목록만 200 을 주면
     * 두 응답이 엇갈린다.
     */
    private void requireActiveEvent(long eventId) {
        events.findById(eventId)
                .filter(event -> event.getStatus() == EventLifecycle.ACTIVE)
                .orElseThrow(() -> new ApiException(ErrorCode.EVENT_NOT_FOUND,
                        Map.of("eventId", eventId)));
    }
}
