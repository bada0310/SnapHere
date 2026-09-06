package com.snaphere.api.post.dto;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.entity.BadgeEntity;

import java.time.OffsetDateTime;

/**
 * 명세: 4. 응답 스키마 &gt; BadgeSummary.
 *
 * <p>게시글 등록 응답의 새로 획득한 뱃지(API-PST-003), 행사 상세·업로드 컨텍스트의 뱃지
 * 미리보기(API-EVT-003, API-EVT-005), 수집함 항목(API-BDG-001)이 모두 이 형태를 쓴다.
 *
 * <p><b>{@code name}·{@code description} 은 서버가 채운다.</b> 이전에는 {@code nameKey} 로
 * 내보내며 "앱이 다국어를 조립한다"고 적어 두었는데, 그 원칙(SYS-010)은 "좋아요 3개가
 * 달렸어요" 같은 조립 문장을 두고 한 말이다. 뱃지 이름은 운영이 입력한 고정 문자열이고
 * {@code badges} 테이블이 {@code name_ko}·{@code name_en} 두 열로 갖고 있다. 명세도
 * {@code name} 을 locale 별 이름으로 정의한다.
 */
public record BadgeSummaryResponse(
        String badgeId,
        String type,
        String name,
        String description,
        String iconUrl,
        boolean isObtainable,
        boolean earned,
        OffsetDateTime earnedAt
) {
    /** 수집함·미리보기용. {@code earnedAt} 이 null 이면 미획득(회색)이다 (BDG-010). */
    public static BadgeSummaryResponse of(BadgeEntity badge, String language,
                                          OffsetDateTime earnedAt) {
        return new BadgeSummaryResponse(
                ExternalIds.badge(badge.getBadgeId()),
                badge.getType().name(),
                badge.nameFor(language),
                badge.getDescription(),
                badge.getIconUrl(),
                badge.isObtainable(),
                earnedAt != null,
                earnedAt);
    }

    /** 게시글 등록으로 방금 받은 뱃지. 정의상 항상 획득 상태다. */
    public static BadgeSummaryResponse from(AwardedBadge badge) {
        return new BadgeSummaryResponse(
                ExternalIds.badge(badge.badgeId()),
                badge.type(),
                badge.name(),
                badge.description(),
                badge.iconUrl(),
                true,
                true,
                badge.earnedAt());
    }
}
