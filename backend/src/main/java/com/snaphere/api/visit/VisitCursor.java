package com.snaphere.api.visit;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Base64;
import java.util.Map;

/**
 * 방문 목록 커서. (VST-003, VST-005)
 *
 * <p>정렬 키가 날짜라 같은 날 방문이 여러 건 나온다 — {@code visitId} 를 2차 키로 함께 담는다.
 * 게시글 커서보다 이 문제가 더 잘 드러난다: 시각이 아니라 날짜라서 같은 값이 흔하다.
 *
 * <p>클라이언트가 해석하지 않는 불투명 문자열이다. 날짜를 epochDay 로 담는 것도 그래서다 —
 * 문자열로 보이면 앱이 날짜를 읽어 건너뛰기를 시도하게 된다.
 */
public record VisitCursor(LocalDate visitedOn, long visitId) {

    private static final String SEPARATOR = ":";

    public String encode() {
        String raw = visitedOn.toEpochDay() + SEPARATOR + visitId;
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /** @return 커서가 없으면 null. 형식이 깨졌으면 {@code COMMON_400} */
    public static VisitCursor decode(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
            int separator = raw.indexOf(SEPARATOR);
            if (separator < 0) {
                throw new IllegalArgumentException(raw);
            }
            return new VisitCursor(
                    LocalDate.ofEpochDay(Long.parseLong(raw.substring(0, separator))),
                    Long.parseLong(raw.substring(separator + 1)));
        } catch (IllegalArgumentException malformed) {
            throw new ApiException(ErrorCode.COMMON_400, Map.of("field", "cursor"));
        }
    }
}
