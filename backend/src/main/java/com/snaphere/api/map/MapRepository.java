package com.snaphere.api.map;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.place.PlaceDtos;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.sql.Array;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Repository
public class MapRepository {
    private static final String ELIGIBLE = """
            SELECT p.post_id,p.user_id,p.place_id,p.area_code,p.created_at,
                   coalesce(p.lat,pl.lat) AS lat,coalesce(p.lng,pl.lng) AS lng,
                   coalesce(pr.score,0) AS score,pi.thumbnail_url,
                   floor(coalesce(p.lat,pl.lat) * :factor)::int AS lat_index,
                   floor(coalesce(p.lng,pl.lng) * :factor)::int AS lng_index
            FROM posts p
            JOIN places pl ON pl.place_id=p.place_id AND pl.status='ACTIVE'
            LEFT JOIN post_rankings pr ON pr.post_id=p.post_id AND pr.period=:rankingPeriod
            LEFT JOIN LATERAL (
                SELECT thumbnail_url FROM post_images
                WHERE post_id=p.post_id ORDER BY sort_order LIMIT 1
            ) pi ON true
            WHERE p.status='ACTIVE'
              AND p.created_at>=:createdFrom
              AND coalesce(p.lat,pl.lat) IS NOT NULL AND coalesce(p.lng,pl.lng) IS NOT NULL
            """;

    private final JdbcClient jdbc;

    public MapRepository(JdbcClient jdbc) { this.jdbc = jdbc; }

    public void lockAggregation() {
        jdbc.sql("SELECT pg_advisory_xact_lock(2026090501)").query((rs, n) -> 0).single();
    }

    public int rebuildLevel(MapPeriod period, MapGrid grid, OffsetDateTime from, OffsetDateTime now) {
        jdbc.sql("DELETE FROM heatmap_cells WHERE period=:period AND grid_level=:level")
                .param("period", period.name()).param("level", grid.level()).update();
        int count = insertCells(period, grid, from, now, null, null);
        updateRefreshState(period, grid, now);
        return count;
    }

    public int rebuildCell(MapPeriod period, MapGrid grid, int latIndex, int lngIndex,
                           OffsetDateTime from, OffsetDateTime now) {
        jdbc.sql("""
                DELETE FROM heatmap_cells
                WHERE period=:period AND grid_level=:level AND lat_index=:latIndex AND lng_index=:lngIndex
                """).param("period", period.name()).param("level", grid.level())
                .param("latIndex", latIndex).param("lngIndex", lngIndex).update();
        return insertCells(period, grid, from, now, latIndex, lngIndex);
    }

    private int insertCells(MapPeriod period, MapGrid grid, OffsetDateTime from, OffsetDateTime now,
                            Integer latIndex, Integer lngIndex) {
        String cellFilter = latIndex == null ? "" : " AND lat_index=:latIndex AND lng_index=:lngIndex";
        String sql = """
                WITH eligible AS (
                """ + ELIGIBLE + """
                ), filtered AS (
                    SELECT * FROM eligible WHERE 1=1
                """ + cellFilter + """
                ), aggregate_rows AS (
                    SELECT lat_index,lng_index,count(*)::int post_count,
                           count(DISTINCT user_id)::int user_count,max(created_at) last_posted_at
                    FROM filtered GROUP BY lat_index,lng_index
                ), place_ranked AS (
                    SELECT lat_index,lng_index,place_id,
                           row_number() OVER (PARTITION BY lat_index,lng_index
                             ORDER BY count(*) DESC,max(created_at) DESC,place_id) AS position
                    FROM filtered GROUP BY lat_index,lng_index,place_id
                ), author_best AS (
                    SELECT *,row_number() OVER (PARTITION BY lat_index,lng_index,user_id
                             ORDER BY score DESC,created_at DESC,post_id DESC) AS author_position
                    FROM filtered
                ), candidates AS (
                    SELECT *,row_number() OVER (PARTITION BY lat_index,lng_index
                             ORDER BY score DESC,created_at DESC,post_id DESC) AS position
                    FROM author_best WHERE author_position=1
                ), candidate_arrays AS (
                    SELECT lat_index,lng_index,
                           array_agg(post_id ORDER BY position) FILTER (WHERE position<=10) AS post_ids,
                           array_agg(thumbnail_url ORDER BY position) FILTER (WHERE position<=10) AS thumbnail_urls
                    FROM candidates GROUP BY lat_index,lng_index
                )
                INSERT INTO heatmap_cells(period,grid_level,lat_index,lng_index,lat,lng,
                  post_count,visit_count,user_count,top_place_id,sample_post_ids,
                  sample_thumbnail_urls,last_posted_at,calculated_at)
                SELECT :period,:level,a.lat_index,a.lng_index,
                       (a.lat_index+0.5)/:factor::double precision,
                       (a.lng_index+0.5)/:factor::double precision,
                       a.post_count,0,a.user_count,p.place_id,
                       coalesce(c.post_ids,'{}'::bigint[]),coalesce(c.thumbnail_urls,'{}'::text[]),
                       a.last_posted_at,:calculatedAt
                FROM aggregate_rows a
                LEFT JOIN place_ranked p ON p.lat_index=a.lat_index AND p.lng_index=a.lng_index AND p.position=1
                LEFT JOIN candidate_arrays c ON c.lat_index=a.lat_index AND c.lng_index=a.lng_index
                """;
        JdbcClient.StatementSpec statement = jdbc.sql(sql)
                .param("factor", grid.factor()).param("rankingPeriod", period.rankingPeriod())
                .param("createdFrom", from).param("period", period.name())
                .param("level", grid.level()).param("calculatedAt", now);
        if (latIndex != null) statement = statement.param("latIndex", latIndex).param("lngIndex", lngIndex);
        return statement.update();
    }

    public int rebuildRegions(MapPeriod period, OffsetDateTime from, OffsetDateTime now, Integer areaCode) {
        String areaFilter = areaCode == null ? "" : " AND p.area_code=:areaCode";
        if (areaCode == null) {
            jdbc.sql("DELETE FROM region_stats WHERE period=:period").param("period", period.name()).update();
        } else {
            jdbc.sql("DELETE FROM region_stats WHERE period=:period AND area_code=:areaCode")
                    .param("period", period.name()).param("areaCode", areaCode).update();
        }
        String sql = """
                WITH eligible AS (
                    SELECT p.post_id,p.user_id,p.area_code,p.created_at,coalesce(pr.score,0) score
                    FROM posts p JOIN places pl ON pl.place_id=p.place_id AND pl.status='ACTIVE'
                    LEFT JOIN post_rankings pr ON pr.post_id=p.post_id AND pr.period=:rankingPeriod
                    WHERE p.status='ACTIVE' AND p.created_at>=:createdFrom
                """ + areaFilter + """
                ), ranked AS (
                    SELECT *,row_number() OVER (PARTITION BY area_code
                      ORDER BY score DESC,created_at DESC,post_id DESC) position FROM eligible
                )
                INSERT INTO region_stats(area_code,period,post_count,contributor_count,
                  representative_post_id,calculated_at)
                SELECT area_code,:period,count(*)::int,count(DISTINCT user_id)::int,
                       max(post_id) FILTER (WHERE position=1),:calculatedAt
                FROM ranked GROUP BY area_code
                """;
        JdbcClient.StatementSpec statement = jdbc.sql(sql).param("rankingPeriod", period.rankingPeriod())
                .param("createdFrom", from).param("period", period.name()).param("calculatedAt", now);
        if (areaCode != null) statement = statement.param("areaCode", areaCode);
        return statement.update();
    }

    private void updateRefreshState(MapPeriod period, MapGrid grid, OffsetDateTime now) {
        jdbc.sql("""
                INSERT INTO heatmap_refresh_state(period,grid_level,calculated_at,next_refresh_at)
                VALUES (:period,:level,:calculatedAt,:nextRefreshAt)
                ON CONFLICT(period,grid_level) DO UPDATE SET
                  calculated_at=excluded.calculated_at,next_refresh_at=excluded.next_refresh_at
                """).param("period", period.name()).param("level", grid.level())
                .param("calculatedAt", now).param("nextRefreshAt", now.plus(period.refreshInterval())).update();
    }

    public int viewportPostCount(MapPeriod period, MapGrid grid, MapDtos.Bounds bounds) {
        return jdbc.sql("""
                SELECT coalesce(sum(post_count),0)::int FROM heatmap_cells
                WHERE period=:period AND grid_level=:level
                  AND lng>=:west AND lng<=:east AND lat>=:south AND lat<=:north
                """).param("period", period.name()).param("level", grid.level())
                .param("west", bounds.west()).param("east", bounds.east())
                .param("south", bounds.south()).param("north", bounds.north())
                .query(Integer.class).single();
    }

    public List<CellRow> cells(MapPeriod period, MapGrid grid, MapDtos.Bounds bounds, int limit) {
        return jdbc.sql("""
                SELECT period,grid_level,lat_index,lng_index,lat,lng,post_count,visit_count,
                       user_count,top_place_id,sample_post_ids,sample_thumbnail_urls,last_posted_at,calculated_at
                FROM heatmap_cells
                WHERE period=:period AND grid_level=:level
                  AND lng>=:west AND lng<=:east AND lat>=:south AND lat<=:north
                ORDER BY post_count DESC,last_posted_at DESC,cell_id
                LIMIT :limit
                """).param("period", period.name()).param("level", grid.level())
                .param("west", bounds.west()).param("east", bounds.east())
                .param("south", bounds.south()).param("north", bounds.north()).param("limit", limit)
                .query((rs, n) -> new CellRow(MapPeriod.valueOf(rs.getString(1)), rs.getInt(2),
                        rs.getInt(3), rs.getInt(4), rs.getDouble(5), rs.getDouble(6), rs.getInt(7),
                        rs.getInt(8), rs.getInt(9), (Long) rs.getObject(10), longs(rs.getArray(11)),
                        strings(rs.getArray(12)), rs.getObject(13, OffsetDateTime.class),
                        rs.getObject(14, OffsetDateTime.class))).list();
    }

    public Optional<CellRow> cell(MapCellKey key) {
        MapGrid grid = new MapGrid(key.level(), switch (key.level()) { case 0 -> 1; case 1 -> 10; case 2 -> 100; default -> 1000; });
        double lat = grid.centerLat(key.latIndex());
        double lng = grid.centerLng(key.lngIndex());
        return cells(key.period(), grid, new MapDtos.Bounds(lng, lat, lng, lat), 1).stream().findFirst();
    }

    public OffsetDateTime nextRefreshAt(MapPeriod period, MapGrid grid, OffsetDateTime fallback) {
        return jdbc.sql("SELECT next_refresh_at FROM heatmap_refresh_state WHERE period=:period AND grid_level=:level")
                .param("period", period.name()).param("level", grid.level())
                .query(OffsetDateTime.class).optional().orElse(fallback.plus(period.refreshInterval()));
    }

    public List<RegionRow> regions(MapPeriod period) {
        return jdbc.sql("""
                SELECT r.area_code,r.name_ko,r.name_en,r.representative_image_url,
                       coalesce(r.default_event_verify_radius_m,2000),coalesce(s.post_count,0),
                       coalesce(s.contributor_count,0),s.representative_post_id
                FROM regions r LEFT JOIN region_stats s ON s.area_code=r.area_code AND s.period=:period
                ORDER BY r.area_code
                """).param("period", period.name()).query((rs,n) -> new RegionRow(
                        new PlaceDtos.Region(rs.getInt(1),rs.getString(2),rs.getString(3),rs.getString(4),rs.getInt(5)),
                        rs.getInt(6),rs.getInt(7),(Long)rs.getObject(8))).list();
    }

    public Optional<PostLocation> postLocation(long postId) {
        return jdbc.sql("""
                SELECT p.area_code,coalesce(p.lat,pl.lat),coalesce(p.lng,pl.lng),p.created_at,
                       p.status,p.tier FROM posts p JOIN places pl ON pl.place_id=p.place_id
                WHERE p.post_id=:postId
                """).param("postId",postId).query((rs,n)->new PostLocation(rs.getInt(1),
                        (Double)rs.getObject(2),(Double)rs.getObject(3),rs.getObject(4,OffsetDateTime.class),
                        rs.getString(5),rs.getString(6))).optional();
    }

    private static List<Long> longs(Array array) throws SQLException {
        if (array == null) return List.of();
        Object[] values = (Object[]) array.getArray();
        List<Long> result = new ArrayList<>(values.length);
        for (Object value : values) result.add(((Number)value).longValue());
        return List.copyOf(result);
    }

    private static List<String> strings(Array array) throws SQLException {
        if (array == null) return List.of();
        Object[] values = (Object[]) array.getArray();
        List<String> result = new ArrayList<>(values.length);
        for (Object value : values) result.add(value == null ? null : value.toString());
        return java.util.Collections.unmodifiableList(result);
    }

    public record CellRow(MapPeriod period,int level,int latIndex,int lngIndex,double lat,double lng,
                          int postCount,int visitCount,int userCount,Long topPlaceId,List<Long> samplePostIds,
                          List<String> sampleThumbnailUrls,OffsetDateTime lastPostedAt,OffsetDateTime calculatedAt) { }
    public record RegionRow(PlaceDtos.Region region,int postCount,int contributorCount,Long representativePostId) { }
    public record PostLocation(int areaCode,Double lat,Double lng,OffsetDateTime createdAt,String status,String tier) {
        boolean eligible() { return lat != null && lng != null && "ACTIVE".equals(status); }
    }
}
