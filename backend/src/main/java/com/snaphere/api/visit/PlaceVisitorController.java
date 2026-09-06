package com.snaphere.api.visit;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.post.dto.UserSummaryResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * API-VST-004 — 장소 방문자.
 *
 * <p>기능 명세: 6.1 장소 정보 &gt; 방문자 · 랭킹
 * <p>요구사항: VST-005
 *
 * <p>경로 접두어가 {@code /api/v1/places} 라 발자국 컨트롤러와 갈라 둔다. 장소 상세 화면이
 * 쓰는 값이고, 비회원도 볼 수 있다 (명세 Bearer optional).
 *
 * <p>{@code placeId} 는 {@code plc_} 외부 ID 로 받는다. 같은 {@code /places/&#123;placeId&#125;}
 * 자리를 쓰는 형제 엔드포인트(상세·게시글·북마크·신고)가 모두 그 형식이라, 여기만 생숫자를
 * 받으면 클라이언트가 같은 경로 변수에 두 가지 값을 준비해야 한다.
 */
@RestController
@RequestMapping("/api/v1/places/{placeId}")
public class PlaceVisitorController {

    private final PlaceVisitorService placeVisitorService;

    public PlaceVisitorController(PlaceVisitorService placeVisitorService) {
        this.placeVisitorService = placeVisitorService;
    }

    @GetMapping("/visitors")
    public ResponseEntity<ApiResponse<CursorPage<UserSummaryResponse>>> visitors(
            @PathVariable String placeId,
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) Integer size,
            HttpServletRequest httpRequest) {

        long id = ExternalIds.parse(placeId, "plc", ErrorCode.PLACE_NOT_FOUND);
        CursorPage<UserSummaryResponse> page =
                placeVisitorService.ofPlace(id, cursor, size);

        return ResponseEntity.ok(ApiResponse.ok(page,
                TraceIdFilter.currentTraceId(httpRequest)));
    }
}
