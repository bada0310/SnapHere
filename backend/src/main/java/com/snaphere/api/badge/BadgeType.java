package com.snaphere.api.badge;

/**
 * 뱃지 분류. 수집함이 이 값으로 탭을 나눈다. (BDG-011)
 *
 * <p>명세: 4. 응답 스키마 &gt; BadgeSummary.type
 */
public enum BadgeType {

    /** 행사 참여 (BDG-001) */
    EVENT,
    /** 지역 (BDG-002) */
    AREA,
    /** 완주 (BDG-003) */
    COMPLETION,
    /** 기록 (BDG-004) */
    RECORD;

    /** {@code category=ALL} 이거나 알 수 없는 값이면 null — 전체 조회로 본다. */
    public static BadgeType parseOrNull(String raw) {
        if (raw == null || raw.isBlank() || "ALL".equalsIgnoreCase(raw.trim())) {
            return null;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException unknown) {
            return null;
        }
    }
}
