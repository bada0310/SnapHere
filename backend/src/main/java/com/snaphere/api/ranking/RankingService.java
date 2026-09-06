package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.web.CursorCodec;
import com.snaphere.api.common.web.CursorPage;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;

@Service
public class RankingService {
    private static final int MAX_PAGE = 50;
    private static final int MAX_RECOMMENDATIONS = 30;
    private static final Pattern THEME_CODE = Pattern.compile("[A-Z0-9_-]{1,30}");

    private final RankingRepository rankings;

    public RankingService(RankingRepository rankings) {
        this.rankings = rankings;
    }

    public CursorPage<RankingDtos.RankingEntry> places(String scopeValue, Integer areaCode,
                                                        String periodValue, String themeValue,
                                                        String placeTypeValue, String cursor,
                                                        int size, CurrentUser viewer) {
        RankingScope scope = RankingScope.parse(scopeValue);
        if (scope == RankingScope.REGION && areaCode == null) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
        if (size < 1 || size > MAX_PAGE) throw new ApiException(ErrorCode.COMMON_400);

        RankingPeriod period = RankingPeriod.parse(periodValue);
        RankingPlaceType placeType = RankingPlaceType.parse(placeTypeValue);
        String theme = normalizeTheme(themeValue);
        Long decoded = CursorCodec.decode(cursor);
        if (decoded != null && (decoded < 1 || decoded > Integer.MAX_VALUE)) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
        Integer afterRank = decoded == null ? null : decoded.intValue();
        UUID viewerId = viewer == null ? null : viewer.userId();

        Integer effectiveAreaCode = scope == RankingScope.REGION ? areaCode : null;
        List<RankingRepository.RankingRow> rows = rankings.rankings(scope, effectiveAreaCode, period,
                theme, placeType, afterRank, size + 1, viewerId);
        boolean hasNext = rows.size() > size;
        List<RankingRepository.RankingRow> visible = hasNext ? rows.subList(0, size) : rows;
        List<RankingDtos.RankingEntry> items = visible.stream().map(RankingService::entry).toList();
        String next = hasNext && !visible.isEmpty()
                ? CursorCodec.encode(visible.getLast().rank()) : null;
        return new CursorPage<>(items, next, hasNext);
    }

    public List<RankingDtos.Recommendation> recommendations(Double lat, Double lng,
                                                             Integer areaCode, int limit,
                                                             CurrentUser viewer) {
        validateCoordinates(lat, lng);
        if (limit < 1 || limit > MAX_RECOMMENDATIONS) throw new ApiException(ErrorCode.COMMON_400);
        UUID viewerId = viewer == null ? null : viewer.userId();
        List<RankingRepository.RecommendationRow> rows =
                rankings.recommendations(areaCode, lat, lng, limit, viewerId);
        boolean curated = rows.isEmpty();
        if (curated) rows = rankings.curated(areaCode, lat, lng, limit, viewerId);

        final boolean fallback = curated;
        return rows.stream().map(row -> recommendation(row, areaCode, fallback)).toList();
    }

    private static RankingDtos.RankingEntry entry(RankingRepository.RankingRow row) {
        Integer change = row.previousRank() == null ? null : row.previousRank() - row.rank();
        String theme = "ALL".equals(row.theme()) ? null : row.theme();
        return new RankingDtos.RankingEntry(row.rank(), row.previousRank(), change, row.score(),
                row.place(), row.period(), theme);
    }

    private static RankingDtos.Recommendation recommendation(
            RankingRepository.RecommendationRow row, Integer areaCode, boolean curated) {
        if (curated) {
            return new RankingDtos.Recommendation(row.place(), "CURATED", Map.of(), row.score());
        }
        if (row.place().distanceM() != null) {
            return new RankingDtos.Recommendation(row.place(), "TRENDING_NEARBY",
                    Map.of("distanceM", row.place().distanceM()), row.score());
        }
        if (areaCode != null) {
            return new RankingDtos.Recommendation(row.place(), "TRENDING_IN_AREA",
                    Map.of("areaCode", areaCode), row.score());
        }
        return new RankingDtos.Recommendation(row.place(), "TRENDING", Map.of(), row.score());
    }

    private static String normalizeTheme(String value) {
        if (value == null || value.isBlank()) return "ALL";
        String normalized = value.trim().toUpperCase(Locale.ROOT);
        if (!THEME_CODE.matcher(normalized).matches()) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
        return normalized;
    }

    private static void validateCoordinates(Double lat, Double lng) {
        if ((lat == null) != (lng == null)) throw new ApiException(ErrorCode.COMMON_400);
        if (lat == null) return;
        if (!Double.isFinite(lat) || !Double.isFinite(lng)
                || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
    }
}
