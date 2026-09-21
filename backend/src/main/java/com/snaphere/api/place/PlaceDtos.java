package com.snaphere.api.place;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

public final class PlaceDtos {
    private PlaceDtos() { }

    public record Region(int areaCode, String nameKo, String nameEn,
                         String representativeImageUrl, int defaultEventVerifyRadiusM) { }
    public record Sigungu(int areaCode, int sigunguCode, String nameKo, String nameEn) { }

    public record PlaceSummary(String placeId, String placeType, String title, String addr1,
                               String imageUrl, Double lat, Double lng, int postCount,
                               int visitCount, Integer distanceM, Boolean isVerifiable,
                               Boolean isBookmarked) { }

    public record RankingEntry(int rank, Integer previousRank, BigDecimal score,
                               String period, String theme) { }

    public record UserSummary(String userId, String nickname, String profileImageUrl) { }
    public record PostSummary(String postId, UserSummary author, PlaceSummary place,
                              String thumbnailUrl, int imageCount, double aspectRatio,
                              String tier, int likeCount, int commentCount,
                              OffsetDateTime createdAt, Boolean isBookmarked) { }

    public record PlaceDetail(PlaceSummary place, String overview, String languageCode,
                              String tel, String homepage, int verifyRadiusM, long viewCount,
                              RankingEntry ranking, List<PlaceSummary> nearbyPlaces,
                              List<PostSummary> recentPosts) { }

    public record NearbyPlaceResult(PlaceSummary exactMatch, List<PlaceSummary> candidates,
                                    boolean createAllowed, int searchedRadiusM,
                                    Integer nearestDistanceM) { }

    public record NearestPlaceMatchRequest(
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double lng) { }

    public record NearestPlaceMatchResult(String suggestedName, String formattedAddress,
                                          List<PlaceSummary> candidates) { }

    public record CreatePlaceRequest(
            @NotBlank @Size(max = 100) String title,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double lng,
            @Size(max = 300) String addr1) { }

    public record CreatePlaceResult(PlaceSummary place, boolean created, String duplicateOfPlaceId) { }
    public record BookmarkResult(String targetType, String targetId, boolean isBookmarked,
                                 OffsetDateTime savedAt) { }
    public record TagSuggestion(String name, String normalizedName, String tagId, String source) { }

    public record CreateReportRequest(
            @NotBlank @Pattern(regexp = "INAPPROPRIATE|COPYRIGHT|PLACE_MISMATCH|SPAM|OTHER") String reason,
            @Size(max = 1000) String detail) { }
    public record ReportReceipt(String reportId, String status, OffsetDateTime createdAt) { }
    public record RadiusRequest(@Min(1) @Max(20000) int verifyRadiusM) { }
    public record EventRadiusRequest(@Min(1) @Max(20000) Integer verifyRadiusM) { }
    public record RegionRadiusRequest(@Min(1) @Max(20000) int defaultEventVerifyRadiusM) { }
}
