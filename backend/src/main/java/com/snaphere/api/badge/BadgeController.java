package com.snaphere.api.badge;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.badge.dto.BadgeCollectionResponse;
import com.snaphere.api.badge.dto.BadgeDetailResponse;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.TraceIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * API-BDG-001 · API-BDG-002 — 뱃지 수집함과 상세. (BDG-009 ~ BDG-013)
 *
 * <p>둘 다 비회원이 볼 수 있다. 수집함은 남의 프로필에서도 열리고(BDG-012), 상세는 조건과
 * 획득자 수를 보여 주는 화면이라 로그인을 요구할 이유가 없다.
 */
@RestController
@RequestMapping("/api/v1")
public class BadgeController {

    private final BadgeQueryService badgeQueryService;
    private final CurrentUserProvider currentUserProvider;

    public BadgeController(BadgeQueryService badgeQueryService,
                           CurrentUserProvider currentUserProvider) {
        this.badgeQueryService = badgeQueryService;
        this.currentUserProvider = currentUserProvider;
    }

    /**
     * 사용자 뱃지 수집함. (BDG-009 ~ BDG-012)
     *
     * <p>{@code userId} 에 {@code me} 를 쓰면 토큰 주인의 수집함이다. 앱이 자기 ID 를 들고
     * 다니지 않아도 되게 하려는 것이고, 로그인하지 않은 채 {@code me} 를 부르면 401 이다.
     */
    @GetMapping("/users/{userId}/badges")
    public ResponseEntity<ApiResponse<BadgeCollectionResponse>> collection(
            @PathVariable String userId,
            @RequestParam(required = false) String category,
            @RequestHeader(name = "Accept-Language", required = false) String language,
            HttpServletRequest httpRequest) {

        UUID ownerId = resolveOwner(userId, httpRequest);
        BadgeCollectionResponse collection =
                badgeQueryService.collection(ownerId, category, languageOf(language));

        return ResponseEntity.ok(ApiResponse.ok(collection,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    /** 뱃지 상세. (BDG-013) */
    @GetMapping("/badges/{badgeId}")
    public ResponseEntity<ApiResponse<BadgeDetailResponse>> detail(
            @PathVariable String badgeId,
            @RequestHeader(name = "Accept-Language", required = false) String language,
            HttpServletRequest httpRequest) {

        long id = ExternalIds.parse(badgeId, "bdg", ErrorCode.BADGE_NOT_FOUND);
        UUID viewerId = currentUserProvider.optional(httpRequest)
                .map(CurrentUser::userId)
                .orElse(null);

        BadgeDetailResponse detail = badgeQueryService.detail(id, viewerId, languageOf(language));

        return ResponseEntity.ok(ApiResponse.ok(detail,
                TraceIdFilter.currentTraceId(httpRequest)));
    }

    private UUID resolveOwner(String userId, HttpServletRequest request) {
        if ("me".equalsIgnoreCase(userId)) {
            CurrentUser user = currentUserProvider.require(request);
            return user.userId();
        }
        return parseUserId(userId);
    }

    /**
     * 사용자 ID 는 uuid 문자열이다. 다른 도메인의 {@code usr_} 외부 ID 와 달리 users.id 가
     * 애초에 uuid 라 숨길 것이 없다 — 게시글 응답의 {@code author.userId} 도 uuid 를 그대로 준다.
     */
    private static UUID parseUserId(String userId) {
        try {
            return UUID.fromString(userId);
        } catch (IllegalArgumentException malformed) {
            throw new com.snaphere.api.common.error.ApiException(ErrorCode.USER_NOT_FOUND);
        }
    }

    /** {@code ko-KR} → {@code ko}. 없으면 한국어로 본다. */
    private static String languageOf(String acceptLanguage) {
        if (acceptLanguage == null || acceptLanguage.isBlank()) {
            return "ko";
        }
        String first = acceptLanguage.split(",")[0].trim();
        return first.length() >= 2 ? first.substring(0, 2).toLowerCase() : "ko";
    }
}
