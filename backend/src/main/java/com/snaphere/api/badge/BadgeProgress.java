package com.snaphere.api.badge;

import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.post.repository.PostRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 뱃지 조건의 현재 진행값을 센다. (BDG-007)
 *
 * <p>수집함 상세(BDG-013)와 지급 판정(BDG-005)이 <b>같은 계산</b>을 써야 한다. 두 곳에 따로
 * 두면 "상세에서는 5/5인데 뱃지가 안 나온다" 같은 어긋남이 생긴다.
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

    /** 뱃지 하나만 볼 때. 상세 화면이 쓴다. */
    @Transactional(readOnly = true)
    public int currentValue(BadgeEntity badge, UUID userId) {
        return session(userId).currentValue(badge);
    }

    /** 조건을 채웠는가. */
    @Transactional(readOnly = true)
    public boolean satisfied(BadgeEntity badge, UUID userId) {
        return session(userId).satisfied(badge);
    }

    /**
     * 여러 뱃지를 연달아 볼 때 쓰는 계산 묶음.
     *
     * <p>지역 뱃지가 임계값만 다르게 여러 개 걸려 있는 것은 흔하다(2개·5개·10개). 뱃지마다
     * 카운트 쿼리를 돌리면 게시글 하나 올릴 때 수십 번이 나간다. 한 번의 판정 안에서는 같은
     * 집계를 다시 세지 않는다.
     */
    public Session session(UUID userId) {
        return new Session(posts, userId);
    }

    /** 한 요청 안에서만 산다. 값을 캐시하므로 재사용하면 낡은 수를 본다. */
    public static final class Session {

        private final PostRepository posts;
        private final UUID userId;
        private final Map<Integer, Integer> areaPosts = new HashMap<>();
        private final Map<Long, Integer> eventPosts = new HashMap<>();
        private Integer totalPosts;
        private Integer distinctAreas;

        private Session(PostRepository posts, UUID userId) {
            this.posts = posts;
            this.userId = userId;
        }

        /**
         * @return 현재 진행값. 비회원이거나 조건을 해석할 수 없으면 0
         */
        public int currentValue(BadgeEntity badge) {
            if (userId == null) {
                return 0;
            }
            BadgeCondition condition = badge.condition();
            if (!condition.known()) {
                return 0;
            }
            return switch (condition.type()) {
                case EVENT_PARTICIPATE -> badge.getEventId() == null
                        ? 0 : eventPosts(badge.getEventId());
                case AREA_POST_COUNT -> badge.getAreaCode() == null
                        ? 0 : areaPosts(badge.getAreaCode());
                case VISITED_AREA_COUNT -> distinctAreas();
                case TOTAL_POST_COUNT -> totalPosts();
            };
        }

        /**
         * 조건을 채웠는가.
         *
         * <p>대상이 지정되지 않은 뱃지(행사·지역 ID 가 빈 경우)는 진행값이 0 이라 자연히
         * 지급되지 않는다. 조건을 해석할 수 없는 뱃지도 마찬가지다.
         */
        public boolean satisfied(BadgeEntity badge) {
            BadgeCondition condition = badge.condition();
            return condition.known() && currentValue(badge) >= condition.threshold();
        }

        private int totalPosts() {
            if (totalPosts == null) {
                totalPosts = (int) posts.countEligibleByUser(userId);
            }
            return totalPosts;
        }

        private int distinctAreas() {
            if (distinctAreas == null) {
                distinctAreas = (int) posts.countDistinctAreasByUser(userId);
            }
            return distinctAreas;
        }

        private int areaPosts(Integer areaCode) {
            return areaPosts.computeIfAbsent(areaCode,
                    code -> (int) posts.countEligibleByUserAndArea(userId, code));
        }

        private int eventPosts(Long eventId) {
            return eventPosts.computeIfAbsent(eventId,
                    id -> (int) posts.countEligibleByUserAndEvent(userId, id));
        }
    }
}
