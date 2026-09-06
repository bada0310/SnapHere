package com.snaphere.api.badge;

import com.snaphere.api.badge.entity.BadgeEntity;
import org.springframework.beans.BeanUtils;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.OffsetDateTime;
import java.util.Map;

/** 테스트용 뱃지. 필드가 전부 private 이라 리플렉션으로 채운다. */
public final class BadgeFixtures {

    private BadgeFixtures() {
    }

    public static BadgeEntity badge(long badgeId, BadgeType type, Map<String, Object> condition) {
        return badge(badgeId, type, condition, true, null, null);
    }

    public static BadgeEntity badge(long badgeId, BadgeType type, Map<String, Object> condition,
                                    boolean obtainable, Long eventId, Integer areaCode) {
        BadgeEntity badge = BeanUtils.instantiateClass(BadgeEntity.class);
        ReflectionTestUtils.setField(badge, "badgeId", badgeId);
        ReflectionTestUtils.setField(badge, "code", "CODE_" + badgeId);
        ReflectionTestUtils.setField(badge, "type", type);
        ReflectionTestUtils.setField(badge, "nameKo", "뱃지 " + badgeId);
        ReflectionTestUtils.setField(badge, "nameEn", "Badge " + badgeId);
        ReflectionTestUtils.setField(badge, "description", "조건 설명 " + badgeId);
        ReflectionTestUtils.setField(badge, "iconUrl", "https://cdn/" + badgeId + ".png");
        ReflectionTestUtils.setField(badge, "conditionJson", condition);
        ReflectionTestUtils.setField(badge, "eventId", eventId);
        ReflectionTestUtils.setField(badge, "areaCode", areaCode);
        ReflectionTestUtils.setField(badge, "obtainable", obtainable);
        ReflectionTestUtils.setField(badge, "earnedCount", 0);
        ReflectionTestUtils.setField(badge, "createdAt", OffsetDateTime.now());
        ReflectionTestUtils.setField(badge, "updatedAt", OffsetDateTime.now());
        return badge;
    }

    public static Map<String, Object> condition(String type, Integer threshold) {
        return threshold == null
                ? Map.of("type", type)
                : Map.of("type", type, "threshold", threshold);
    }
}
