package com.snaphere.api.user;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

/** USER 탈퇴·복구·파기 단계가 공유하는 이력 저장소. */
public interface AccountDeletionLogRepository extends JpaRepository<AccountDeletionLog, Long> {

    List<AccountDeletionLog> findByUserIdOrderByDeletedAtDesc(UUID userId);

    java.util.Optional<AccountDeletionLog> findFirstByUserIdOrderByDeletedAtDesc(UUID userId);
}
