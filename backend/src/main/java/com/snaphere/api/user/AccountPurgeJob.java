package com.snaphere.api.user;

import com.snaphere.api.auth.User;
import com.snaphere.api.auth.UserRepository;
import com.snaphere.api.auth.UserStatus;
import com.snaphere.api.post.repository.PostRepository;
import com.snaphere.api.post.repository.PostImageRepository;
import com.snaphere.api.media.storage.MediaObjectStore;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/** JOB-010: 30일 유예가 끝난 계정의 개인정보를 물리 삭제한다. */
@Component
public class AccountPurgeJob {
    static final UUID ANONYMOUS_AUTHOR_ID = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final UserRepository users; private final PostRepository posts; private final AccountDeletionLogRepository logs; private final PostImageRepository images; private final MediaObjectStore objects;
    public AccountPurgeJob(UserRepository users, PostRepository posts, AccountDeletionLogRepository logs, PostImageRepository images, MediaObjectStore objects) { this.users=users; this.posts=posts; this.logs=logs; this.images=images; this.objects=objects; }
    @Scheduled(cron="${snaphere.jobs.account-purge-cron:0 0 5 * * *}",zone="Asia/Seoul")
    @Transactional public void purgeExpired() {
        Instant now=Instant.now();
        for(User user:users.findByStatusAndPurgeScheduledAtLessThanEqual(UserStatus.WITHDRAWN,now)) {
            images.findByAuthorId(user.getId()).forEach(image -> { try { objects.delete(image.getImageKey()); } catch (RuntimeException ignored) { } });
            posts.reassignAuthor(user.getId(),ANONYMOUS_AUTHOR_ID);
            logs.findFirstByUserIdOrderByDeletedAtDesc(user.getId()).ifPresent(log->log.markPurged(now));
            users.delete(user);
        }
    }
    @Transactional public void purgeImmediately(User user) { images.findByAuthorId(user.getId()).forEach(image -> { try { objects.delete(image.getImageKey()); } catch (RuntimeException ignored) { } }); posts.softDeleteByUserId(user.getId(), java.time.OffsetDateTime.now()); posts.reassignAuthor(user.getId(),ANONYMOUS_AUTHOR_ID); logs.save(AccountDeletionLog.requested(user.getId(), "ADMIN_FORCE_DELETE", ContentAction.DELETE_ALL, Instant.now())); users.delete(user); }
}
