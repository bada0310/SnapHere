package com.snaphere.api.place;

import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class PlaceController {
    private final PlaceService service;
    private final RecentPlaceService recentPlaces;
    private final CurrentUserProvider users;

    public PlaceController(PlaceService service, RecentPlaceService recentPlaces,
                           CurrentUserProvider users) {
        this.service = service;
        this.recentPlaces = recentPlaces;
        this.users = users;
    }

    @GetMapping("/regions")
    ApiResponse<List<PlaceDtos.Region>> regions(HttpServletRequest request) {
        return ok(service.regions(), request);
    }

    @GetMapping("/regions/{areaCode}/sigungu")
    ApiResponse<List<PlaceDtos.Sigungu>> sigungu(@PathVariable int areaCode, HttpServletRequest request) {
        return ok(service.sigungu(areaCode), request);
    }

    @GetMapping("/places")
    ApiResponse<CursorPage<PlaceDtos.PlaceSummary>> places(
            @RequestParam(required = false) Integer areaCode,
            @RequestParam(required = false) Integer sigunguCode,
            @RequestParam(required = false) Integer contentTypeId,
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest request) {
        return ok(service.list(areaCode, sigunguCode, contentTypeId, keyword, cursor, size,
                users.optional(request).orElse(null)), request);
    }

    @GetMapping("/places/nearby")
    ApiResponse<PlaceDtos.NearbyPlaceResult> nearby(@RequestParam double lat, @RequestParam double lng,
                                                     @RequestParam(defaultValue = "500") int radiusM,
                                                     HttpServletRequest request) {
        return ok(service.nearby(lat, lng, radiusM, users.optional(request).orElse(null)), request);
    }

    @GetMapping("/places/{placeId}")
    ApiResponse<PlaceDtos.PlaceDetail> detail(@PathVariable String placeId,
                                               @RequestHeader(name = "Accept-Language", required = false) String language,
                                               HttpServletRequest request) {
        return ok(service.detail(placeId, language, users.optional(request).orElse(null)), request);
    }

    @GetMapping("/places/{placeId}/posts")
    ApiResponse<CursorPage<PlaceDtos.PostSummary>> posts(@PathVariable String placeId,
                                                          @RequestParam(required = false) String cursor,
                                                          @RequestParam(defaultValue = "20") int size,
                                                          HttpServletRequest request) {
        return ok(service.posts(placeId, cursor, size, users.optional(request).orElse(null)), request);
    }

    @PostMapping("/places")
    ResponseEntity<ApiResponse<PlaceDtos.CreatePlaceResult>> create(@Valid @RequestBody PlaceDtos.CreatePlaceRequest body,
                                                                    HttpServletRequest request) {
        var result = service.create(users.require(request), body);
        return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(ok(result, request));
    }

    @PutMapping("/places/{placeId}/bookmark")
    ApiResponse<PlaceDtos.BookmarkResult> bookmark(@PathVariable String placeId,
                                                    HttpServletRequest request) {
        return ok(service.bookmark(users.require(request), placeId), request);
    }

    @DeleteMapping("/places/{placeId}/bookmark")
    ApiResponse<PlaceDtos.BookmarkResult> unbookmark(@PathVariable String placeId,
                                                      HttpServletRequest request) {
        return ok(service.unbookmark(users.require(request), placeId), request);
    }

    @GetMapping("/me/bookmarks")
    ApiResponse<CursorPage<PlaceDtos.PlaceSummary>> bookmarks(@RequestParam(defaultValue = "PLACE") String type,
                                                               @RequestParam(required = false) String cursor,
                                                               @RequestParam(defaultValue = "20") int size,
                                                               HttpServletRequest request) {
        if (!"PLACE".equals(type)) throw new com.snaphere.api.common.error.ApiException(com.snaphere.api.common.error.ErrorCode.COMMON_400);
        return ok(service.bookmarks(users.require(request), cursor, size), request);
    }

    // GET /api/v1/tags/suggestions 는 TagController 가 맡는다 (API-CMU-011).
    // 여기에도 같은 매핑이 있어 두 컨트롤러가 부딪쳤고 애플리케이션이 뜨지 않았다
    // (2026-09-05 로컬 기동 실패, Ambiguous mapping). 명세는 이 엔드포인트 하나가
    // 장소 태그(PLC-021)·행사 고정 태그(EVT-017~020)·타이핑 접두어(CMU-026~028)를
    // 모두 처리하도록 정의하는데, 이쪽 구현은 placeId 만 받아 eventId 를 다루지 못했다.

    @PostMapping("/places/{placeId}/reports")
    ResponseEntity<ApiResponse<PlaceDtos.ReportReceipt>> report(@PathVariable String placeId,
                                                                 @Valid @RequestBody PlaceDtos.CreateReportRequest body,
                                                                 HttpServletRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ok(service.report(users.require(request), placeId, body), request));
    }

    /**
     * API-USER-011 — 최근 본 장소. (VST-006)
     *
     * <p>{@code /me} 는 토큰 주인만 가리킨다. 경로에 사용자 ID 를 두지 않는 이유이기도 하고,
     * 남의 열람 기록을 보여 주면 안 되므로 {@code require} 로 막는다.
     */
    @GetMapping("/me/recent-places")
    ApiResponse<CursorPage<PlaceDtos.PlaceSummary>> myRecentPlaces(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest request) {
        return ok(recentPlaces.recent(users.require(request).userId(), cursor, size), request);
    }

    private static <T> ApiResponse<T> ok(T data, HttpServletRequest request) {
        return ApiResponse.ok(data, TraceIdFilter.currentTraceId(request));
    }
}
