package com.snaphere.api.event.entity;

import com.snaphere.api.event.EventLifecycle;
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
import java.util.List;

/**
 * 행사. (EVT-001, EVT-011, EVT-017, EVT-023)
 *
 * <p>테이블은 {@code V11__place_features.sql} 이 이미 만들어 두었다. 이 엔터티는 그 위에
 * 얹히기만 하고 스키마를 바꾸지 않는다.
 *
 * <p>{@code fixed_tags} 는 jsonb 다. Hibernate 6 의 {@code @JdbcTypeCode(SqlTypes.JSON)} 이
 * 문자열 배열과 jsonb 를 직접 오간다 — 별도 라이브러리를 더하지 않으려고 이 방식을 골랐다.
 */
@Entity
@Table(name = "events")
public class EventEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "event_id")
    private Long eventId;

    /** TourAPI 콘텐츠 ID. 직접 등록한 행사는 null 이다 (EVT-004). */
    @Column(name = "content_id", length = 100)
    private String contentId;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "overview")
    private String overview;

    @Column(name = "area_code", nullable = false)
    private Integer areaCode;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "thumbnail_url", length = 2048)
    private String thumbnailUrl;

    /**
     * 행사 참여 업로드에 자동으로 붙는 태그 이름. 지역 1개 + 행사 이름 1개다 (EVT-017).
     *
     * <p>표시용 이름만 담는다. 정규화와 {@code tags} 행 연결은 태그 도메인이 한다 —
     * 여기에 tagId 를 넣으면 태그가 병합·삭제될 때 이 열이 낡는다.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "fixed_tags", nullable = false)
    private List<String> fixedTags;

    @Column(name = "participant_count", nullable = false)
    private int participantCount;

    @Column(name = "source", nullable = false, length = 20)
    private String source;

    /** null 이면 지역 기본값, 그것도 없으면 2,000m (EVT-023, PLC-022). */
    @Column(name = "verify_radius_m")
    private Integer verifyRadiusM;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private EventLifecycle status;

    /** 적재 시각. EVT-008 신규 판정의 기준이다. */
    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    protected EventEntity() {
    }

    public Long getEventId() {
        return eventId;
    }

    public String getContentId() {
        return contentId;
    }

    public String getTitle() {
        return title;
    }

    public String getOverview() {
        return overview;
    }

    public Integer getAreaCode() {
        return areaCode;
    }

    public Long getPlaceId() {
        return placeId;
    }

    public LocalDate getStartDate() {
        return startDate;
    }

    public LocalDate getEndDate() {
        return endDate;
    }

    public String getThumbnailUrl() {
        return thumbnailUrl;
    }

    /** @return 고정 태그 이름. 없으면 빈 목록 — null 을 흘려 호출자가 방어하게 두지 않는다 */
    public List<String> getFixedTags() {
        return fixedTags == null ? List.of() : fixedTags;
    }

    public int getParticipantCount() {
        return participantCount;
    }

    public String getSource() {
        return source;
    }

    public Integer getVerifyRadiusM() {
        return verifyRadiusM;
    }

    public EventLifecycle getStatus() {
        return status;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
