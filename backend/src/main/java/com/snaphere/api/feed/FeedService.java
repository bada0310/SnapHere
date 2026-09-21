package com.snaphere.api.feed;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.post.PostCursor;
import com.snaphere.api.post.PostResponseAssembler;
import com.snaphere.api.post.dto.PostSummaryResponse;
import com.snaphere.api.post.entity.PostEntity;
import com.snaphere.api.post.repository.PostRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * API-CMU-003 — 최근 피드.
 *
 * <p>기능 명세: 1.1 피드 &gt; 최근 피드
 * <p>요구사항: CMU-003, CMU-010
 *
 * <p>기간·지역 필터가 없다. 최근 피드는 "지금 올라오는 것"을 보는 자리이고, 필터를 붙이면 인기
 * 피드와 하는 일이 겹친다 (CMU-004 에서 탭을 나눈 이유다).
 *
 * <p>페이징 코드가 {@code PostFeedService} 와 겹친다. 그쪽을 고쳐 함께 쓰게 만들면 게시글 목록을
 * 만지는 사람과 충돌하므로 일부러 따로 두었다 — 커서 규약(SYS-003, CMU-010)만 같으면 된다.
 */
@Service
public class FeedService {

    private final PostRepository posts;
    private final PostResponseAssembler assembler;
    private final PagingProperties paging;

    public FeedService(PostRepository posts,
                       PostResponseAssembler assembler,
                       PagingProperties paging) {
        this.posts = posts;
        this.assembler = assembler;
        this.paging = paging;
    }

    /**
     * 최신 공개 게시글을 시간순으로. (CMU-003)
     *
     * <p>비회원도 본다. 삭제·가림 게시글은 조회 쿼리가 이미 걸러 낸다.
     *
     * <p>요청 크기보다 한 건 더 읽어 다음 페이지 존재를 판단한다. COUNT 를 따로 세면 게시글이
     * 쌓일수록 같은 조건을 두 번 훑는다.
     */
    @Transactional(readOnly = true)
    public CursorPage<PostSummaryResponse> recent(String cursor, Integer size) {
        int pageSize = paging.resolve(size);
        PostCursor decoded = PostCursor.decode(cursor);

        List<PostEntity> rows = posts.findFeed(null, null, null, null,
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
        return CursorPage.of(assembler.summaries(page), nextCursor);
    }

    /** 현재 사용자가 팔로우한 사용자의 공개 게시글만 최신순으로 보여 준다. (CMU-001, CMU-010) */
    @Transactional(readOnly = true)
    public CursorPage<PostSummaryResponse> following(UUID viewerId, String cursor, Integer size) {
        int pageSize = paging.resolve(size);
        PostCursor decoded = PostCursor.decode(cursor);
        List<PostEntity> rows = posts.findFollowingFeed(
                viewerId,
                decoded == null ? null : decoded.createdAt(),
                decoded == null ? null : decoded.postId(),
                PageRequest.of(0, pageSize + 1));
        boolean hasNext = rows.size() > pageSize;
        List<PostEntity> page = hasNext ? rows.subList(0, pageSize) : rows;
        if (page.isEmpty()) return CursorPage.empty();
        PostEntity last = page.get(page.size() - 1);
        String nextCursor = hasNext
                ? new PostCursor(last.getCreatedAt(), last.getPostId()).encode()
                : null;
        return CursorPage.of(assembler.summaries(page), nextCursor);
    }
}
