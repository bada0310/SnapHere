package com.snaphere.api.visit;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** 방문 목록 커서 — VST-003, VST-005 */
class VisitCursorTest {

    @Test
    @DisplayName("날짜와 2차 키가 왕복해도 그대로 살아 있다")
    void roundTrip() {
        VisitCursor decoded = VisitCursor.decode(
                new VisitCursor(LocalDate.of(2026, 9, 4), 42L).encode());

        assertThat(decoded.visitedOn()).isEqualTo(LocalDate.of(2026, 9, 4));
        assertThat(decoded.visitId()).isEqualTo(42L);
    }

    @Test
    @DisplayName("커서가 없으면 null — 첫 페이지다")
    void absent() {
        assertThat(VisitCursor.decode(null)).isNull();
        assertThat(VisitCursor.decode("  ")).isNull();
    }

    @Test
    @DisplayName("깨진 커서는 500 이 아니라 400 이다")
    void malformed() {
        assertThatThrownBy(() -> VisitCursor.decode("!!!not-base64!!!"))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.COMMON_400));
    }

    @Test
    @DisplayName("날짜를 그대로 노출하지 않는다 — 앱이 읽어 건너뛰지 못하게 한다")
    void opaque() {
        assertThat(new VisitCursor(LocalDate.of(2026, 9, 4), 1L).encode())
                .doesNotContain("2026").doesNotContain("09-04");
    }
}
