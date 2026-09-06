package com.snaphere.api.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.snaphere.api.auth.Platform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;
import com.snaphere.api.place.PlaceDtos;
import com.snaphere.api.post.dto.PostSummaryResponse;

/** USER API request/response contracts. JsonNode keeps omitted and explicit null distinct for PATCH. */
public final class UserDtos {
    private UserDtos() { }

    public record UpdateProfileRequest(JsonNode nickname, JsonNode bio, JsonNode profileImageKey, JsonNode locale) { }
    public record DeviceUpsertRequest(@NotBlank String deviceId, String fcmToken,
                                      @NotNull Platform platform, @NotBlank String appVersion) { }
    public record DeviceResult(UUID deviceId, String deviceIdentifier, Platform platform,
                               String fcmToken, String appVersion) { }
    public record NotificationPreferences(Boolean postLike, Boolean follow, Boolean badgeEarned) { }
    public record UserSummary(UUID userId, String nickname, String profileImageUrl, String bio,
                              Boolean isFollowing, Boolean isFollowedBy) { }
    public record ProfileStats(int postCount, int followerCount, int followingCount, int badgeCount) { }
    public record UserProfile(UserSummary user, ProfileStats stats) { }
    public record MyProfile(UserProfile profile, String email, String locale, String status,
                            String role, NotificationPreferences notificationPreferences) { }
    public record DeleteAccountRequest(@NotNull ContentAction contentAction, @Size(max = 500) String reason) { }
    public record DeletionPreview(long postCount, long imageCount, long commentCount, long followerCount,
                                  long badgeCount, long visitCount, int gracePeriodDays) { }
    public record DeletionReceipt(String status, Instant withdrawnAt, Instant purgeScheduledAt, String restoreKey) { }
    public record BookmarkItem(String targetType, String targetId, OffsetDateTime savedAt,
                               PostSummaryResponse post, PlaceDtos.PlaceSummary place) { }
}
