package com.snaphere.api.badge.repository;

import com.snaphere.api.badge.BadgeType;
import com.snaphere.api.badge.entity.BadgeEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** 뱃지 정의 조회. (BDG-009 ~ BDG-013) */
public interface BadgeRepository extends JpaRepository<BadgeEntity, Long> {

    /**
     * 수집함에 보일 뱃지. (BDG-009, BDG-010, BDG-011)
     *
     * <p>{@code is_obtainable = false} 인 뱃지도 <b>내가 이미 받았다면</b> 보여야 한다. 기간이
     * 끝난 행사 뱃지가 수집함에서 사라지면 모은 기록이 없어진 것처럼 보인다. 진행률 분모에서만
     * 빠진다 (docs/04-data-design.md).
     *
     * <p><b>분류 필터를 {@code :type is null} 로 합치지 않고 메서드를 나눴다.</b> PostgreSQL 은
     * {@code IS NULL} 에만 쓰인 파라미터의 타입을 추론하지 못해 준비 단계에서 거절하는 경우가
     * 있다 — 게시글 피드와 시도별 요약이 실제로 그 문제로 500 이었다. 조건이 하나뿐이라
     * 나눠도 커서 로직처럼 갈라질 여지가 없다.
     */
    @Query("""
            select b from BadgeEntity b
             where b.obtainable = true
                or exists (select ub.id.badgeId from UserBadgeEntity ub
                            where ub.id.badgeId = b.badgeId and ub.id.userId = :userId)
             order by b.type asc, b.badgeId asc
            """)
    List<BadgeEntity> findCollection(@Param("userId") UUID userId);

    /** 분류 탭이 선택된 수집함. (BDG-011) */
    @Query("""
            select b from BadgeEntity b
             where b.type = :type
               and (b.obtainable = true
                    or exists (select ub.id.badgeId from UserBadgeEntity ub
                                where ub.id.badgeId = b.badgeId and ub.id.userId = :userId))
             order by b.badgeId asc
            """)
    List<BadgeEntity> findCollectionByType(@Param("userId") UUID userId,
                                           @Param("type") BadgeType type);

    /** 진행률 분모. 지금 획득 가능한 전체 뱃지 수다 (BDG-009). */
    @Query("select count(b) from BadgeEntity b where b.obtainable = true")
    long countObtainable();

    @Query("select count(b) from BadgeEntity b where b.obtainable = true and b.type = :type")
    long countObtainableByType(@Param("type") BadgeType type);

    /**
     * 아직 못 받은 획득 가능 뱃지. 지급 판정의 후보다. (BDG-005)
     *
     * <p>이미 받은 뱃지를 후보에서 빼는 것은 최적화일 뿐 중복 방지가 아니다. 방지는
     * {@code user_badges} PK 가 한다 (BDG-006) — 여기서 걸러도 동시 요청은 통과한다.
     */
    @Query("""
            select b from BadgeEntity b
             where b.obtainable = true
               and not exists (select ub.id.badgeId from UserBadgeEntity ub
                                where ub.id.badgeId = b.badgeId and ub.id.userId = :userId)
             order by b.badgeId asc
            """)
    List<BadgeEntity> findAwardCandidates(@Param("userId") UUID userId);

    Optional<BadgeEntity> findByEventId(Long eventId);

    /** 획득자 수 카운터. BDG-013 이 이 값을 보여 준다 — 조회 때 COUNT 를 돌리지 않는다. */
    @Modifying
    @Query("update BadgeEntity b set b.earnedCount = b.earnedCount + :delta, b.updatedAt = :now "
            + "where b.badgeId = :badgeId")
    int addEarnedCount(@Param("badgeId") Long badgeId,
                       @Param("delta") int delta,
                       @Param("now") OffsetDateTime now);
}
