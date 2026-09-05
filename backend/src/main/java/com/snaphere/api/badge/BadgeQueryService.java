package com.snaphere.api.badge;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.badge.dto.BadgeCollectionResponse;
import com.snaphere.api.badge.dto.BadgeDetailResponse;
import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.badge.entity.UserBadgeEntity;
import com.snaphere.api.badge.repository.BadgeRepository;
import com.snaphere.api.badge.repository.UserBadgeRepository;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.post.dto.BadgeSummaryResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * API-BDG-001 · API-BDG-002 — 뱃지 수집함과 상세.
 *
 * <p>기능 명세: 4.4 뱃지 수집함 · 7.1 프로필 &gt; 뱃지 수집함
 * <p>요구사항: BDG-009 ~ BDG-013
 */
@Service
public class BadgeQueryService {

    private final BadgeRepository badges;
    private final UserBadgeRepository userBadges;
    private final BadgeProgress progress;

    public BadgeQueryService(BadgeRepository badges,
                             UserBadgeRepository userBadges,
                             BadgeProgress progress) {
        this.badges = badges;
        this.userBadges = userBadges;
        this.progress = progress;
    }

    /**
     * 수집함. 획득·미획득을 함께 준다. (BDG-009 ~ BDG-012)
     *
     * <p>미획득 뱃지를 빼지 않는 이유는 화면이 회색으로 조건과 함께 보여 주기 때문이다
     * (BDG-010). 그래서 이 응답은 "내가 가진 것" 이 아니라 "모을 수 있는 것 전부" 다.
     *
     * <p>{@code ownerId} 는 수집함 주인이다. 타인 프로필에서도 같은 응답을 쓴다 (BDG-012) —
     * 남의 수집함을 볼 때도 회색 뱃지가 보여야 "이 사람이 무엇을 안 모았는지" 를 알 수 있다.
     */
    @Transactional(readOnly = true)
    public BadgeCollectionResponse collection(UUID ownerId, String category, String language) {
        BadgeType type = BadgeType.parseOrNull(category);

        List<BadgeEntity> rows = type == null
                ? badges.findCollection(ownerId)
                : badges.findCollectionByType(ownerId, type);
        Map<Long, OffsetDateTime> earnedAt = earnedAtByBadgeId(ownerId, rows);

        List<BadgeSummaryResponse> items = new ArrayList<>(rows.size());
        int earnedCount = 0;
        for (BadgeEntity badge : rows) {
            OffsetDateTime at = earnedAt.get(badge.getBadgeId());
            if (at != null) {
                earnedCount++;
            }
            items.add(BadgeSummaryResponse.of(badge, language, at));
        }

        long obtainable = type == null
                ? badges.countObtainable()
                : badges.countObtainableByType(type);
        return BadgeCollectionResponse.of(earnedCount, (int) obtainable, items);
    }

    /**
     * 뱃지 상세. (BDG-013)
     *
     * <p>비회원도 본다. 그때 {@code currentValue} 는 0 이고 {@code earned} 는 false 다 —
     * 조건과 획득자 수를 보여 주는 것이 이 화면의 목적이라 로그인을 요구하지 않는다.
     */
    @Transactional(readOnly = true)
    public BadgeDetailResponse detail(long badgeId, UUID viewerId, String language) {
        BadgeEntity badge = badges.findById(badgeId)
                .orElseThrow(() -> new ApiException(ErrorCode.BADGE_NOT_FOUND,
                        Map.of("badgeId", badgeId)));

        Optional<UserBadgeEntity> earned = viewerId == null
                ? Optional.empty()
                : userBadges.findOne(viewerId, badgeId);

        BadgeCondition condition = badge.condition();

        return new BadgeDetailResponse(
                BadgeSummaryResponse.of(badge, language,
                        earned.map(UserBadgeEntity::getEarnedAt).orElse(null)),
                condition.toMap(),
                progress.currentValue(badge, viewerId),
                condition.known() ? condition.threshold() : 0,
                badge.getEarnedCount(),
                earned.map(UserBadgeEntity::getSourcePostId)
                        .filter(java.util.Objects::nonNull)
                        .map(ExternalIds::post)
                        .orElse(null));
    }

    /** 뱃지마다 조회하면 N+1 이다. 한 번에 받아 맵으로 만든다. */
    private Map<Long, OffsetDateTime> earnedAtByBadgeId(UUID ownerId, List<BadgeEntity> rows) {
        if (ownerId == null || rows.isEmpty()) {
            return Map.of();
        }
        List<Long> badgeIds = rows.stream().map(BadgeEntity::getBadgeId).toList();
        Map<Long, OffsetDateTime> earned = new HashMap<>();
        for (UserBadgeEntity row : userBadges.findByUserIdAndBadgeIds(ownerId, badgeIds)) {
            earned.put(row.getId().getBadgeId(), row.getEarnedAt());
        }
        return earned;
    }
}
