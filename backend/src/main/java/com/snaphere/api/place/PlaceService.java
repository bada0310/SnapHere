package com.snaphere.api.place;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.web.CursorCodec;
import com.snaphere.api.common.web.CursorPage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.ZonedDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Locale;

@Service
public class PlaceService {
    private static final Logger log = LoggerFactory.getLogger(PlaceService.class);
    private static final int MAX_PAGE = 50;
    private final PlaceRepository places;
    private final TourPlaceDetailClient details;
    private final ViewCounterService views;
    private final RecentPlaceService recentPlaces;
    private final PlaceReadCache cache;
    private final GoogleGeocodingClient geocoder;

    public PlaceService(PlaceRepository places,
                        TourPlaceDetailClient details, ViewCounterService views,
                        RecentPlaceService recentPlaces, PlaceReadCache cache,
                        GoogleGeocodingClient geocoder) {
        this.places = places;
        this.details = details;
        this.views = views;
        this.recentPlaces = recentPlaces;
        this.cache = cache;
        this.geocoder = geocoder;
    }

    public List<PlaceDtos.Region> regions() {
        return cache.regions().orElseGet(() -> {
            List<PlaceDtos.Region> value = places.regions(); cache.putRegions(value); return value;
        });
    }
    public List<PlaceDtos.Sigungu> sigungu(int areaCode) {
        return cache.sigungu(areaCode).orElseGet(() -> {
            List<PlaceDtos.Sigungu> value = places.sigungu(areaCode); cache.putSigungu(areaCode,value); return value;
        });
    }

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

    public PlaceDtos.NearestPlaceMatchResult nearestMatch(
            PlaceDtos.NearestPlaceMatchRequest request, CurrentUser actor) {
        validCoordinate(request.lat(), request.lng());
        // 사진의 원래 좌표에서 계산한 거리 순서로 추천한다. 역지오코딩 좌표나
        // 이름 유사도는 장소 선택 순서를 바꾸지 않는다.
        List<PlaceDtos.PlaceSummary> candidates = places.nearby(
                request.lat(), request.lng(), 20_000, 20, actor.userId());
        return new PlaceDtos.NearestPlaceMatchResult(null, null, candidates);
    }

    public PlaceDtos.PlaceDetail detail(String externalId, String acceptLanguage, CurrentUser actor) {
        long id = ExternalIds.parse(externalId, "plc", ErrorCode.PLACE_NOT_FOUND);
        PlaceRepository.PlaceRecord place = places.placeRecord(id);
        String language = language(acceptLanguage);
        ensureDetail(place, language);
        PlaceRepository.DetailRecord live = places.detail(id, language);
        PlaceReadCache.DetailContent content = cachedDetail(id,language,live);
        PlaceRepository.DetailRecord detail = new PlaceRepository.DetailRecord(content.overview(),content.tel(),content.homepage(),live.verifyRadiusM(),live.viewCount());
        if (detail.overview() == null && !"ko".equals(language)) {
            ensureDetail(place, "ko");
            live = places.detail(id, "ko");
            content = cachedDetail(id,"ko",live);
            detail = new PlaceRepository.DetailRecord(content.overview(),content.tel(),content.homepage(),live.verifyRadiusM(),live.viewCount());
            language = "ko";
        }
        java.util.UUID viewer = actor == null ? null : actor.userId();
        PlaceDtos.PlaceSummary summary = places.summary(id, viewer);
        // 부가 섹션의 조회 실패가 장소 기본 정보를 가리지 않게 한다. 상세 화면은
        // 장소명·주소·인증 반경만으로도 열 수 있고, 주변 장소·최근 글은 다음 진입에서
        // 다시 보강된다.
        List<PlaceDtos.PlaceSummary> nearby = summary.lat() == null ? List.of() : optional(
                "주변 장소", id, () -> places.nearby(summary.lat(), summary.lng(), 5000, 7, viewer)
                        .stream().filter(p -> !p.placeId().equals(externalId)).limit(6).toList(), List.of());
        List<PlaceDtos.PostSummary> recent = optional(
                "최근 게시글", id, () -> places.posts(id, null, 12, viewer), List.of());
        long totalViews = detail.viewCount() + views.pending(id) + 1;
        views.increment(id);
        // 최근 본 장소 (VST-006). 비회원은 남길 곳이 없어 건너뛴다.
        recentPlaces.record(viewer, id);
        return new PlaceDtos.PlaceDetail(summary, detail.overview(), language, detail.tel(), detail.homepage(),
                detail.verifyRadiusM(), totalViews,
                optional("장소 랭킹", id, () -> places.ranking(id), null), nearby, recent);
    }

    private <T> T optional(String section, long placeId, java.util.function.Supplier<T> load,
                           T fallback) {
        try {
            return load.get();
        } catch (RuntimeException failure) {
            log.warn("장소 상세의 {} 조회 실패. 기본 정보로 응답한다. placeId={}, type={}",
                    section, placeId, failure.getClass().getSimpleName());
            return fallback;
        }
    }

    private PlaceReadCache.DetailContent cachedDetail(long id, String language,
                                                       PlaceRepository.DetailRecord live) {
        return cache.detail(id,language).orElseGet(() -> {
            PlaceReadCache.DetailContent value = new PlaceReadCache.DetailContent(
                    live.overview(),live.tel(),live.homepage());
            cache.putDetail(id,language,value);
            return value;
        });
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
            cache.evictDetail(place.id(),language);
            return;
        }
        try {
            TourPlaceDetailClient.Detail loaded = details.load(place.contentId(), language);
            if (loaded != null) {
                places.upsertDetail(place.id(), language, loaded);
                cache.evictDetail(place.id(),language);
            }
        } catch (RuntimeException e) {
            // 관광 API의 부가정보 장애가 내부 DB에 이미 저장된 장소명·주소·사진까지
            // 가리지 않게 한다. 빈 상세를 저장하지 않아 다음 요청에서 다시 보강한다.
            log.warn("장소 부가정보 보강 실패. 기본 정보로 응답한다. placeId={}, language={}, type={}",
                    place.id(), language, e.getClass().getSimpleName());
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
