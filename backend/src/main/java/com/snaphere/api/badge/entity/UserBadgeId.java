package com.snaphere.api.badge.entity;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/** {@code user_badges} 복합 키. 이 조합의 유일성이 곧 중복 지급 방지다 (BDG-006). */
public class UserBadgeId implements Serializable {

    private UUID userId;
    private Long badgeId;

    protected UserBadgeId() {
    }

    public UserBadgeId(UUID userId, Long badgeId) {
        this.userId = userId;
        this.badgeId = badgeId;
    }

    public UUID getUserId() {
        return userId;
    }

    public Long getBadgeId() {
        return badgeId;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof UserBadgeId that)) {
            return false;
        }
        return Objects.equals(userId, that.userId) && Objects.equals(badgeId, that.badgeId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, badgeId);
    }
}
