package com.snaphere.api.auth;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "users")
public class User {
    @Id private UUID id;
    @Column(name = "google_subject", nullable = false, unique = true) private String googleSubject;
    @Column(nullable = false) private String email;
    private String nickname;
    @Column(name = "profile_image_url") private String profileImageUrl;
    @Column(length = 200) private String bio;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private UserStatus status;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private UserRole role;
    @Column(name = "onboarding_completed", nullable = false) private boolean onboardingCompleted;
    @Column(name = "terms_version") private String termsVersion;
    @Column(name = "terms_agreed_at") private Instant termsAgreedAt;
    @Column(nullable = false) private String locale;
    @Column(name = "upload_blocked_until") private Instant uploadBlockedUntil;
    @Column(name = "push_like_enabled", nullable = false) private boolean pushLikeEnabled = true;
    @Column(name = "push_follow_enabled", nullable = false) private boolean pushFollowEnabled = true;
    @Column(name = "push_badge_enabled", nullable = false) private boolean pushBadgeEnabled = true;
    @Column(name = "badge_count", nullable = false) private int badgeCount;
    @Column(name = "follower_count", nullable = false) private int followerCount;
    @Column(name = "following_count", nullable = false) private int followingCount;
    @Column(name = "post_count", nullable = false) private int postCount;
    @Column(name = "withdrawn_at") private Instant withdrawnAt;
    @Column(name = "purge_scheduled_at") private Instant purgeScheduledAt;
    @Column(name = "restore_key", length = 64) private String restoreKey;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    protected User() {}
    public static User newGoogleUser(String subject, String email, String picture) { User u = new User(); u.id=UUID.randomUUID(); u.googleSubject=subject; u.email=email; u.profileImageUrl=picture; u.status=UserStatus.PENDING; u.role=UserRole.USER; u.locale="ko-KR"; u.pushLikeEnabled=true; u.pushFollowEnabled=true; u.pushBadgeEnabled=true; u.createdAt=u.updatedAt=Instant.now(); return u; }
    public UUID getId(){return id;} public String getEmail(){return email;} public String getNickname(){return nickname;} public String getProfileImageUrl(){return profileImageUrl;} public String getBio(){return bio;} public UserStatus getStatus(){return status;} public UserRole getRole(){return role;} public boolean isOnboardingCompleted(){return onboardingCompleted;} public String getTermsVersion(){return termsVersion;} public Instant getTermsAgreedAt(){return termsAgreedAt;} public String getLocale(){return locale;} public Instant getUploadBlockedUntil(){return uploadBlockedUntil;} public boolean isPushLikeEnabled(){return pushLikeEnabled;} public boolean isPushFollowEnabled(){return pushFollowEnabled;} public boolean isPushBadgeEnabled(){return pushBadgeEnabled;} public int getBadgeCount(){return badgeCount;} public int getFollowerCount(){return followerCount;} public int getFollowingCount(){return followingCount;} public int getPostCount(){return postCount;} public Instant getWithdrawnAt(){return withdrawnAt;} public Instant getPurgeScheduledAt(){return purgeScheduledAt;} public String getRestoreKey(){return restoreKey;}
    public void completeOnboarding(String nickname, String termsVersion, String locale) { this.nickname=nickname; this.termsVersion=termsVersion; this.termsAgreedAt=Instant.now(); this.locale=locale; this.onboardingCompleted=true; this.status=UserStatus.ACTIVE; this.updatedAt=Instant.now(); }
    public void updateProfile(String nickname, String bio, String profileImageUrl, String locale,
                              boolean changeNickname, boolean changeBio, boolean changeImage, boolean changeLocale) {
        if (changeNickname) this.nickname = nickname;
        if (changeBio) this.bio = bio;
        if (changeImage) this.profileImageUrl = profileImageUrl;
        if (changeLocale) this.locale = locale;
        this.updatedAt = Instant.now();
    }
    public void updateNotificationPreferences(Boolean postLike, Boolean follow, Boolean badgeEarned) {
        if (postLike != null) this.pushLikeEnabled = postLike;
        if (follow != null) this.pushFollowEnabled = follow;
        if (badgeEarned != null) this.pushBadgeEnabled = badgeEarned;
        this.updatedAt = Instant.now();
    }
    public void withdraw(Instant now, Instant purgeAt, String restoreKey) {
        this.status = UserStatus.WITHDRAWN;
        this.withdrawnAt = now;
        this.purgeScheduledAt = purgeAt;
        this.restoreKey = restoreKey;
        this.updatedAt = now;
    }
    public void restore(String nickname) { this.nickname=nickname; this.status=UserStatus.ACTIVE; this.withdrawnAt=null; this.purgeScheduledAt=null; this.restoreKey=null; this.updatedAt=Instant.now(); }
}
