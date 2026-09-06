package com.snaphere.api.social;
import java.util.UUID;
public final class SocialDtos { private SocialDtos(){} public record FollowResult(UUID followingUserId,boolean isFollowing,int followerCount){} public record UserSummary(UUID userId,String nickname,String profileImageUrl,String bio,Boolean isFollowing,Boolean isFollowedBy){} }
