package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Base64;
import java.util.Map;

/**
 * 이벤트 목록 커서. (EVT-005)
 *
 * <p>정렬 키가 세 개다 — 정렬 그룹(진행 → 임박 → 예정 → 종료), 시작일, 이벤트 ID.
 * 그룹만으로도 시작일만으로도 같은 값이 흔해서 셋을 모두 담아야 페이지 경계에서 행이
 * 빠지거나 겹치지 않는다.
 *
 * <p>클라이언트가 해석하지 않는 불투명 문자열이다.
 */
public record EventCursor(int sortGroup, LocalDate startDate, long eventId) {

    private static final String SEPARATOR = ":";

    public String encode() {
        String raw = sortGroup + SEPARATOR + startDate.toEpochDay() + SEPARATOR + eventId;
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    /** @return 커서가 없으면 null. 형식이 깨졌으면 {@code COMMON_400} */
    public static EventCursor decode(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            return null;
        }
        try {
            String raw = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
            String[] parts = raw.split(SEPARATOR);
            if (parts.length != 3) {
                throw new IllegalArgumentException(raw);
            }
            return new EventCursor(
                    Integer.parseInt(parts[0]),
                    LocalDate.ofEpochDay(Long.parseLong(parts[1])),
                    Long.parseLong(parts[2]));
        } catch (IllegalArgumentException malformed) {
            throw new ApiException(ErrorCode.COMMON_400, Map.of("field", "cursor"));
        }
    }
}
