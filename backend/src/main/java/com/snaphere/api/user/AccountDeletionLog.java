package com.snaphere.api.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

/**
 * 탈퇴 접수·물리 파기 감사 이력 (USER-015, USER-019).
 *
 * <p>유예 만료 후 사용자 행은 물리 삭제되므로 user_id에는 JPA 연관관계를 두지 않는다.
 * 이력은 개인정보를 복원하지 않는 범위에서 보존한다.
 */
@Entity
@Table(name = "account_deletion_logs")
public class AccountDeletionLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private Long id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(length = 500)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "content_action", nullable = false, length = 30)
    private ContentAction contentAction;

    @Column(name = "deleted_at", nullable = false)
    private Instant deletedAt;

    @Column(name = "purged_at")
    private Instant purgedAt;

    protected AccountDeletionLog() {
    }

    public static AccountDeletionLog requested(UUID userId, String reason,
                                               ContentAction contentAction, Instant deletedAt) {
        AccountDeletionLog log = new AccountDeletionLog();
        log.userId = userId;
        log.reason = reason;
        log.contentAction = contentAction;
        log.deletedAt = deletedAt;
        return log;
    }

    public Long getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getReason() {
        return reason;
    }

    public ContentAction getContentAction() {
        return contentAction;
    }

    public Instant getDeletedAt() {
        return deletedAt;
    }

    public Instant getPurgedAt() {
        return purgedAt;
    }

    public void markPurged(Instant purgedAt) {
        this.purgedAt = purgedAt;
    }
}
