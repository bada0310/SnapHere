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

import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * 행사. (EVT-001, EVT-011, EVT-017, EVT-023)
 *
 * <p>테이블은 {@code V11__place_features.sql} 이 이미 만들어 두었다. 이 엔터티는 그 위에
 * 얹히기만 하고 스키마를 바꾸지 않는다.
 *
 * <p>{@code fixed_tags} 는 아직 매핑하지 않는다. jsonb 라 H2 로 스키마를 만드는 테스트에서
 * 형식이 어긋나고, 고정 태그를 실제로 읽는 것은 업로드 컨텍스트(EVT-016~020) 슬라이스다.
 * 매핑하지 않은 컬럼은 {@code ddl-auto=validate} 가 문제 삼지 않는다.
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
