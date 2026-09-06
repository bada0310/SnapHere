package com.snaphere.api.post;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** 목록 커서 — SYS-004 */
class PostCursorTest {

    private static final OffsetDateTime AT = OffsetDateTime.parse("2026-09-02T12:34:56+09:00");

    @Test
    @DisplayName("담았다가 꺼내면 같은 값이 나온다")
    void 왕복() {
        String encoded = new PostCursor(AT, 42L).encode();
        PostCursor decoded = PostCursor.decode(encoded);

        assertThat(decoded.postId()).isEqualTo(42L);
        assertThat(decoded.createdAt().toInstant()).isEqualTo(AT.toInstant());
    }

    @Test
    @DisplayName("커서는 앱이 읽을 값이 아니다 — 정렬 키가 그대로 보이지 않는다")
    void 불투명() {
        String encoded = new PostCursor(AT, 42L).encode();
        // 구분자와 원문 형태가 그대로 드러나지 않는다. Base64URL 알파벳에는 ':' 가 없다.
        assertThat(encoded).doesNotContain(":");
        assertThat(encoded).isNotEqualTo(AT.toInstant().toEpochMilli() + ":42");
    }

    @Test
    @DisplayName("커서가 없으면 null — 첫 페이지다")
    void 첫_페이지() {
        assertThat(PostCursor.decode(null)).isNull();
        assertThat(PostCursor.decode("")).isNull();
        assertThat(PostCursor.decode("   ")).isNull();
    }

    @Test
    @DisplayName("형식이 깨진 커서는 COMMON_400")
    void 잘못된_커서() {
        for (String broken : new String[]{"!!!not-base64!!!", "YWJj", "MTIzNA"}) {
            assertThatThrownBy(() -> PostCursor.decode(broken))
                    .isInstanceOf(ApiException.class)
                    .satisfies(t -> assertThat(((ApiException) t).errorCode())
                            .isEqualTo(ErrorCode.COMMON_400));
        }
    }

    @Test
    @DisplayName("같은 시각이면 postId 로 갈린다 — 같은 행이 두 페이지에 나오지 않는다")
    void 동시각_구분() {
        assertThat(new PostCursor(AT, 1L).encode())
                .isNotEqualTo(new PostCursor(AT, 2L).encode());
    }

    @Test
    @DisplayName("마이크로초를 잃지 않는다 — 밀리초로 자르면 같은 밀리초의 게시글이 다음 페이지에서 통째로 빠진다")
    void keepsSubMillisecondPrecision() {
        java.time.OffsetDateTime at =
                java.time.OffsetDateTime.parse("2026-09-05T12:34:56.123456+09:00");
        PostCursor decoded = PostCursor.decode(new PostCursor(at, 9101L).encode());

        org.assertj.core.api.Assertions.assertThat(decoded).isNotNull();
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant())
                .isEqualTo(at.toInstant());
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant().getNano())
                .isEqualTo(123_456_000);
        org.assertj.core.api.Assertions.assertThat(decoded.postId()).isEqualTo(9101L);
    }

    @Test
    @DisplayName("이 수정 이전에 발급한 두 토막 커서도 계속 받는다 — 앱이 들고 있던 커서가 400 이 되면 목록이 처음으로 튄다")
    void acceptsLegacyMillisecondCursor() {
        String legacy = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("1788000000000:" + 9101L).getBytes(java.nio.charset.StandardCharsets.UTF_8));

        PostCursor decoded = PostCursor.decode(legacy);

        org.assertj.core.api.Assertions.assertThat(decoded).isNotNull();
        org.assertj.core.api.Assertions.assertThat(decoded.createdAt().toInstant().toEpochMilli())
                .isEqualTo(1788000000000L);
        org.assertj.core.api.Assertions.assertThat(decoded.postId()).isEqualTo(9101L);
    }
}
