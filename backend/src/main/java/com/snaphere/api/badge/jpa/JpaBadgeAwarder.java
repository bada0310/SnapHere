package com.snaphere.api.badge.jpa;

import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.BadgeAwarder;
import com.snaphere.api.badge.BadgeCondition;
import com.snaphere.api.badge.BadgeConditionType;
import com.snaphere.api.badge.BadgeProgress;
import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.badge.repository.BadgeRepository;
import com.snaphere.api.badge.repository.UserBadgeRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 게시글 등록으로 획득되는 뱃지를 판정하고 지급한다. (BDG-001 ~ BDG-006)
 *
 * <p>게시글 생성 트랜잭션 안에서 돈다. 게시글이 롤백되면 뱃지도 함께 되돌아가야 하고,
 * 응답의 {@code earnedBadges} 가 이 자리에서 채워져야 하기 때문이다(API-PST-003).
 * BDG-005 의 "비동기 지급" 은 게시글 저장을 막지 않는다는 뜻으로 읽었다 — 실제로 판정에
 * 드는 것은 카운트 쿼리 몇 번이고, 별도 스레드로 빼면 응답에 담을 수 없다.
 *
 * <p><b>낮음 등급이면 아무것도 하지 않는다</b> (PST-026, EVT-023). 반경 밖에서 올린 글로
 * 뱃지를 모을 수 있으면 현장 인증이라는 전제가 무너진다. 게시 자체는 이미 성공한 뒤다.
 */
@Component
@Primary
public class JpaBadgeAwarder implements BadgeAwarder {

    private static final Logger log = LoggerFactory.getLogger(JpaBadgeAwarder.class);
    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final BadgeRepository badges;
    private final UserBadgeRepository userBadges;
    private final BadgeProgress progress;

    public JpaBadgeAwarder(BadgeRepository badges,
                           UserBadgeRepository userBadges,
                           BadgeProgress progress) {
        this.badges = badges;
        this.userBadges = userBadges;
        this.progress = progress;
    }

    @Override
    public List<AwardedBadge> awardForPost(UUID userId, long postId, long placeId,
                                           Integer areaCode, Long eventId,
                                           boolean eligibleForBadge) {
        if (!eligibleForBadge) {
            return List.of();
        }

        OffsetDateTime now = OffsetDateTime.now(KST);
        // 수집함 상세와 같은 계산을 쓴다. 한 판정 안에서 같은 집계를 다시 세지 않는다.
        BadgeProgress.Session session = progress.session(userId);
        List<AwardedBadge> awarded = new ArrayList<>();

        for (BadgeEntity badge : badges.findAwardCandidates(userId)) {
            if (!relevant(badge, areaCode, eventId)) {
                continue;
            }
            if (!session.satisfied(badge)) {
                continue;
            }
            // 중복 방지는 여기가 아니라 user_badges PK 가 한다 (BDG-006).
            // 후보 조회로 걸러도 같은 사용자의 동시 요청은 둘 다 통과한다.
            if (userBadges.insertIfAbsent(userId, badge.getBadgeId(), now, postId) == 0) {
                continue;
            }
            badges.addEarnedCount(badge.getBadgeId(), 1, now);
            awarded.add(new AwardedBadge(badge.getBadgeId(), badge.getType().name(),
                    badge.getNameKo(), badge.getDescription(), badge.getIconUrl(), now));
            log.debug("뱃지 지급 userId={} badgeId={} postId={}", userId, badge.getBadgeId(), postId);
        }
        return awarded;
    }

    /**
     * 이번 게시글과 상관있는 뱃지만 평가한다.
     *
     * <p>행사·지역 뱃지는 대상이 정해져 있어 다른 행사·지역의 글로는 절대 진행되지 않는다.
     * 미리 걸러 카운트 쿼리를 아낀다 — 완주·기록 뱃지는 모든 글이 영향을 주므로 그대로 본다.
     */
    private static boolean relevant(BadgeEntity badge, Integer areaCode, Long eventId) {
        BadgeCondition condition = badge.condition();
        if (!condition.known()) {
            return false;
        }
        if (condition.type() == BadgeConditionType.EVENT_PARTICIPATE) {
            return badge.getEventId() != null && badge.getEventId().equals(eventId);
        }
        if (condition.type() == BadgeConditionType.AREA_POST_COUNT) {
            return badge.getAreaCode() != null && badge.getAreaCode().equals(areaCode);
        }
        return true;
    }

}
