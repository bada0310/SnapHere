package com.snaphere.api.badge;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** 뱃지 조건 해석 — BDG-007 */
class BadgeConditionTest {

    @Test
    @DisplayName("행사 참여는 게시글 1개가 곧 조건이다")
    void 행사_참여() {
        BadgeCondition condition = BadgeCondition.of(BadgeConditionType.EVENT_PARTICIPATE, null);

        assertThat(condition.known()).isTrue();
        assertThat(condition.threshold()).isEqualTo(1);
    }

    @Test
    @DisplayName("임계값은 데이터로 읽는다 — 갈래를 늘릴 때만 배포가 필요하다")
    void 임계값() {
        assertThat(BadgeCondition.of(BadgeConditionType.AREA_POST_COUNT, 5).threshold())
                .isEqualTo(5);
        assertThat(BadgeCondition.of(BadgeConditionType.VISITED_AREA_COUNT, 17).threshold())
                .isEqualTo(17);
    }

    @Test
    @DisplayName("모르는 갈래는 UNKNOWN — 그 뱃지만 지급되지 않는다")
    void 모르는_갈래() {
        assertThat(BadgeCondition.of(null, 5).known()).isFalse();
        assertThat(BadgeConditionType.parseOrNull("SOMETHING_UNKNOWN")).isNull();
    }

    @Test
    @DisplayName("임계값이 없거나 0 이하면 UNKNOWN — '아무나 받는 뱃지' 를 막는다")
    void 잘못된_임계값() {
        assertThat(BadgeCondition.of(BadgeConditionType.AREA_POST_COUNT, null).known()).isFalse();
        assertThat(BadgeCondition.of(BadgeConditionType.AREA_POST_COUNT, 0).known()).isFalse();
        assertThat(BadgeCondition.of(BadgeConditionType.TOTAL_POST_COUNT, -1).known()).isFalse();
    }

    @Test
    @DisplayName("응답에는 해석된 조건만 나간다 — 저장된 JSON 을 그대로 흘리지 않는다")
    void 응답_형태() {
        assertThat(BadgeCondition.of(BadgeConditionType.AREA_POST_COUNT, 5).toMap())
                .containsEntry("type", "AREA_POST_COUNT")
                .containsEntry("threshold", 5);

        assertThat(BadgeCondition.UNKNOWN.toMap())
                .containsEntry("type", "UNKNOWN")
                .containsEntry("threshold", null);
    }

    @Test
    @DisplayName("분류 파싱: ALL 과 모르는 값은 전체 조회로 본다")
    void 분류_파싱() {
        assertThat(BadgeType.parseOrNull("ALL")).isNull();
        assertThat(BadgeType.parseOrNull(null)).isNull();
        assertThat(BadgeType.parseOrNull("WEIRD")).isNull();
        assertThat(BadgeType.parseOrNull("area")).isEqualTo(BadgeType.AREA);
    }
}
