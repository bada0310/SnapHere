package com.snaphere.api.badge.entity;

import com.snaphere.api.badge.BadgeCondition;
import com.snaphere.api.badge.BadgeConditionType;
import com.snaphere.api.badge.BadgeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Map;

/**
 * 뱃지 정의. (BDG-001 ~ BDG-004, BDG-007)
 *
 * <p>이름을 {@code name_ko}·{@code name_en} 두 열로 갖는다. SYS-010 은 서버가 완성 문장을
 * 만들지 말라고 하지만 그건 "좋아요 3개가 달렸어요" 같은 조립 문장을 말하는 것이고, 뱃지
 * 이름은 운영이 입력한 고정 문자열이다. 명세도 {@code BadgeSummary.name} 을 locale 별 이름으로
 * 정의한다.
 */
@Entity
@Table(name = "badges")
public class BadgeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "badge_id")
    private Long badgeId;

    @Column(name = "code", nullable = false, length = 100)
    private String code;

    @Enumerated(EnumType.STRING)
    @Column(name = "type", nullable = false, length = 20)
    private BadgeType type;

    @Column(name = "name_ko", nullable = false, length = 100)
    private String nameKo;

    @Column(name = "name_en", length = 100)
    private String nameEn;

    @Column(name = "description", nullable = false, length = 500)
    private String description;

    @Column(name = "icon_url", length = 2048)
    private String iconUrl;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "condition_json", nullable = false)
    private Map<String, Object> conditionJson;

    /** 행사 뱃지의 대상 행사. {@code EVENT_PARTICIPATE} 가 이 값을 본다. */
    @Column(name = "event_id")
    private Long eventId;

    /** 지역 뱃지의 대상 시도. {@code AREA_POST_COUNT} 가 이 값을 본다. */
    @Column(name = "area_code")
    private Integer areaCode;

    @Column(name = "is_obtainable", nullable = false)
    private boolean obtainable;

    @Column(name = "available_from")
    private LocalDate availableFrom;

    @Column(name = "available_to")
    private LocalDate availableTo;

    @Column(name = "earned_count", nullable = false)
    private int earnedCount;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected BadgeEntity() {
    }

    /**
     * 저장된 JSON 을 조건으로 읽는다.
     *
     * <p>형식이 깨져 있어도 예외를 던지지 않는다. 뱃지 하나의 JSON 오타 때문에 수집함 전체가
     * 500 이 되면 안 된다 — 그 뱃지만 {@link BadgeCondition#UNKNOWN} 이 되어 지급되지 않는다.
     */
    public BadgeCondition condition() {
        if (conditionJson == null) {
            return BadgeCondition.UNKNOWN;
        }
        Object rawType = conditionJson.get("type");
        Object rawThreshold = conditionJson.get("threshold");
        Integer threshold = rawThreshold instanceof Number number ? number.intValue() : null;
        return BadgeCondition.of(
                BadgeConditionType.parseOrNull(rawType == null ? null : rawType.toString()),
                threshold);
    }

    /** @param language {@code Accept-Language} 앞 두 글자. 영어가 비어 있으면 한국어로 돌아간다 */
    public String nameFor(String language) {
        if ("en".equalsIgnoreCase(language) && nameEn != null && !nameEn.isBlank()) {
            return nameEn;
        }
        return nameKo;
    }

    public Long getBadgeId() {
        return badgeId;
    }

    public String getCode() {
        return code;
    }

    public BadgeType getType() {
        return type;
    }

    public String getNameKo() {
        return nameKo;
    }

    public String getNameEn() {
        return nameEn;
    }

    public String getDescription() {
        return description;
    }

    public String getIconUrl() {
        return iconUrl;
    }

    public Long getEventId() {
        return eventId;
    }

    public Integer getAreaCode() {
        return areaCode;
    }

    public boolean isObtainable() {
        return obtainable;
    }

    public LocalDate getAvailableFrom() {
        return availableFrom;
    }

    public LocalDate getAvailableTo() {
        return availableTo;
    }

    public int getEarnedCount() {
        return earnedCount;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
