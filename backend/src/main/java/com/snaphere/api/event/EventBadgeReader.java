package com.snaphere.api.event;

import com.snaphere.api.post.dto.BadgeSummaryResponse;

import java.util.Optional;
import java.util.UUID;

/**
 * 행사에 걸린 뱃지 조회 포트. (BDG-001, BDG-009, EVT-011)
 *
 * <p>행사 상세와 업로드 컨텍스트가 "참여하면 받는 뱃지" 를 미리 보여 준다 (기능 명세 3.2
 * &gt; 뱃지 미리보기). 그 정보는 {@code badges} 테이블에 있는데 뱃지 도메인(BDG)은 뒤 슬라이스라
 * 아직 테이블이 없다.
 *
 * <p>이벤트 응답이 뱃지 저장 구조를 알지 않도록 여기서 끊는다. {@code BadgeAwarder} 와 같은
 * 방식이다 — 지금은 {@link NoOpEventBadgeReader} 가 빈 값을 주고, 명세상 이 필드는
 * {@code BadgeSummary|null} 이라 계약은 그대로 지켜진다.
 */
public interface EventBadgeReader {

    /**
     * @param viewerId 조회자. 로그인했으면 {@code earned} 를 채울 수 있다. 비회원이면 null
     * @return 행사 뱃지. 걸린 뱃지가 없으면 빈 값
     */
    Optional<BadgeSummaryResponse> findByEventId(long eventId, UUID viewerId);
}
