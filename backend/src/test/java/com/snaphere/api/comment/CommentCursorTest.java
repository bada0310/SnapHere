package com.snaphere.api.comment;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 댓글 목록 커서 — CMU-013, CMU-010
 */
class CommentCursorTest {

    @Test
    @DisplayName("두 정렬 키가 왕복해도 그대로 살아 있다")
    void roundTrip() {
        OffsetDateTime at = OffsetDateTime.of(2026, 9, 3, 12, 0, 0, 0, ZoneOffset.UTC);
        CommentCursor decoded = CommentCursor.decode(new CommentCursor(at, 42L).encode());

        assertThat(decoded.commentId()).isEqualTo(42L);
        assertThat(decoded.createdAt().toInstant()).isEqualTo(at.toInstant());
    }

    @Test
    @DisplayName("커서가 없으면 null — 첫 페이지다")
    void absent() {
        assertThat(CommentCursor.decode(null)).isNull();
        assertThat(CommentCursor.decode("   ")).isNull();
    }

    @Test
    @DisplayName("깨진 커서는 500 이 아니라 400 이다")
    void malformed() {
        assertThatThrownBy(() -> CommentCursor.decode("!!!not-base64!!!"))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.COMMON_400));
    }

    @Test
    @DisplayName("마이크로초를 잃지 않는다 — 밀리초로 자르면 같은 밀리초의 댓글이 다음 페이지에서 통째로 빠진다")
    void keepsSubMillisecondPrecision() {
        java.time.OffsetDateTime at =
                java.time.OffsetDateTime.parse("2026-09-05T12:34:56.123456+09:00");
        CommentCursor decoded = CommentCursor.decode(new CommentCursor(at, 9301L).encode());

        org.assertj.core.api.Assertions.assertThat(decoded).isNotNull();
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant())
                .isEqualTo(at.toInstant());
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant().getNano())
                .isEqualTo(123_456_000);
        org.assertj.core.api.Assertions.assertThat(decoded.commentId()).isEqualTo(9301L);
    }

    @Test
    @DisplayName("이 수정 이전에 발급한 두 토막 커서도 계속 받는다 — 앱이 들고 있던 커서가 400 이 되면 목록이 처음으로 튄다")
    void acceptsLegacyMillisecondCursor() {
        String legacy = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("1788000000000:" + 9301L).getBytes(java.nio.charset.StandardCharsets.UTF_8));

        CommentCursor decoded = CommentCursor.decode(legacy);

        org.assertj.core.api.Assertions.assertThat(decoded).isNotNull();
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant().toEpochMilli())
                .isEqualTo(1788000000000L);
        org.assertj.core.api.Assertions.assertThat(decoded.commentId()).isEqualTo(9301L);
    }
}
