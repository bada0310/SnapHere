package com.snaphere.api.badge;

import java.time.OffsetDateTime;

/**
 * 새로 획득한 뱃지. 명세: 4. 응답 스키마 &gt; BadgeSummary
 *
 * <p>이름과 설명은 {@code badges} 테이블에 운영이 입력해 둔 값이다. 서버가 문장을 조립하는
 * 것이 아니라 저장된 문자열을 locale 에 맞춰 고르는 것이다 (SYS-010 의 취지와 어긋나지 않는다).
 */
public record AwardedBadge(
        long badgeId,
        String type,
        String name,
        String description,
        String iconUrl,
        OffsetDateTime earnedAt
) {
}
