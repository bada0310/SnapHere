package com.snaphere.api.event;

import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.event.dto.EventRegionSummaryResponse;
import com.snaphere.api.event.dto.EventSummaryResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.List;

/**
 * API-EVT-001 · API-EVT-006 — 이벤트 홈. (EVT-002, EVT-005 ~ EVT-010)
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

    public EventController(EventQueryService eventQueryService) {
        this.eventQueryService = eventQueryService;
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
}
