package com.snaphere.api.badge;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 해석된 획득 조건. (BDG-007)
 *
 * <p>{@code condition_json} 을 그대로 응답에 흘리지 않고 이 형태로 한 번 거른다. 저장된 JSON 에
 * 오타나 낯선 키가 있어도 앱은 {@code type}·{@code threshold} 두 개만 보면 되게 하려는 것이다.
 *
 * @param threshold 목표값. {@code EVENT_PARTICIPATE} 는 게시글 1개가 곧 조건이라 1 이다
 */
public record BadgeCondition(BadgeConditionType type, int threshold) {

    /** 알 수 없는 조건. 평가기는 이걸 만나면 절대 지급하지 않는다. */
    public static final BadgeCondition UNKNOWN = new BadgeCondition(null, Integer.MAX_VALUE);

    public static BadgeCondition of(BadgeConditionType type, Integer threshold) {
        if (type == null) {
            return UNKNOWN;
        }
        if (type == BadgeConditionType.EVENT_PARTICIPATE) {
            return new BadgeCondition(type, 1);
        }
        // 임계값이 없거나 0 이하인 조건은 "아무나 받는 뱃지" 가 되므로 지급하지 않는다.
        if (threshold == null || threshold <= 0) {
            return UNKNOWN;
        }
        return new BadgeCondition(type, threshold);
    }

    public boolean known() {
        return type != null;
    }

    /** 명세 BadgeDetail.condition — 해석된 조건을 객체로 준다. */
    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("type", type == null ? "UNKNOWN" : type.name());
        map.put("threshold", known() ? threshold : null);
        return map;
    }
}
