package com.snaphere.api.visit.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * 방문 기록. (VST-001, VST-002)
 *
 * <p>{@code visitedOn} 은 Asia/Seoul 기준 날짜다 (SYS-005). 중복 판정이 이 값으로 이뤄지므로,
 * 자정 경계가 사용자가 보는 날짜와 같아야 "오늘 이미 기록됐다"는 응답이 납득된다.
 *
 * <p>삽입은 이 엔티티로 하지 않는다 — {@code VisitRepository.insertIfAbsent} 가 유니크 제약에
 * 기대는 방식이라, 이 클래스는 조회 전용으로 쓰인다.
 */
@Entity
@Table(name = "visits")
public class VisitEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "visit_id")
    private Long visitId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "visited_on", nullable = false)
    private LocalDate visitedOn;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    protected VisitEntity() {
    }

    public Long getVisitId() {
        return visitId;
    }

    public UUID getUserId() {
        return userId;
    }

    public Long getPlaceId() {
        return placeId;
    }

    public Long getPostId() {
        return postId;
    }

    public LocalDate getVisitedOn() {
        return visitedOn;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
}
