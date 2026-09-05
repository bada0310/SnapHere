package com.snaphere.api.event;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.event.dto.EventDetailResponse;
import com.snaphere.api.event.dto.EventRegionSummaryResponse;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.dto.EventUploadContextResponse;
import com.snaphere.api.post.dto.PostSummaryResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * API-EVT-001 ~ API-EVT-006 — 이벤트. (EVT-002, EVT-005 ~ EVT-020)
 *
 * <p>비회원도 본다. 응답이 요청자에 따라 달라지지 않으므로 공용 캐시에 10분 올려도 된다
 * (명세 캐시·멱등 열). 신규 강조가 최대 10분 늦게 붙지만, 매 스크롤마다 17개 시도를
 * 집계하는 쪽이 더 비싸다.
 */
@RestController
@RequestMapping("/api/v1/events")
public class EventController {

    private static final Duration CACHE_TTL = Duration.ofMinutes(10);

    private final EventQueryService eventQueryService;
    private final EventDetailService eventDetailService;
    private final EventPostService eventPostService;
    private final EventNearbyService eventNearbyService;
    private final EventUploadContextService eventUploadContextService;
    private final CurrentUserProvider currentUserProvider;

    public EventController(EventQueryService eventQueryService,
                           EventDetailService eventDetailService,
                           EventPostService eventPostService,
                           EventNearbyService eventNearbyService,
                           EventUploadContextService eventUploadContextService,
                           CurrentUserProvider currentUserProvider) {
        this.eventQueryService = eventQueryService;
        this.eventDetailService = eventDetailService;
        this.eventPostService = eventPostService;
        this.eventNearbyService = eventNearbyService;
        this.eventUploadContextService = eventUploadContextService;
        this.currentUserProvider = currentUserProvider;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<CursorPage<EventSummaryResponse>>> list(
            @RequestParam(required = false) Integer areaCode,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Boolean includeEnded,
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {

        CursorPage<EventSummaryResponse> page =
                eventQueryService.list(areaCode, status, includeEnded, cursor, size);

        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(CACHE_TTL).cachePublic())
                .body(ApiResponse.ok(page, TraceIdFilter.currentTraceId(httpRequest)));
    }

    @GetMapping("/region-summary")
    public ResponseEntity<ApiResponse<List<EventRegionSummaryResponse>>> regionSummary(
            @RequestParam(required = false) Integer newWithinDays,
            HttpServletRequest httpRequest) {

        List<EventRegionSummaryResponse> summaries =
                eventQueryService.regionSummary(newWithinDays);

        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(CACHE_TTL).cachePublic())
                .body(ApiResponse.ok(summaries, TraceIdFilter.currentTraceId(httpRequest)));
    }

    /**
     * 현재 위치 주변의 진행·예정 행사. (EVT-015)
     *
     * <p><b>{@code /events/&#123;eventId&#125;} 보다 먼저 선언한다.</b> 두 경로가 같은 자리에서
     * 갈리는데, 리터럴 경로가 경로 변수보다 우선이라 순서와 무관하게 맞기는 한다. 그래도
     * 사람이 읽을 때 헷갈리지 않도록 위에 둔다.
     *
     * <p>위치마다 결과가 달라 공용 캐시를 두지 않는다.
     */
    @GetMapping("/nearby")
    public ResponseEntity<ApiResponse<List<EventSummaryResponse>>> nearby(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false) Integer radiusM,
            HttpServletRequest httpRequest) {

        List<EventSummaryResponse> events = eventNearbyService.nearby(lat, lng, radiusM);

        return ResponseEntity.ok(ApiResponse.ok(events,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /**
     * 행사 상세. (EVT-011, EVT-012, EVT-013)
     *
     * <p>비회원도 본다. 로그인했으면 뱃지의 획득 여부를 채울 수 있어 사용자를 확인하되,
     * 없다고 막지는 않는다.
     *
     * <p>캐시는 두지 않는다. 목록과 달리 이 응답에는 요청자에 따라 달라지는 값(뱃지 획득 여부)이
     * 섞이므로 공용 캐시에 올리면 남의 상태가 보인다.
     */
    @GetMapping("/{eventId}")
    public ResponseEntity<ApiResponse<EventDetailResponse>> detail(
            @PathVariable String eventId,
            HttpServletRequest httpRequest) {

        long id = ExternalIds.parse(eventId, "evt", ErrorCode.EVENT_NOT_FOUND);
        UUID viewerId = currentUserProvider.optional(httpRequest)
                .map(CurrentUser::userId)
                .orElse(null);

        EventDetailResponse detail = eventDetailService.detail(id, viewerId);

        return ResponseEntity.ok(ApiResponse.ok(detail,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /** 행사에 참여한 공개 게시글. (EVT-014) */
    @GetMapping("/{eventId}/posts")
    public ResponseEntity<ApiResponse<CursorPage<PostSummaryResponse>>> posts(
            @PathVariable String eventId,
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {

        long id = ExternalIds.parse(eventId, "evt", ErrorCode.EVENT_NOT_FOUND);
        Optional<UUID> viewerId = currentUserProvider.optional(httpRequest)
                .map(CurrentUser::userId);

        CursorPage<PostSummaryResponse> page =
                eventPostService.postsOf(id, cursor, size, viewerId);

        return ResponseEntity.ok(ApiResponse.ok(page,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /**
     * 행사 참여 업로드 컨텍스트. (EVT-012, EVT-016 ~ EVT-020)
     *
     * <p>명세가 이 엔드포인트에만 Bearer 를 요구한다(API-EVT-005). SecurityConfig 는
     * {@code GET /api/v1/**} 를 permitAll 로 두므로 컨트롤러에서 {@code require} 로 막는다 —
     * 태그 추천(API-CMU-011)이 같은 이유로 같은 방식을 쓴다. 글을 쓰기 직전에만 부르는
     * 조회라 비회원에게 열어 둘 이유가 없다.
     */
    @GetMapping("/{eventId}/upload-context")
    public ResponseEntity<ApiResponse<EventUploadContextResponse>> uploadContext(
            @PathVariable String eventId,
            HttpServletRequest httpRequest) {

        CurrentUser user = currentUserProvider.require(httpRequest);
        long id = ExternalIds.parse(eventId, "evt", ErrorCode.EVENT_NOT_FOUND);

        EventUploadContextResponse context = eventUploadContextService.of(id, user.userId());

        return ResponseEntity.ok(ApiResponse.ok(context,
                TraceIdFilter.currentTraceId(httpRequest)));
    }
}
