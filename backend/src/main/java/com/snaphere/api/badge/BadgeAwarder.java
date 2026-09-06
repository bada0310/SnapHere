package com.snaphere.api.badge;

import java.util.List;
import java.util.UUID;

/**
 * 게시글 등록으로 획득되는 뱃지 판정 포트. (BDG-005, BDG-006)
 *
 * <p>반경 밖 게시글도 게시는 성공하고 뱃지만 주지 않는다 (API 명세 API-PST-003 비고).
 * 그래서 뱃지 판정 결과가 게시글 생성 실패로 이어지는 일은 없다.
 *
 * <p>{@code JpaBadgeAwarder} 가 {@code @Primary} 로 실제 판정을 한다. {@link NoOpBadgeAwarder}
 * 는 뱃지 스키마 없이 게시글 도메인만 띄울 때를 위해 남겨 둔다.
 */
public interface BadgeAwarder {

    /**
     * @param areaCode         장소의 시도. 지역 뱃지(BDG-002) 판정에 쓴다
     * @param eligibleForBadge 등급이 뱃지 대상인가 ({@code TrustTier.eligibleForBadge()})
     * @return 이번 게시글로 새로 획득한 뱃지. 없으면 빈 목록
     */
    List<AwardedBadge> awardForPost(UUID userId, long postId, long placeId, Integer areaCode,
                                    Long eventId, boolean eligibleForBadge);
}
