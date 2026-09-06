package com.snaphere.api.post;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Map;

/**
 * 목록 커서. (SYS-004)
 *
 * <p>정렬 키 두 개를 담는다 — {@code createdAt} 과 {@code postId}. 시각만 담으면 같은 순간에
 * 만들어진 게시글이 두 페이지에 나오거나 한 페이지에서 사라진다.
 *
 * <p><b>시각을 밀리초로 줄이지 않는다.</b> PostgreSQL {@code timestamptz} 는 마이크로초까지
 * 보관한다. 밀리초로 자르면 커서 시각이 실제 값보다 앞서고, 조회 조건의
 * {@code createdAt = :cursor} 가 영영 맞지 않아 같은 밀리초의 게시글이 다음 페이지에서
 * 통째로 빠진다. 초와 나노초를 따로 담는다.
 *
 * <p><b>클라이언트가 해석하지 않는 불투명 문자열이다.</b> Base64 로 감싸는 것은 암호화가 아니라
 * "이 값을 읽지 마라"는 신호다. 앱이 커서를 파싱해 페이지를 건너뛰기 시작하면 서버가 정렬 방식을
 * 바꿀 수 없게 된다.
 *
 * <p>위조를 막지는 않는다. 커서를 조작해도 자기 페이징만 어긋나고 남의 데이터가 보이지는 않는다 —
 * 목록 자체가 공개 범위이기 때문이다. 서명은 그 값에 비해 비용이 크다.
 */
public record PostCursor(OffsetDateTime createdAt, long postId) {

    private static final String SEPARATOR = ":";

    public String encode() {
        java.time.Instant at = createdAt.toInstant();
        String raw = at.getEpochSecond() + SEPARATOR + at.getNano() + SEPARATOR + postId;
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /** @return 커서가 없으면 null. 형식이 깨졌으면 {@code COMMON_400} */
    public static PostCursor decode(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
            String[] parts = raw.split(SEPARATOR);
            // 두 토막은 이 수정 이전에 발급한 커서다. 앱이 들고 있던 것을 400 으로 되돌리면
            // 무한 스크롤이 처음으로 튀므로 밀리초로 해석해 계속 넘긴다.
            if (parts.length == 2) {
                return new PostCursor(
                        OffsetDateTime.ofInstant(
                                Instant.ofEpochMilli(Long.parseLong(parts[0])), ZoneOffset.UTC),
                        Long.parseLong(parts[1]));
            }
            if (parts.length != 3) {
                throw new IllegalArgumentException(raw);
            }
            return new PostCursor(
                    OffsetDateTime.ofInstant(
                            Instant.ofEpochSecond(Long.parseLong(parts[0]), Long.parseLong(parts[1])),
                            ZoneOffset.UTC),
                    Long.parseLong(parts[2]));
        } catch (IllegalArgumentException malformed) {
            throw new ApiException(ErrorCode.COMMON_400, Map.of("field", "cursor"));
        }
    }
}
