package com.snaphere.api.badge.repository;

import com.snaphere.api.badge.entity.UserBadgeEntity;
import com.snaphere.api.badge.entity.UserBadgeId;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
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

    /**
     * 중복 지급을 DB 에 맡기고 지급한다. (BDG-006)
     *
     * <p>조회 후 삽입하면 같은 사용자가 동시에 두 번 요청할 때 두 건이 들어간다. PK 가
     * {@code (user_id, badge_id)} 라 {@code on conflict do nothing} 이 그 경합을 흡수한다.
     *
     * <p>{@code save()} 를 쓰지 않는 이유: {@code @EmbeddedId} 엔터티에 대해 Spring Data 는
     * "PK 가 채워져 있으면 기존 행" 으로 보고 merge 를 시도한다. 그러면 이미 받은 뱃지의
     * {@code earned_at} 이 새 값으로 덮여 획득 시각이 사라진다.
     *
     * @return 새로 지급했으면 1, 이미 갖고 있었으면 0
     */
    @Modifying
    @Query(value = """
            insert into user_badges (user_id, badge_id, earned_at, source_post_id)
            values (:userId, :badgeId, :earnedAt, :sourcePostId)
            on conflict do nothing
            """, nativeQuery = true)
    int insertIfAbsent(@Param("userId") UUID userId,
                       @Param("badgeId") Long badgeId,
                       @Param("earnedAt") OffsetDateTime earnedAt,
                       @Param("sourcePostId") Long sourcePostId);

    /** 최근 획득 순. 방문 지도 하단 요약이 쓴다 (VST-010). */
    @Query("select ub from UserBadgeEntity ub where ub.id.userId = :userId "
            + "order by ub.earnedAt desc, ub.id.badgeId desc")
    List<UserBadgeEntity> findRecent(@Param("userId") UUID userId, Pageable pageable);
}
