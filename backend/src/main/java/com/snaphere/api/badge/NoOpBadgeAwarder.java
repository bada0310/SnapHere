package com.snaphere.api.badge;

import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * {@code user_badges} 테이블이 생기기 전까지 쓰는 구현. 항상 빈 목록.
 *
 * <p>{@code JpaBadgeAwarder} 가 {@code @Primary} 로 우선한다. 이 파일을 남긴 이유는 뱃지
 * 스키마(V15) 없이 게시글 도메인만 띄우는 경우를 막지 않기 위해서다 — {@code @Primary} 로
 * 갈라 두면 중복 빈 오류도 나지 않는다.
 */
@Component
public class NoOpBadgeAwarder implements BadgeAwarder {

    @Override
    public List<AwardedBadge> awardForPost(UUID userId, long postId, long placeId,
                                           Integer areaCode, Long eventId,
                                           boolean eligibleForBadge) {
        return List.of();
    }
}
