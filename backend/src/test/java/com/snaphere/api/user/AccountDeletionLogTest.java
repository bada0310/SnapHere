package com.snaphere.api.user;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class AccountDeletionLogTest {

    @Test
    void 탈퇴_이력은_콘텐츠_처리_선택과_파기_완료_시각을_보존한다() {
        UUID userId = UUID.randomUUID();
        Instant requestedAt = Instant.parse("2026-09-06T00:00:00Z");
        AccountDeletionLog log = AccountDeletionLog.requested(
                userId, "더 이상 사용하지 않음", ContentAction.KEEP_ANONYMIZED, requestedAt);

        assertThat(log.getUserId()).isEqualTo(userId);
        assertThat(log.getContentAction()).isEqualTo(ContentAction.KEEP_ANONYMIZED);
        assertThat(log.getPurgedAt()).isNull();

        Instant purgedAt = requestedAt.plusSeconds(30L * 24 * 60 * 60);
        log.markPurged(purgedAt);

        assertThat(log.getPurgedAt()).isEqualTo(purgedAt);
    }
}
