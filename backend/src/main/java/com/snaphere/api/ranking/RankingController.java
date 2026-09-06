package com.snaphere.api.ranking;

import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class RankingController {
    private final RankingService rankings;
    private final CurrentUserProvider users;

    public RankingController(RankingService rankings, CurrentUserProvider users) {
        this.rankings = rankings;
        this.users = users;
    }

    @GetMapping("/rankings/places")
    ApiResponse<CursorPage<RankingDtos.RankingEntry>> places(
            @RequestParam(required = false) String scope,
            @RequestParam(required = false) Integer areaCode,
            @RequestParam(defaultValue = "WEEKLY") String period,
            @RequestParam(required = false) String theme,
            @RequestParam(defaultValue = "ALL") String placeType,
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int size,
            HttpServletRequest request) {
        return ok(rankings.places(scope, areaCode, period, theme, placeType, cursor, size,
                users.optional(request).orElse(null)), request);
    }

    @GetMapping("/recommendations/places")
    ApiResponse<List<RankingDtos.Recommendation>> recommendations(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false) Integer areaCode,
            @RequestParam(defaultValue = "10") int limit,
            HttpServletRequest request) {
        return ok(rankings.recommendations(lat, lng, areaCode, limit,
                users.optional(request).orElse(null)), request);
    }

    private static <T> ApiResponse<T> ok(T data, HttpServletRequest request) {
        return ApiResponse.ok(data, TraceIdFilter.currentTraceId(request));
    }
}
