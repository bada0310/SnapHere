package com.snaphere.api.badge;

/**
 * {@code badges.condition_json} 의 {@code type}. (BDG-007)
 *
 * <p>설계: docs/04-data-design.md &gt; badges.condition_json
 *
 * <p>평가기는 이 네 갈래 분기만 갖고 임계값은 데이터로 읽는다. 그래서 행사·지역 뱃지를
 * 추가하는 일은 배포 없이 데이터 입력으로 끝나고, 배포가 필요한 것은 갈래를 늘릴 때뿐이다.
 */
public enum BadgeConditionType {

    /** 그 행사에 게시글 1개. 대상 행사는 {@code badges.event_id} 다 */
    EVENT_PARTICIPATE,
    /** 그 시도에 게시글 N개. 대상 시도는 {@code badges.area_code} 다 */
    AREA_POST_COUNT,
    /** 게시글을 남긴 시도 수가 N개 (완주) */
    VISITED_AREA_COUNT,
    /** 전체 게시글 N개 */
    TOTAL_POST_COUNT;

    public static BadgeConditionType parseOrNull(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException unknown) {
            return null;
        }
    }
}
