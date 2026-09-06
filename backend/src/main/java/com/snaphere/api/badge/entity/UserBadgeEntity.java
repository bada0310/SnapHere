package com.snaphere.api.badge.entity;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 획득 기록. 행의 존재가 곧 획득이다. (BDG-005, BDG-006)
 *
 * <p>미획득을 나타내는 행은 없다. 수집함(BDG-009, BDG-010)은 {@code badges} 를 왼쪽에 두고
 * 이 테이블을 붙여 회색 뱃지를 그린다.
 */
@Entity
@Table(name = "user_badges")
public class UserBadgeEntity {

    @EmbeddedId
    private UserBadgeId id;

    @Column(name = "earned_at", nullable = false)
    private OffsetDateTime earnedAt;

    /** 획득 근거 게시글. 게시글이 물리 삭제되면 null 이 된다 — 획득 사실은 남는다 (PST-039). */
    @Column(name = "source_post_id")
    private Long sourcePostId;

    protected UserBadgeEntity() {
    }

    public static UserBadgeEntity of(UUID userId, Long badgeId, Long sourcePostId,
                                     OffsetDateTime earnedAt) {
        UserBadgeEntity entity = new UserBadgeEntity();
        entity.id = new UserBadgeId(userId, badgeId);
        entity.sourcePostId = sourcePostId;
        entity.earnedAt = earnedAt;
        return entity;
    }

    public UserBadgeId getId() {
        return id;
    }

    public OffsetDateTime getEarnedAt() {
        return earnedAt;
    }

    public Long getSourcePostId() {
        return sourcePostId;
    }
}
