package com.snaphere.api.feed;

import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.social.FollowService;
import com.snaphere.api.social.SocialDtos;
import com.snaphere.api.post.dto.PostSummaryResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * API-CMU-002·003 — 팔로잉 피드와 최근 피드.
 *
 * <p>기능 명세: 1.1 피드 &gt; 팔로잉 피드·최근 피드
 * <p>요구사항: CMU-001, CMU-003, CMU-010, SOC-014
 *
 * <p>지도·탐색의 게시글 목록(API-PST-004)과 역할이 다르다. 이쪽은 필터 없는 시간순이고,
 * 그쪽은 지역·장소·태그·기간 필터가 붙는다.
 */
@RestController
@RequestMapping("/api/v1/feeds")
public class FeedController {

    private final FeedService feedService;
    private final FollowService followService;
    private final CurrentUserProvider currentUser;

    public FeedController(FeedService feedService, FollowService followService,
                          CurrentUserProvider currentUser) {
        this.feedService = feedService;
        this.followService = followService;
        this.currentUser = currentUser;
    }

    @GetMapping("/recent")
    public ResponseEntity<ApiResponse<CursorPage<PostSummaryResponse>>> recent(
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {

        CursorPage<PostSummaryResponse> page = feedService.recent(cursor, size);

        return ResponseEntity.ok(ApiResponse.ok(page,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    @GetMapping("/following")
    public ResponseEntity<ApiResponse<FollowingFeedResult>> following(
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {
        var viewer = currentUser.require(httpRequest).userId();
        CursorPage<PostSummaryResponse> page = feedService.following(viewer, cursor, size);
        var suggestions = page.items().isEmpty()
                ? followService.recommendations(viewer, 10)
                : java.util.List.<SocialDtos.UserSummary>of();
        return ResponseEntity.ok(ApiResponse.ok(
                new FollowingFeedResult(page, page.items().isEmpty(), suggestions),
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    public record FollowingFeedResult(
            CursorPage<PostSummaryResponse> page,
            boolean empty,
            java.util.List<SocialDtos.UserSummary> suggestedUsers) {
    }
}
