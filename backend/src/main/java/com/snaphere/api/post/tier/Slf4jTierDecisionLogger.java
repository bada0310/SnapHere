package com.snaphere.api.post.tier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * 임시 구현. 판정 근거를 애플리케이션 로그에 남긴다.
 *
 * <p><b>{@code tier_logs} 테이블이 생기면 JPA 구현으로 교체한다.</b>
 * 그때까지도 판정 입력·결과가 유실되지 않게 하려고 둔다 (PST-028).
 */
@Component
public class Slf4jTierDecisionLogger implements TierDecisionLogger {

    private static final Logger log = LoggerFactory.getLogger("tier-decision");

    @Override
    public void record(Long postId, UUID userId, long placeId, Long eventId,
                       TierInput input, TierDecision decision) {
        log.info("tier={} reason={} postId={} userId={} placeId={} eventId={} "
                        + "source={} hasTakenAt={} hasCoord={} distanceM={} radiusM={} daysSinceTaken={} "
                        + "thresholdHighMin={} thresholdMediumDays={} decidedAt={}",
                decision.tier(), decision.reason(), postId, userId, placeId, eventId,
                input.source(), input.takenAt() != null,
                decision.hasTakenCoordinate(), decision.distanceM(), decision.appliedRadiusM(),
                decision.daysSinceTaken(), decision.thresholds().highWithinMinutes(),
                decision.thresholds().mediumWithinDays(), decision.decidedAt());
    }
}
