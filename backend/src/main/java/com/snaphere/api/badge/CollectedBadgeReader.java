package com.snaphere.api.badge;

import java.util.List;
import java.util.UUID;

/**
 * 수집한 뱃지 조회 포트. (BDG-009, VST-010)
 *
 * <p>방문 지도 하단에 모은 뱃지를 함께 보여 준다 (VST-010, 결정 2026-09-01 — 지도 + 하단 뱃지
 * 병행). 지도 응답이 뱃지 도메인의 저장 구조를 알지 않도록 여기서 끊는다.
 *
 * <p><b>{@code badges}·{@code user_badges} 테이블은 아직 없다.</b> 뱃지 도메인(BDG)은 다른
 * 담당 범위여서 지금은 {@link NoOpCollectedBadgeReader} 가 빈 목록을 준다. 히트맵이
 * {@code visitCount} 를 0 으로 내보내며 계약을 지켰던 것과 같은 방식이다 (DEC-20260905-007).
 */
public interface CollectedBadgeReader {

    /**
     * @param limit 최대 개수. 지도 하단 요약이라 전부 내리지 않는다
     * @return 획득한 뱃지. 최근 획득 순. 없으면 빈 목록
     */
    List<AwardedBadge> findCollected(UUID userId, int limit);
}
