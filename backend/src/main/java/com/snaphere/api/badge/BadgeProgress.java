package com.snaphere.api.badge;

import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.post.repository.PostRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * 뱃지 조건의 현재 진행값을 센다. (BDG-007)
 *
 * <p>수집함 상세(BDG-013)와 지급 판정(BDG-005)이 같은 계산을 써야 한다. 두 곳에 따로 두면
 * "상세에서는 5/5인데 뱃지가 안 나온다" 같은 어긋남이 생긴다.
 *
 * <p>{@code condition_json} 의 갈래만 분기하고 임계값은 데이터로 읽는다 — 행사·지역 뱃지
 * 추가는 배포 없이 데이터 입력으로 끝난다.
 */
@Component
public class BadgeProgress {

    private final PostRepository posts;

    public BadgeProgress(PostRepository posts) {
        this.posts = posts;
    }

    /**
     * @param userId 비회원이면 null — 진행값은 0 이다
     * @return 현재 진행값. 조건을 해석할 수 없으면 0
     */
    @Transactional(readOnly = true)
    public int currentValue(BadgeEntity badge, UUID userId) {
        if (userId == null) {
            return 0;
        }
        BadgeCondition condition = badge.condition();
        if (!condition.known()) {
            return 0;
        }
        return switch (condition.type()) {
            case EVENT_PARTICIPATE -> badge.getEventId() == null
                    ? 0
                    : (int) posts.countEligibleByUserAndEvent(userId, badge.getEventId());
            case AREA_POST_COUNT -> badge.getAreaCode() == null
                    ? 0
                    : (int) posts.countEligibleByUserAndArea(userId, badge.getAreaCode());
            case VISITED_AREA_COUNT -> (int) posts.countDistinctAreasByUser(userId);
            case TOTAL_POST_COUNT -> (int) posts.countEligibleByUser(userId);
        };
    }

    /** 조건을 채웠는가. 대상이 지정되지 않은 뱃지(행사·지역 ID 가 빈 경우)는 절대 지급되지 않는다. */
    @Transactional(readOnly = true)
    public boolean satisfied(BadgeEntity badge, UUID userId) {
        BadgeCondition condition = badge.condition();
        if (!condition.known()) {
            return false;
        }
        return currentValue(badge, userId) >= condition.threshold();
    }
}
