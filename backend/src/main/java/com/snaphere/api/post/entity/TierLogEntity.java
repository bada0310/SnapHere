package com.snaphere.api.post.entity;

import com.snaphere.api.post.tier.PhotoSource;
import com.snaphere.api.post.tier.TierDecision;
import com.snaphere.api.post.tier.TierInput;
import com.snaphere.api.post.tier.TierImprovementHint;
import com.snaphere.api.post.tier.TierReason;
import com.snaphere.api.post.tier.TierThresholds;
import com.snaphere.api.post.tier.TrustTier;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 등급 판정 근거 감사 로그. (PST-028)
 *
 * <p>{@code posts} 에 합치지 않는다. 판정 기준(반경·10분·30일)이 바뀌어도 과거 판정을 재현할 수
 * 있도록 판정 결과와 기준값을 스냅샷으로 남긴다. 정확한 촬영 시각과 좌표는 저장하지 않는다. 현재 등급은
 * {@code posts.tier}, 판정 이유는 이 테이블의 최신 1행이다.
 *
 * <p>등급 안내 화면(PST-047)이 이 행을 읽고, 심사에서는 "위치를 어떻게 검증했는가"의 근거가 된다.
 */
@Entity
@Table(name = "tier_logs")
public class TierLogEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "tier_log_id")
    private Long tierLogId;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Enumerated(EnumType.STRING)
    @Column(name = "tier", nullable = false, length = 10)
    private TrustTier tier;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", length = 20)
    private PhotoSource source;

    /** 정확한 촬영 시각은 보관하지 않고 판정 당시의 경과일만 남긴다. */
    @Column(name = "days_since_taken")
    private Long daysSinceTaken;

    @Column(name = "has_taken_coordinate", nullable = false)
    private boolean hasTakenCoordinate;

    /** 촬영 좌표가 없으면 null. 그 자체가 낮음 판정 근거다. (PST-025) */
    @Column(name = "distance_m")
    private Integer distanceM;

    @Column(name = "applied_radius_m", nullable = false)
    private int appliedRadiusM;

    @Column(name = "threshold_high_minutes", nullable = false)
    private int thresholdHighMinutes;

    @Column(name = "threshold_medium_days", nullable = false)
    private int thresholdMediumDays;

    /** {@code TierReason} enum 이름. 문장은 앱이 만든다 (SYS-011). */
    @Column(name = "decided_reason", nullable = false, length = 50)
    private String decidedReason;

    @Column(name = "decided_at", nullable = false)
    private OffsetDateTime decidedAt;

    protected TierLogEntity() {
    }

    /**
     * 원본 좌표·정확한 촬영 시각은 버리고, 판정 결과와 경과일만 옮긴다.
     */
    public static TierLogEntity from(Long postId, TierInput input, TierDecision decision) {
        TierLogEntity log = new TierLogEntity();
        log.postId = postId;
        log.tier = decision.tier();
        log.source = input.source();
        log.daysSinceTaken = decision.daysSinceTaken();
        log.hasTakenCoordinate = decision.hasTakenCoordinate();
        log.distanceM = decision.distanceM();
        log.appliedRadiusM = decision.appliedRadiusM();
        log.thresholdHighMinutes = decision.thresholds().highWithinMinutes();
        log.thresholdMediumDays = decision.thresholds().mediumWithinDays();
        log.decidedReason = decision.reason().name();
        log.decidedAt = decision.decidedAt();
        return log;
    }

    /**
     * 저장된 스냅샷으로 판정을 그대로 재현한다. (PST-047)
     *
     * <p>스냅샷을 남긴 이유가 이것이다 — 등급 안내 화면은 "왜 이 등급인가"와 "어떻게 올리는가"를
     * 함께 보여줘야 하는데(PST-049), 개선 방법은 저장하지 않고 판정 규칙에서 다시 뽑는다.
     * 기준값도 스냅샷에서 오므로 규칙이 바뀐 뒤에도 그때의 결과가 나온다.
     *
     * <p>{@code place_has_coordinate} 는 별도 열로 남기지 않았다. 그 조건이 걸린 경우에만
     * {@code decided_reason} 이 {@code PLACE_HAS_NO_COORDINATE} 이므로 이유에서 되돌린다.
     */
    public TierDecision toDecision() {
        TierReason reason = TierReason.valueOf(decidedReason);
        return new TierDecision(tier, reason, hasTakenCoordinate, distanceM, appliedRadiusM,
                daysSinceTaken, thresholds(), hintsFor(reason), decidedAt);
    }

    private static List<TierImprovementHint> hintsFor(TierReason reason) {
        return switch (reason) {
            case NO_TAKEN_COORDINATE -> List.of(TierImprovementHint.ENABLE_LOCATION_ON_CAMERA,
                    TierImprovementHint.SHOOT_NOW_WITH_CAMERA);
            case OUT_OF_RADIUS, PLACE_HAS_NO_COORDINATE ->
                    List.of(TierImprovementHint.TAKE_CLOSER_TO_PLACE);
            case NO_TAKEN_AT -> List.of(TierImprovementHint.SHOOT_NOW_WITH_CAMERA);
            case TAKEN_TOO_LONG_AGO -> List.of(TierImprovementHint.USE_RECENT_PHOTO,
                    TierImprovementHint.SHOOT_NOW_WITH_CAMERA);
            case ON_SITE_CAMERA -> List.of();
            case RECENT_WITHIN_RADIUS -> List.of(TierImprovementHint.SHOOT_NOW_WITH_CAMERA);
            case LOCAL_VERIFICATION -> List.of();
        };
    }

    public TierThresholds thresholds() {
        return new TierThresholds(thresholdHighMinutes, thresholdMediumDays);
    }

    public Long getTierLogId() {
        return tierLogId;
    }

    public Long getPostId() {
        return postId;
    }

    public TrustTier getTier() {
        return tier;
    }

    public String getDecidedReason() {
        return decidedReason;
    }

    public OffsetDateTime getDecidedAt() {
        return decidedAt;
    }

    public Integer getDistanceM() {
        return distanceM;
    }

    public int getAppliedRadiusM() {
        return appliedRadiusM;
    }
}
