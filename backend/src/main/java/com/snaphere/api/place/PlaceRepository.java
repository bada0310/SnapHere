package com.snaphere.api.place;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;

@Repository("placeJdbcRepository")
public class PlaceRepository {
    private final JdbcClient jdbc;

    public PlaceRepository(JdbcClient jdbc) { this.jdbc = jdbc; }

    public List<PlaceDtos.Region> regions() {
        return jdbc.sql("SELECT area_code,name_ko,name_en,representative_image_url,coalesce(default_event_verify_radius_m,2000) FROM regions ORDER BY area_code")
                .query((rs, n) -> new PlaceDtos.Region(rs.getInt(1), rs.getString(2), rs.getString(3),
                        rs.getString(4), rs.getInt(5))).list();
    }

    public List<PlaceDtos.Sigungu> sigungu(int areaCode) {
        return jdbc.sql("SELECT area_code,sigungu_code,name_ko,name_en FROM sigungu WHERE area_code=:area ORDER BY sigungu_code")
                .param("area", areaCode).query((rs, n) -> new PlaceDtos.Sigungu(
                        rs.getInt(1), rs.getInt(2), rs.getString(3), rs.getString(4))).list();
    }

    public List<PlaceDtos.PlaceSummary> list(Integer areaCode, Integer sigunguCode, Integer contentTypeId,
                                              String keyword, Long after, int limit, UUID viewer) {
        StringBuilder sql = new StringBuilder(basePlaceSelect(viewer, false)).append(" WHERE p.status='ACTIVE'");
        Map<String, Object> params = new HashMap<>();
        if (areaCode != null) { sql.append(" AND p.area_code=:area"); params.put("area", areaCode); }
        if (sigunguCode != null) { sql.append(" AND p.sigungu_code=:sigungu"); params.put("sigungu", sigunguCode); }
        if (contentTypeId != null) { sql.append(" AND p.content_type_id=:type"); params.put("type", contentTypeId); }
        if (keyword != null && !keyword.isBlank()) {
            sql.append(" AND (p.normalized_title LIKE '%'||:keyword||'%' OR lower(coalesce(p.addr1,'')) LIKE '%'||lower(:rawKeyword)||'%')");
            params.put("keyword", normalizeTitle(keyword)); params.put("rawKeyword", keyword.trim());
        }
        if (after != null) { sql.append(" AND p.place_id>:after"); params.put("after", after); }
        sql.append(" ORDER BY p.place_id LIMIT :limit"); params.put("limit", limit);
        JdbcClient.StatementSpec spec = jdbc.sql(sql.toString()).params(params);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, n) -> mapPlace(rs)).list();
    }

    public List<PlaceDtos.PlaceSummary> nearby(double lat, double lng, int radiusM, int limit, UUID viewer) {
        String sql = basePlaceSelect(viewer, true) + """
                WHERE p.status='ACTIVE' AND p.has_coordinate=true
                  AND ST_DWithin(p.geom, ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography, :radius)
                ORDER BY distance_m,p.place_id LIMIT :limit
                """;
        JdbcClient.StatementSpec spec = jdbc.sql(sql).param("lat", lat).param("lng", lng)
                .param("radius", radiusM).param("limit", limit);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, n) -> mapPlace(rs)).list();
    }

    public Integer nearestDistance(double lat, double lng) {
        return jdbc.sql("""
                SELECT round(ST_Distance(p.geom, ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography))::int
                FROM places p
                WHERE p.status='ACTIVE' AND p.has_coordinate=true
                ORDER BY p.geom <-> ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography, p.place_id
                LIMIT 1
                """).param("lat", lat).param("lng", lng).query(Integer.class).optional().orElse(null);
    }

    public PlaceRecord placeRecord(long placeId) {
        return jdbc.sql("""
                SELECT place_id,place_type,content_id,title,area_code,sigungu_code,verify_radius_m,view_count,status
                FROM places WHERE place_id=:id AND status='ACTIVE'
                """).param("id", placeId).query((rs, n) -> new PlaceRecord(rs.getLong(1), rs.getString(2),
                        rs.getString(3), rs.getString(4), rs.getInt(5), (Integer) rs.getObject(6),
                        rs.getInt(7), rs.getLong(8))).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND));
    }

    public PlaceDtos.PlaceSummary summary(long placeId, UUID viewer) {
        JdbcClient.StatementSpec spec = jdbc.sql(basePlaceSelect(viewer, false) + " WHERE p.place_id=:id AND p.status='ACTIVE'")
                .param("id", placeId);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, n) -> mapPlace(rs)).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND));
    }

    public DetailRecord detail(long placeId, String language) {
        return jdbc.sql("""
                SELECT d.overview,d.tel,d.homepage,p.verify_radius_m,p.view_count
                FROM places p LEFT JOIN place_details d ON d.place_id=p.place_id AND d.language_code=:language
                WHERE p.place_id=:id AND p.status='ACTIVE'
                """).param("language", language).param("id", placeId)
                .query((rs, n) -> new DetailRecord(rs.getString(1), rs.getString(2), rs.getString(3),
                        rs.getInt(4), rs.getLong(5))).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND));
    }

    public boolean hasDetail(long placeId, String language) {
        return jdbc.sql("SELECT EXISTS(SELECT 1 FROM place_details WHERE place_id=:id AND language_code=:language)")
                .param("id", placeId).param("language", language).query(Boolean.class).single();
    }

    public void upsertDetail(long placeId, String language, TourPlaceDetailClient.Detail detail) {
        jdbc.sql("""
                INSERT INTO place_details(place_id,language_code,overview,tel,homepage,use_time,rest_date)
                VALUES (:id,:language,:overview,:tel,:homepage,:useTime,:restDate)
                ON CONFLICT(place_id,language_code) DO UPDATE SET overview=excluded.overview,tel=excluded.tel,
                  homepage=excluded.homepage,use_time=excluded.use_time,rest_date=excluded.rest_date,loaded_at=now()
                """).param("id", placeId).param("language", language).param("overview", detail.overview())
                .param("tel", detail.tel()).param("homepage", detail.homepage())
                .param("useTime", detail.useTime()).param("restDate", detail.restDate()).update();
    }

    public PlaceDtos.RankingEntry ranking(long placeId) {
        return jdbc.sql("""
                SELECT rank_no,previous_rank,score,period,theme FROM place_rankings
                WHERE place_id=:id AND scope='NATIONAL' AND place_type='ALL' AND theme='ALL'
                ORDER BY CASE period WHEN 'WEEKLY' THEN 0 ELSE 1 END, calculated_at DESC LIMIT 1
                """).param("id", placeId).query((rs, n) -> new PlaceDtos.RankingEntry(rs.getInt(1),
                        (Integer) rs.getObject(2), rs.getBigDecimal(3), rs.getString(4), null))
                .optional().orElse(null);
    }

    public List<PlaceDtos.PostSummary> posts(long placeId, Long after, int limit, UUID viewer) {
        String cursor = after == null ? "" : " AND po.post_id<:after";
        String sql = """
                SELECT po.post_id,u.id user_id,u.nickname,u.profile_image_url,
                       p.place_id,p.place_type,p.title,p.addr1,p.image_url,
                       ST_Y(p.geom::geometry) lat,ST_X(p.geom::geometry) lng,p.post_count,p.visit_count,
                       pi.thumbnail_url,
                       (SELECT count(*) FROM post_images x WHERE x.post_id=po.post_id) image_count,
                       coalesce(pi.aspect_ratio,1) aspect_ratio,po.tier,po.like_count,po.comment_count,po.created_at,
                       CASE WHEN CAST(:viewer AS UUID) IS NULL THEN NULL ELSE EXISTS(
                         SELECT 1 FROM bookmarks b WHERE b.user_id=:viewer AND b.target_type='POST' AND b.target_id=po.post_id) END bookmarked
                FROM posts po JOIN users u ON u.id=po.user_id JOIN places p ON p.place_id=po.place_id
                LEFT JOIN post_images pi ON pi.post_id=po.post_id AND pi.sort_order=1
                WHERE po.place_id=:place AND po.status='ACTIVE'
                """ + cursor + " ORDER BY po.post_id DESC LIMIT :limit";
        JdbcClient.StatementSpec spec = jdbc.sql(sql).param("place", placeId).param("limit", limit);
        if (after != null) spec = spec.param("after", after);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, n) -> mapPost(rs)).list();
    }

    public AreaCodes resolveArea(String region, String district) {
        Integer area = jdbc.sql("SELECT area_code FROM regions WHERE name_ko=:name OR name_ko LIKE :prefix LIMIT 1")
                .param("name", region).param("prefix", region + "%").query(Integer.class).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_OUT_OF_SERVICE_AREA));
        Integer sigungu = null;
        if (district != null) {
            sigungu = jdbc.sql("""
                    SELECT sigungu_code FROM sigungu WHERE area_code=:area
                      AND lower(name_ko)=:name LIMIT 1
                    """).param("area", area).param("name", district).query(Integer.class).optional().orElse(null);
        }
        return new AreaCodes(area, sigungu);
    }

    public void lockDuplicateKey(String normalizedTitle) {
        jdbc.sql("SELECT pg_advisory_xact_lock(hashtext(:key))").param("key", normalizedTitle).query(Long.class).single();
    }

    public Long duplicate(String normalizedTitle, double lat, double lng) {
        return jdbc.sql("""
                SELECT place_id FROM places WHERE status='ACTIVE' AND normalized_title=:title AND has_coordinate=true
                  AND ST_DWithin(geom,ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography,100)
                ORDER BY ST_Distance(geom,ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography),place_id LIMIT 1
                """).param("title", normalizedTitle).param("lat", lat).param("lng", lng)
                .query(Long.class).optional().orElse(null);
    }

    public long userPlaceCountToday(UUID userId) {
        return jdbc.sql("""
                SELECT count(*) FROM places WHERE created_by=:user AND place_type='USER'
                  AND created_at >= (date_trunc('day',now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul')
                """).param("user", userId).query(Long.class).single();
    }

    public long insertUserPlace(UUID userId, PlaceDtos.CreatePlaceRequest body, String normalized,
                                AreaCodes area) {
        return jdbc.sql("""
                INSERT INTO places(place_type,title,normalized_title,addr1,lat,lng,verify_radius_m,
                  area_code,sigungu_code,created_by)
                VALUES ('USER',:title,:normalized,:addr,
                  :lat,:lng,100,:area,:sigungu,:user)
                RETURNING place_id
                """).param("title", body.title().trim()).param("normalized", normalized)
                .param("addr", body.addr1()).param("lng", body.lng()).param("lat", body.lat())
                .param("area", area.areaCode()).param("sigungu", area.sigunguCode(), Types.INTEGER)
                .param("user", userId).query(Long.class).single();
    }

    public OffsetDateTime bookmark(UUID userId, long placeId) {
        placeRecord(placeId);
        jdbc.sql("""
                INSERT INTO bookmarks(user_id,target_type,target_id) VALUES (:user,'PLACE',:place)
                ON CONFLICT DO NOTHING
                """).param("user", userId).param("place", placeId).update();
        return jdbc.sql("SELECT created_at FROM bookmarks WHERE user_id=:user AND target_type='PLACE' AND target_id=:place")
                .param("user", userId).param("place", placeId).query(OffsetDateTime.class).single();
    }

    public void unbookmark(UUID userId, long placeId) {
        jdbc.sql("DELETE FROM bookmarks WHERE user_id=:user AND target_type='PLACE' AND target_id=:place")
                .param("user", userId).param("place", placeId).update();
    }

    public List<PlaceDtos.PlaceSummary> bookmarkedPlaces(UUID userId, Long after, int limit) {
        String cursor = after == null ? "" : " AND p.place_id<:after";
        String sql = basePlaceSelect(userId, false) + """
                JOIN bookmarks saved ON saved.target_id=p.place_id AND saved.target_type='PLACE' AND saved.user_id=:user
                WHERE p.status='ACTIVE'
                """ + cursor + " ORDER BY p.place_id DESC LIMIT :limit";
        JdbcClient.StatementSpec spec = jdbc.sql(sql).param("viewer", userId).param("user", userId).param("limit", limit);
        if (after != null) spec = spec.param("after", after);
        return spec.query((rs, n) -> mapPlace(rs)).list();
    }

    public PlaceDtos.TagSuggestion placeTag(long placeId) {
        PlaceRecord place = placeRecord(placeId);
        String normalized = normalizeTag(place.title());
        TagRow tag = jdbc.sql("SELECT tag_id,name,normalized_name FROM tags WHERE normalized_name=:name")
                .param("name", normalized).query((rs, n) -> new TagRow(rs.getLong(1), rs.getString(2), rs.getString(3)))
                .optional().orElse(null);
        return tag == null ? new PlaceDtos.TagSuggestion(place.title(), normalized, null, "NEW")
                : new PlaceDtos.TagSuggestion(tag.name(), tag.normalized(), ExternalIds.tag(tag.id()), "EXISTING");
    }

    public List<PlaceDtos.TagSuggestion> tagSuggestions(long placeId, String query, int limit) {
        PlaceDtos.TagSuggestion placeTag = placeTag(placeId);
        String normalizedQuery = query == null ? "" : normalizeTag(query);
        List<PlaceDtos.TagSuggestion> rest = jdbc.sql("""
                SELECT tag_id,name,normalized_name FROM tags WHERE normalized_name<>:place
                  AND normalized_name LIKE :prefix||'%' ORDER BY usage_count DESC,tag_id LIMIT :limit
                """).param("place", placeTag.normalizedName()).param("prefix", normalizedQuery).param("limit", limit - 1)
                .query((rs, n) -> new PlaceDtos.TagSuggestion(rs.getString(2), rs.getString(3),
                        ExternalIds.tag(rs.getLong(1)), "EXISTING")).list();
        List<PlaceDtos.TagSuggestion> result = new ArrayList<>(); result.add(placeTag); result.addAll(rest); return result;
    }

    public void addViewCount(long placeId, long delta) {
        jdbc.sql("UPDATE places SET view_count=view_count+:delta WHERE place_id=:id")
                .param("delta", delta).param("id", placeId).update();
    }

    public PlaceDtos.ReportReceipt reportPlace(UUID userId, long placeId, PlaceDtos.CreateReportRequest body) {
        placeRecord(placeId);
        try {
            ReportRow row = jdbc.sql("""
                    INSERT INTO reports(reporter_id,target_type,target_id,reason,detail)
                    VALUES (:user,'PLACE',:place,:reason,:detail)
                    RETURNING report_id,status,created_at
                    """).param("user", userId).param("place", placeId).param("reason", body.reason())
                    .param("detail", body.detail()).query((rs, n) -> new ReportRow(rs.getLong(1),
                            rs.getString(2), rs.getObject(3, OffsetDateTime.class))).single();
            long count = jdbc.sql("""
                    SELECT count(*) FROM reports WHERE target_type='PLACE' AND target_id=:place
                    """).param("place", placeId).query(Long.class).single();
            if (count >= 3) {
                jdbc.sql("UPDATE places SET status='HIDDEN',updated_at=now() WHERE place_id=:id AND status='ACTIVE'")
                        .param("id", placeId).update();
            }
            return new PlaceDtos.ReportReceipt(ExternalIds.report(row.id()), row.status(), row.createdAt());
        } catch (org.springframework.dao.DuplicateKeyException e) {
            throw new ApiException(ErrorCode.REPORT_DUPLICATE);
        }
    }

    private static String basePlaceSelect(UUID viewer, boolean distance) {
        String distanceColumns = distance ? "round(ST_Distance(p.geom,ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography))::int distance_m, CASE WHEN CAST(:viewer AS UUID) IS NULL THEN NULL ELSE (ST_Distance(p.geom,ST_SetSRID(ST_MakePoint(:lng,:lat),4326)::geography)<=p.verify_radius_m) END verifiable," : "NULL::integer distance_m,NULL::boolean verifiable,";
        return """
                SELECT p.place_id,p.place_type,p.title,p.addr1,p.image_url,
                  ST_Y(p.geom::geometry) lat,ST_X(p.geom::geometry) lng,p.post_count,p.visit_count,
                """ + distanceColumns + """
                  CASE WHEN CAST(:viewer AS UUID) IS NULL THEN NULL ELSE EXISTS(
                    SELECT 1 FROM bookmarks b WHERE b.user_id=:viewer AND b.target_type='PLACE' AND b.target_id=p.place_id) END bookmarked
                FROM places p
                """;
    }

    private static PlaceDtos.PlaceSummary mapPlace(ResultSet rs) throws SQLException {
        return new PlaceDtos.PlaceSummary(ExternalIds.place(rs.getLong("place_id")), rs.getString("place_type"),
                rs.getString("title"), rs.getString("addr1"), rs.getString("image_url"),
                (Double) rs.getObject("lat"), (Double) rs.getObject("lng"), rs.getInt("post_count"),
                rs.getInt("visit_count"), (Integer) rs.getObject("distance_m"),
                (Boolean) rs.getObject("verifiable"), (Boolean) rs.getObject("bookmarked"));
    }

    private static PlaceDtos.PostSummary mapPost(ResultSet rs) throws SQLException {
        PlaceDtos.PlaceSummary place = new PlaceDtos.PlaceSummary(ExternalIds.place(rs.getLong("place_id")),
                rs.getString("place_type"), rs.getString("title"), rs.getString("addr1"), rs.getString("image_url"),
                (Double) rs.getObject("lat"), (Double) rs.getObject("lng"), rs.getInt("post_count"),
                rs.getInt("visit_count"), null, null, null);
        return new PlaceDtos.PostSummary(ExternalIds.post(rs.getLong("post_id")),
                new PlaceDtos.UserSummary(rs.getObject("user_id", UUID.class).toString(), rs.getString("nickname"), rs.getString("profile_image_url")),
                place, rs.getString("thumbnail_url"), rs.getInt("image_count"), rs.getDouble("aspect_ratio"),
                rs.getString("tier"), rs.getInt("like_count"), rs.getInt("comment_count"),
                rs.getObject("created_at", OffsetDateTime.class), (Boolean) rs.getObject("bookmarked"));
    }

    public static String normalizeTitle(String value) { return value.trim().toLowerCase(Locale.ROOT).replaceAll("\\s+", " "); }
    public static String normalizeTag(String value) { return value.trim().toLowerCase(Locale.ROOT).replaceAll("[#\\s]+", ""); }

    public record PlaceRecord(long id, String type, String contentId, String title, int areaCode,
                              Integer sigunguCode, int verifyRadiusM, long viewCount) { }
    public record DetailRecord(String overview, String tel, String homepage, int verifyRadiusM, long viewCount) { }
    public record AreaCodes(int areaCode, Integer sigunguCode) { }
    private record TagRow(long id, String name, String normalized) { }
    private record ReportRow(long id, String status, OffsetDateTime createdAt) { }
}
