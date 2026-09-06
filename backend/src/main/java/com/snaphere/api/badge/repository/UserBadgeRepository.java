package com.snaphere.api.badge.repository;

import com.snaphere.api.badge.entity.UserBadgeEntity;
import com.snaphere.api.badge.entity.UserBadgeId;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** 획득 기록 조회. (BDG-005, BDG-006, BDG-009, BDG-012) */
public interface UserBadgeRepository extends JpaRepository<UserBadgeEntity, UserBadgeId> {

    /** 수집함 한 화면에 필요한 획득 기록을 한 번에 가져온다 — 뱃지마다 조회하면 N+1 이다. */
    @Query("select ub from UserBadgeEntity ub where ub.id.userId = :userId")
    List<UserBadgeEntity> findAllByUserId(@Param("userId") UUID userId);

    @Query("select ub from UserBadgeEntity ub "
            + "where ub.id.userId = :userId and ub.id.badgeId in :badgeIds")
    List<UserBadgeEntity> findByUserIdAndBadgeIds(@Param("userId") UUID userId,
                                                  @Param("badgeIds") Collection<Long> badgeIds);

    @Query("select ub from UserBadgeEntity ub "
            + "where ub.id.userId = :userId and ub.id.badgeId = :badgeId")
    Optional<UserBadgeEntity> findOne(@Param("userId") UUID userId,
                                      @Param("badgeId") Long badgeId);

    /** 최근 획득 순. 방문 지도 하단 요약이 쓴다 (VST-010). */
    @Query("select ub from UserBadgeEntity ub where ub.id.userId = :userId "
            + "order by ub.earnedAt desc, ub.id.badgeId desc")
    List<UserBadgeEntity> findRecent(@Param("userId") UUID userId, Pageable pageable);
}
