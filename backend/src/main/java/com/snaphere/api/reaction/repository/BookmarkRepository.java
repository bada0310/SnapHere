package com.snaphere.api.reaction.repository;

import com.snaphere.api.reaction.BookmarkTargetType;
import com.snaphere.api.reaction.entity.BookmarkEntity;
import com.snaphere.api.reaction.entity.BookmarkId;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

/** 저장함 조회. (CMU-023, PLC-015) */
public interface BookmarkRepository extends JpaRepository<BookmarkEntity, BookmarkId> {

    /** 목록 응답의 {@code isBookmarked} 를 한 번에 채운다 (SYS-018). */
    @Query("select b.id.targetId from BookmarkEntity b "
            + "where b.id.userId = :userId and b.id.targetType = :targetType "
            + "and b.id.targetId in :targetIds")
    List<Long> findBookmarkedTargetIds(@Param("userId") UUID userId,
                                       @Param("targetType") BookmarkTargetType targetType,
                                       @Param("targetIds") Collection<Long> targetIds);

    /** 마이페이지 저장함. 최근 저장 순이다. */
    List<BookmarkEntity> findByIdUserIdAndIdTargetTypeOrderByCreatedAtDesc(
            UUID userId, BookmarkTargetType targetType, Pageable pageable);

    @Query("""
            select b from BookmarkEntity b where b.id.userId=:userId and b.id.targetType=:targetType
              and (cast(:cursorCreatedAt as timestamp) is null or b.createdAt < :cursorCreatedAt
                   or (b.createdAt = :cursorCreatedAt and b.id.targetId < :cursorTargetId))
            order by b.createdAt desc, b.id.targetId desc
            """)
    List<BookmarkEntity> findPage(@Param("userId") UUID userId,
                                  @Param("targetType") BookmarkTargetType targetType,
                                  @Param("cursorCreatedAt") java.time.OffsetDateTime cursorCreatedAt,
                                  @Param("cursorTargetId") Long cursorTargetId,
                                  Pageable pageable);

    int deleteByIdUserIdAndIdTargetTypeAndIdTargetId(
            UUID userId, BookmarkTargetType targetType, Long targetId);

    void deleteByIdUserId(UUID userId);
}
