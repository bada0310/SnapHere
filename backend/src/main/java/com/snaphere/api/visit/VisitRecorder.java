package com.snaphere.api.visit;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 방문 자동 기록 포트. (VST-001, VST-002)
 *
 * <p>높음·보통 등급 게시글을 올리면 방문이 기록되고, 같은 날 같은 장소는 한 번만 기록된다.
 * 중복 차단은 {@code visits} 테이블의 유니크 제약으로 보장한다 (VST-002) — 애플리케이션에서
 * 조회 후 삽입하면 동시 요청에 두 번 들어간다.
 */
public interface VisitRecorder {

    /**
     * @param postId         방문의 근거 게시글. 방문 기록 응답이 이 값을 그대로 노출한다 (VST-003)
     * @param countsForVisit 등급이 방문으로 인정되는가 ({@code TrustTier.countsForVisit()})
     * @return 이번 호출로 방문이 새로 기록되었으면 true. 같은 날 이미 기록됐으면 false
     */
    boolean recordIfEligible(UUID userId, long placeId, long postId,
                             boolean countsForVisit, OffsetDateTime at);
}
