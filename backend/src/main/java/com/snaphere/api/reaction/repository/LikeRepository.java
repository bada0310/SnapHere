package com.snaphere.api.reaction.repository;

import com.snaphere.api.reaction.LikeTargetType;
import com.snaphere.api.reaction.entity.LikeEntity;
import com.snaphere.api.reaction.entity.LikeId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/** 좋아요 조회. (PST-040) */
public interface LikeRepository extends JpaRepository<LikeEntity, LikeId> {

    /**
     * 목록 응답의 {@code isLiked} 를 한 번에 채운다. 카드마다 exists 를 날리면 N+1 이다 (SYS-018).
     *
     * @return 요청자가 좋아요를 누른 대상 ID 목록
     */
    @Query("select l.id.targetId from LikeEntity l "
            + "where l.id.userId = :userId and l.id.targetType = :targetType "
            + "and l.id.targetId in :targetIds")
    List<Long> findLikedTargetIds(@Param("userId") UUID userId,
                                  @Param("targetType") LikeTargetType targetType,
                                  @Param("targetIds") Collection<Long> targetIds);

    int deleteByIdUserIdAndIdTargetTypeAndIdTargetId(
            UUID userId, LikeTargetType targetType, Long targetId);

    long countByIdUserId(UUID userId);

    void deleteByIdUserId(UUID userId);
}
