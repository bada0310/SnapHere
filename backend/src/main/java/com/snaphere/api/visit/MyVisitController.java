package com.snaphere.api.visit;

import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.visit.dto.VisitMapResponse;
import com.snaphere.api.visit.dto.VisitResponse;
import com.snaphere.api.visit.dto.VisitStatsResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * API-VST-001 · API-VST-002 · API-VST-003 — 내 방문 기록·방문 통계·방문 지도.
 *
 * <p>기능 명세: 4.3 방문 지도 &gt; 진행률 표시 (방문 기록 목록은 화면 정의에 없다)
 * <p>요구사항: VST-003, VST-004, VST-007, VST-008, VST-009, VST-010
 *
 * <p>{@code GET /api/v1/**} 는 permitAll 이지만 이 조회는 남의 발자국을 보여 주면 안 되므로
 * 컨트롤러에서 {@code require} 로 막는다. 경로에 사용자 ID 를 두지 않는 것도 그래서다 —
 * {@code /me} 는 토큰 주인만 가리킨다.
 */
@RestController
@RequestMapping("/api/v1/me")
public class MyVisitController {

    private final VisitQueryService visitQueryService;
    private final VisitStatsService visitStatsService;
    private final VisitMapService visitMapService;
    private final CurrentUserProvider currentUserProvider;

    public MyVisitController(VisitQueryService visitQueryService,
                             VisitStatsService visitStatsService,
                             VisitMapService visitMapService,
                             CurrentUserProvider currentUserProvider) {
        this.visitQueryService = visitQueryService;
        this.visitStatsService = visitStatsService;
        this.visitMapService = visitMapService;
        this.currentUserProvider = currentUserProvider;
    }

    @GetMapping("/visits")
    public ResponseEntity<ApiResponse<CursorPage<VisitResponse>>> myVisits(
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {

        CurrentUser user = currentUserProvider.require(httpRequest);
        CursorPage<VisitResponse> page =
                visitQueryService.myVisits(user.userId(), cursor, size);

        return ResponseEntity.ok(ApiResponse.ok(page,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /** 17개 시도 진행률과 지역별 분포. (VST-004, VST-008, VST-009) */
    @GetMapping("/visit-stats")
    public ResponseEntity<ApiResponse<VisitStatsResponse>> visitStats(HttpServletRequest httpRequest) {
        CurrentUser user = currentUserProvider.require(httpRequest);
        VisitStatsResponse stats = visitStatsService.of(user.userId());

        return ResponseEntity.ok(ApiResponse.ok(stats,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /** 마커·시도 채색·진행률·수집 뱃지를 한 번에. (VST-007, VST-008, VST-009, VST-010) */
    @GetMapping("/visit-map")
    public ResponseEntity<ApiResponse<VisitMapResponse>> visitMap(HttpServletRequest httpRequest) {
        CurrentUser user = currentUserProvider.require(httpRequest);
        VisitMapResponse map = visitMapService.of(user.userId());

        return ResponseEntity.ok(ApiResponse.ok(map,
                TraceIdFilter.currentTraceId(httpRequest)));
    }
}
