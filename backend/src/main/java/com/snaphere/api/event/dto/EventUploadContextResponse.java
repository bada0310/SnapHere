package com.snaphere.api.event.dto;

import com.snaphere.api.post.dto.BadgeSummaryResponse;
import com.snaphere.api.post.dto.PlaceSummaryResponse;
import com.snaphere.api.post.dto.TagSummaryResponse;

import java.util.List;

/**
 * 명세: 4. 응답 스키마 &gt; EventUploadContext. (EVT-012, EVT-016 ~ EVT-020)
 *
 * <p>기능 명세: 3.3 행사 참여 업로드
 *
 * <p>업로드 화면이 열리는 순간 필요한 것을 모두 준다 — 프리필할 장소(EVT-016), 뗄 수 없는
 * 고정 태그(EVT-017, EVT-018), 적용 인증 반경, 받게 될 뱃지.
 *
 * <p>{@code freeTagSlots} 는 명세에 없는 계산 필드다. 사용자가 직접 넣을 수 있는 태그 수를
 * 앱이 빼기로 구하지 않게 하려고 서버가 정한다 (EVT-020) — 고정 태그 개수가 행사마다 다를 수
 * 있는데 앱에 "10 - 2" 를 하드코딩하면 그때 어긋난다.
 */
public record EventUploadContextResponse(
        EventSummaryResponse event,
        PlaceSummaryResponse place,
        List<TagSummaryResponse> fixedTags,
        int verifyRadiusM,
        BadgeSummaryResponse badge,
        int freeTagSlots
) {
}
