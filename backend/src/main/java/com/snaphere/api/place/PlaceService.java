package com.snaphere.api.place;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.web.CursorCodec;
import com.snaphere.api.common.web.CursorPage;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.ZonedDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Locale;

@Service
public class PlaceService {
    private static final int MAX_PAGE = 50;
    private final PlaceRepository places;
    private final GoogleGeocodingClient geocoder;
    private final TourPlaceDetailClient details;
    private final ViewCounterService views;
    private final RecentPlaceService recentPlaces;

    public PlaceService(PlaceRepository places, GoogleGeocodingClient geocoder,
                        TourPlaceDetailClient details, ViewCounterService views,
                        RecentPlaceService recentPlaces) {
        this.places = places;
        this.geocoder = geocoder;
        this.details = details;
        this.views = views;
        this.recentPlaces = recentPlaces;
    }

    public List<PlaceDtos.Region> regions() { return places.regions(); }
    public List<PlaceDtos.Sigungu> sigungu(int areaCode) { return places.sigungu(areaCode); }

    public CursorPage<PlaceDtos.PlaceSummary> list(Integer areaCode, Integer sigunguCode,
                                                    Integer contentTypeId, String keyword,
                                                    String cursor, int size, CurrentUser actor) {
        if (sigunguCode != null && areaCode == null) throw new ApiException(ErrorCode.COMMON_400);
        if (keyword != null && keyword.length() > 100) throw new ApiException(ErrorCode.COMMON_400);
        int pageSize = validSize(size);
        Long after = CursorCodec.decode(cursor);
        List<PlaceDtos.PlaceSummary> rows = places.list(areaCode, sigunguCode, contentTypeId,
                keyword, after, pageSize + 1, actor == null ? null : actor.userId());
        return page(rows, pageSize, p -> ExternalIds.parse(p.placeId(), "plc", ErrorCode.COMMON_400));
    }

    public PlaceDtos.NearbyPlaceResult nearby(double lat, double lng, int radiusM, CurrentUser actor) {
        validCoordinate(lat, lng);
        if (radiusM < 1 || radiusM > 20_000) throw new ApiException(ErrorCode.PLACE_RADIUS_TOO_LARGE);
        List<PlaceDtos.PlaceSummary> candidates = places.nearby(lat, lng, radiusM, 50,
                actor == null ? null : actor.userId());
        PlaceDtos.PlaceSummary exact = candidates.stream().filter(p -> Boolean.TRUE.equals(p.isVerifiable())).findFirst().orElse(null);
        Integer nearestDistance = candidates.isEmpty() ? places.nearestDistance(lat, lng) : null;
        return new PlaceDtos.NearbyPlaceResult(exact, candidates, exact == null, radiusM, nearestDistance);
    }

    public PlaceDtos.PlaceDetail detail(String externalId, String acceptLanguage, CurrentUser actor) {
        long id = ExternalIds.parse(externalId, "plc", ErrorCode.PLACE_NOT_FOUND);
        PlaceRepository.PlaceRecord place = places.placeRecord(id);
        String language = language(acceptLanguage);
        ensureDetail(place, language);
        PlaceRepository.DetailRecord detail = places.detail(id, language);
        if (detail.overview() == null && !"ko".equals(language)) {
            ensureDetail(place, "ko");
            detail = places.detail(id, "ko");
            language = "ko";
        }
        java.util.UUID viewer = actor == null ? null : actor.userId();
        PlaceDtos.PlaceSummary summary = places.summary(id, viewer);
        List<PlaceDtos.PlaceSummary> nearby = summary.lat() == null ? List.of() : places.nearby(
                summary.lat(), summary.lng(), 5000, 7, viewer).stream().filter(p -> !p.placeId().equals(externalId)).limit(6).toList();
        List<PlaceDtos.PostSummary> recent = places.posts(id, null, 12, viewer);
        long totalViews = detail.viewCount() + views.pending(id) + 1;
        views.increment(id);
        // 최근 본 장소 (VST-006). 비회원은 남길 곳이 없어 건너뛴다.
        recentPlaces.record(viewer, id);
        return new PlaceDtos.PlaceDetail(summary, detail.overview(), language, detail.tel(), detail.homepage(),
                detail.verifyRadiusM(), totalViews, places.ranking(id), nearby, recent);
    }

    public CursorPage<PlaceDtos.PostSummary> posts(String externalId, String cursor, int size, CurrentUser actor) {
        long id = ExternalIds.parse(externalId, "plc", ErrorCode.PLACE_NOT_FOUND);
        places.placeRecord(id);
        int pageSize = validSize(size);
        List<PlaceDtos.PostSummary> rows = places.posts(id, CursorCodec.decode(cursor), pageSize + 1,
                actor == null ? null : actor.userId());
        return page(rows, pageSize, p -> ExternalIds.parse(p.postId(), "pst", ErrorCode.COMMON_400));
    }

    @Transactional
    public PlaceDtos.CreatePlaceResult create(CurrentUser actor, PlaceDtos.CreatePlaceRequest body) {
        validCoordinate(body.lat(), body.lng());
        var administrative = geocoder.reverse(body.lat(), body.lng());
        var area = places.resolveArea(administrative.regionName(), administrative.districtName());
        String normalized = PlaceRepository.normalizeTitle(body.title());
        places.lockDuplicateKey(normalized);
        Long duplicate = places.duplicate(normalized, body.lat(), body.lng());
        if (duplicate != null) {
            return new PlaceDtos.CreatePlaceResult(places.summary(duplicate, actor.userId()), false,
                    ExternalIds.place(duplicate));
        }
        if (places.userPlaceCountToday(actor.userId()) >= 5) {
            ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Asia/Seoul"));
            int retry = Math.toIntExact(Duration.between(now, now.toLocalDate().plusDays(1)
                    .atStartOfDay(now.getZone())).getSeconds());
            throw new ApiException(ErrorCode.PLACE_DAILY_LIMIT, java.util.Map.of("limit", 5), retry);
        }
        long id = places.insertUserPlace(actor.userId(), body, normalized, area);
        return new PlaceDtos.CreatePlaceResult(places.summary(id, actor.userId()), true, null);
    }

    public PlaceDtos.BookmarkResult bookmark(CurrentUser actor, String externalId) {
        long id = ExternalIds.parse(externalId, "plc", ErrorCode.PLACE_NOT_FOUND);
        return new PlaceDtos.BookmarkResult("PLACE", externalId, true, places.bookmark(actor.userId(), id));
    }

    public PlaceDtos.BookmarkResult unbookmark(CurrentUser actor, String externalId) {
        long id = ExternalIds.parse(externalId, "plc", ErrorCode.PLACE_NOT_FOUND);
        places.unbookmark(actor.userId(), id);
        return new PlaceDtos.BookmarkResult("PLACE", externalId, false, null);
    }

    public CursorPage<PlaceDtos.PlaceSummary> bookmarks(CurrentUser actor, String cursor, int size) {
        int pageSize = validSize(size);
        List<PlaceDtos.PlaceSummary> rows = places.bookmarkedPlaces(actor.userId(), CursorCodec.decode(cursor), pageSize + 1);
        return page(rows, pageSize, p -> ExternalIds.parse(p.placeId(), "plc", ErrorCode.COMMON_400));
    }

    @Transactional
    public PlaceDtos.ReportReceipt report(CurrentUser actor, String placeId, PlaceDtos.CreateReportRequest body) {
        long id = ExternalIds.parse(placeId, "plc", ErrorCode.PLACE_NOT_FOUND);
        return places.reportPlace(actor.userId(), id, body);
    }

    private void ensureDetail(PlaceRepository.PlaceRecord place, String language) {
        if (places.hasDetail(place.id(), language)) return;
        if (place.contentId() == null) {
            places.upsertDetail(place.id(), language, new TourPlaceDetailClient.Detail(null, null, null, null, null));
            return;
        }
        try {
            TourPlaceDetailClient.Detail loaded = details.load(place.contentId(), language);
            if (loaded != null) places.upsertDetail(place.id(), language, loaded);
        } catch (RuntimeException e) {
            if ("ko".equals(language)) throw new ApiException(ErrorCode.COMMON_503);
        }
    }

    private static int validSize(int size) {
        if (size < 1 || size > MAX_PAGE) throw new ApiException(ErrorCode.COMMON_400);
        return size;
    }

    private static void validCoordinate(double lat, double lng) {
        if (!Double.isFinite(lat) || !Double.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180)
            throw new ApiException(ErrorCode.PLACE_INVALID_COORDINATE);
    }

    private static String language(String value) {
        if (value == null) return "ko";
        String first = value.split(",", 2)[0].trim().toLowerCase(Locale.ROOT);
        if (first.startsWith("en")) return "en";
        if (first.startsWith("ja")) return "ja";
        if (first.startsWith("zh")) return first.contains("cn") || first.contains("hans") ? "zh-CN" : "zh-TW";
        return "ko";
    }

    private static <T> CursorPage<T> page(List<T> rows, int size, java.util.function.ToLongFunction<T> id) {
        boolean hasNext = rows.size() > size;
        List<T> items = hasNext ? rows.subList(0, size) : rows;
        String next = hasNext && !items.isEmpty() ? CursorCodec.encode(id.applyAsLong(items.get(items.size() - 1))) : null;
        return new CursorPage<>(List.copyOf(items), next, hasNext);
    }
}
