package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** 이벤트 목록 커서 — EVT-005, SYS-004 */
class EventCursorTest {

    private static final LocalDate START = LocalDate.of(2026, 9, 10);

    @Test
    @DisplayName("담았다가 꺼내면 같은 값이 나온다")
    void 왕복() {
        EventCursor decoded = EventCursor.decode(
                new EventCursor(EventSortGroup.IMMINENT, START, 42L).encode());

        assertThat(decoded.sortGroup()).isEqualTo(EventSortGroup.IMMINENT);
        assertThat(decoded.startDate()).isEqualTo(START);
        assertThat(decoded.eventId()).isEqualTo(42L);
    }

    @Test
    @DisplayName("커서는 앱이 읽을 값이 아니다")
    void 불투명() {
        String encoded = new EventCursor(EventSortGroup.ONGOING, START, 42L).encode();
        assertThat(encoded).doesNotContain(":");
        assertThat(encoded).doesNotContain("2026-09-10");
    }

    @Test
    @DisplayName("커서가 없으면 null — 첫 페이지다")
    void 첫_페이지() {
        assertThat(EventCursor.decode(null)).isNull();
        assertThat(EventCursor.decode("")).isNull();
        assertThat(EventCursor.decode("   ")).isNull();
    }

    @Test
    @DisplayName("깨진 커서는 400 — 조용히 첫 페이지로 돌리면 무한 스크롤이 처음으로 되감긴다")
    void 깨진_커서() {
        assertThatThrownBy(() -> EventCursor.decode("not-a-cursor"))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.COMMON_400));
    }

    @Test
    @DisplayName("키가 셋이 아니면 400")
    void 키_개수() {
        String twoKeys = java.util.Base64.getUrlEncoder().withoutPadding()
                .encodeToString("0:20000".getBytes(java.nio.charset.StandardCharsets.UTF_8));

        assertThatThrownBy(() -> EventCursor.decode(twoKeys))
                .isInstanceOf(ApiException.class);
    }
}
