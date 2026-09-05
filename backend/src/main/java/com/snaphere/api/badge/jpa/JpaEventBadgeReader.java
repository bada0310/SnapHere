package com.snaphere.api.badge.jpa;

import com.snaphere.api.badge.entity.UserBadgeEntity;
import com.snaphere.api.badge.repository.BadgeRepository;
import com.snaphere.api.badge.repository.UserBadgeRepository;
import com.snaphere.api.event.EventBadgeReader;
import com.snaphere.api.post.dto.BadgeSummaryResponse;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

/**
 * 행사에 걸린 뱃지를 {@code badges} 에서 읽는다. (BDG-001, EVT-011)
 *
 * <p>행사 상세와 업로드 컨텍스트의 "참여하면 받는 뱃지" 미리보기가 이 값을 쓴다
 * (기능 명세 3.2 &gt; 뱃지 미리보기).
 *
 * <p><b>{@code @Primary} 로 등록한다.</b> 자리를 잡아 두었던 {@code NoOpEventBadgeReader} 를
 * 지우지 않고 함께 둔다 — 뱃지 스키마가 없는 브랜치에서도 이벤트 도메인이 컴파일·기동되게
 * 했던 장치라 그대로 두는 편이 안전하다. 우선순위만 이쪽으로 넘긴다.
 * {@code JpaTierDecisionLogger} 가 같은 방식을 쓴다.
 *
 * <p>{@code earned} 는 조회자 기준이다. 비회원이면 false 로 나가고, 그건 "안 받았다" 가 아니라
 * "알 수 없다" 에 가깝지만 미리보기 화면에서는 구분할 이유가 없다.
 */
@Component
@Primary
public class JpaEventBadgeReader implements EventBadgeReader {

    private final BadgeRepository badges;
    private final UserBadgeRepository userBadges;

    public JpaEventBadgeReader(BadgeRepository badges, UserBadgeRepository userBadges) {
        this.badges = badges;
        this.userBadges = userBadges;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<BadgeSummaryResponse> findByEventId(long eventId, UUID viewerId) {
        return badges.findByEventId(eventId).map(badge -> {
            OffsetDateTime earnedAt = viewerId == null ? null
                    : userBadges.findOne(viewerId, badge.getBadgeId())
                            .map(UserBadgeEntity::getEarnedAt)
                            .orElse(null);
            return BadgeSummaryResponse.of(badge, "ko", earnedAt);
        });
    }
}
