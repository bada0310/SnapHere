package com.snaphere.api.ranking;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.place.PlaceDtos;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public class RankingRepository {
    private static final String PLACE_COLUMNS = """
            p.place_id,p.place_type as actual_place_type,p.title,p.addr1,p.image_url,
            p.lat,p.lng,p.post_count,p.visit_count,
            """;

    private final JdbcClient jdbc;

    public RankingRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public void lockAggregation() {
        jdbc.sql("select pg_advisory_xact_lock(hashtext('snaphere:place-ranking'))")
                .query((rs, rowNum) -> 0).single();
    }

    /** RNK-001, RNK-005~010: 점수와 모든 조회 차원을 한 번에 미리 계산한다. */
    public int upsert(RankingPeriod period, OffsetDateTime createdFrom, OffsetDateTime calculatedAt) {
        return jdbc.sql("""
                with self_likes as (
                    select l.target_id post_id,count(*) self_like_count
                      from likes l join posts owner on owner.post_id=l.target_id
                     where l.target_type='POST' and l.user_id=owner.user_id
                     group by l.target_id
                ), eligible_posts as (
                    select po.post_id,po.place_id,po.tier,
                           greatest(po.like_count-coalesce(sl.self_like_count,0),0) like_count,
                           po.comment_count
                      from posts po
                      left join self_likes sl on sl.post_id=po.post_id
                     where po.status='ACTIVE' and po.created_at>=:createdFrom
                ), themed_posts as (
                    select distinct pt.post_id,t.theme_code
                      from post_tags pt join tags t on t.tag_id=pt.tag_id
                     where t.theme_code is not null and btrim(t.theme_code)<>''
                       and upper(btrim(t.theme_code))<>'ALL'
                ), metrics as (
                    select ep.place_id,'ALL'::varchar as theme,
                           sum(case ep.tier when 'HIGH' then 3.0 when 'MEDIUM' then 1.8 else 0.5 end
                               + ep.like_count*1.0 + ep.comment_count*1.5) as activity_score
                      from eligible_posts ep group by ep.place_id
                    union all
                    select ep.place_id,upper(btrim(tp.theme_code)) as theme,
                           sum(case ep.tier when 'HIGH' then 3.0 when 'MEDIUM' then 1.8 else 0.5 end
                               + ep.like_count*1.0 + ep.comment_count*1.5) as activity_score
                      from eligible_posts ep join themed_posts tp on tp.post_id=ep.post_id
                     group by ep.place_id,upper(btrim(tp.theme_code))
                ), scores as (
                    select p.place_id,p.area_code,p.place_type,m.theme,
                           round((m.activity_score + p.visit_count*2.0 + p.view_count*0.05)::numeric,4) score
                      from metrics m join places p on p.place_id=m.place_id
                     where p.status='ACTIVE'
                ), dimensions as (
                    select s.place_id,s.area_code,s.theme,s.score,d.place_type
                      from scores s
                      cross join lateral (values ('ALL'::varchar),(s.place_type)) d(place_type)
                ), ranked as (
                    select d.place_id,d.area_code,:period period,d.theme,d.score,
                           row_number() over(partition by d.theme,d.place_type
                                             order by d.score desc,d.place_id asc)::int rank_no,
                           'NATIONAL'::varchar scope,d.place_type
                      from dimensions d
                    union all
                    select d.place_id,d.area_code,:period period,d.theme,d.score,
                           row_number() over(partition by d.area_code,d.theme,d.place_type
                                             order by d.score desc,d.place_id asc)::int rank_no,
                           'REGION'::varchar scope,d.place_type
                      from dimensions d
                )
                insert into place_rankings(place_id,area_code,period,theme,score,rank_no,
                                           previous_rank,calculated_at,scope,place_type)
                select place_id,area_code,period,theme,score,rank_no,null,:calculatedAt,scope,place_type
                  from ranked
                on conflict on constraint uk_place_rankings_dimension do update
                    set area_code=excluded.area_code,
                        score=excluded.score,
                        previous_rank=place_rankings.rank_no,
                        rank_no=excluded.rank_no,
                        calculated_at=excluded.calculated_at
                """).param("period", period.name()).param("createdFrom", createdFrom)
                .param("calculatedAt", calculatedAt).update();
    }

    public int deleteStale(RankingPeriod period, OffsetDateTime calculatedAt) {
        return jdbc.sql("delete from place_rankings where period=:period and calculated_at<>:calculatedAt")
                .param("period", period.name()).param("calculatedAt", calculatedAt).update();
    }

    public List<RankingRow> rankings(RankingScope scope, Integer areaCode, RankingPeriod period,
                                     String theme, RankingPlaceType placeType, Integer afterRank,
                                     int limit, UUID viewer) {
        String sql = """
                select r.rank_no,r.previous_rank,r.score,r.period,r.theme,
                """ + PLACE_COLUMNS + """
                       null::integer distance_m,
                       case when cast(:viewer as uuid) is null then null else exists(
                           select 1 from bookmarks b where b.user_id=:viewer and b.target_type='PLACE'
                             and b.target_id=p.place_id) end bookmarked
                  from place_rankings r join places p on p.place_id=r.place_id
                 where r.scope=:scope and r.period=:period and r.theme=:theme
                   and r.place_type=:placeType and p.status='ACTIVE'
                   and (:areaCode is null or r.area_code=:areaCode)
                   and (:afterRank is null or r.rank_no>:afterRank)
                 order by r.rank_no,r.place_id limit :limit
                """;
        JdbcClient.StatementSpec spec = jdbc.sql(sql)
                .param("scope", scope.name()).param("period", period.name()).param("theme", theme)
                .param("placeType", placeType.name()).param("limit", limit)
                .param("areaCode", areaCode, Types.INTEGER).param("afterRank", afterRank, Types.INTEGER);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, rowNum) -> mapRanking(rs)).list();
    }

    public List<RecommendationRow> recommendations(Integer areaCode, Double lat, Double lng,
                                                   int limit, UUID viewer) {
        boolean located = lat != null;
        String distance = located
                ? "round(st_distance(p.geom,st_setsrid(st_makepoint(:lng,:lat),4326)::geography))::int"
                : "null::integer";
        String nearby = located
                ? " and p.geom is not null and st_dwithin(p.geom,st_setsrid(st_makepoint(:lng,:lat),4326)::geography,20000)"
                : "";
        String sql = """
                select r.score,
                %s%s as distance_m,
                       case when cast(:viewer as uuid) is null then null else exists(
                           select 1 from bookmarks b where b.user_id=:viewer and b.target_type='PLACE'
                             and b.target_id=p.place_id) end bookmarked
                  from place_rankings r join places p on p.place_id=r.place_id
                 where r.scope=:scope and r.period='WEEKLY' and r.theme='ALL'
                   and r.place_type='ALL' and p.status='ACTIVE'
                   and (:areaCode is null or r.area_code=:areaCode)
                %s
                 order by (r.score*(0.90+random()*0.20)) desc,r.rank_no,r.place_id
                 limit :limit
                """.formatted(PLACE_COLUMNS, distance, nearby);
        JdbcClient.StatementSpec spec = jdbc.sql(sql)
                .param("scope", areaCode == null ? RankingScope.NATIONAL.name() : RankingScope.REGION.name())
                .param("areaCode", areaCode, Types.INTEGER).param("limit", limit);
        if (located) spec = spec.param("lat", lat).param("lng", lng);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, rowNum) -> mapRecommendation(rs)).list();
    }

    public List<RecommendationRow> curated(Integer areaCode, Double lat, Double lng,
                                           int limit, UUID viewer) {
        boolean located = lat != null;
        String distance = located
                ? "round(st_distance(p.geom,st_setsrid(st_makepoint(:lng,:lat),4326)::geography))::int"
                : "null::integer";
        String sql = """
                select 0::numeric score,
                %s%s as distance_m,
                       case when cast(:viewer as uuid) is null then null else exists(
                           select 1 from bookmarks b where b.user_id=:viewer and b.target_type='PLACE'
                             and b.target_id=p.place_id) end bookmarked
                  from places p
                 where p.status='ACTIVE' and p.is_curated=true
                   and (:areaCode is null or p.area_code=:areaCode)
                 order by random(),p.place_id limit :limit
                """.formatted(PLACE_COLUMNS, distance);
        JdbcClient.StatementSpec spec = jdbc.sql(sql)
                .param("areaCode", areaCode, Types.INTEGER).param("limit", limit);
        if (located) spec = spec.param("lat", lat).param("lng", lng);
        spec = viewer == null ? spec.param("viewer", null, Types.OTHER) : spec.param("viewer", viewer);
        return spec.query((rs, rowNum) -> mapRecommendation(rs)).list();
    }

    private static RankingRow mapRanking(ResultSet rs) throws SQLException {
        return new RankingRow(rs.getInt("rank_no"), (Integer) rs.getObject("previous_rank"),
                rs.getBigDecimal("score"), rs.getString("period"), rs.getString("theme"), mapPlace(rs));
    }

    private static RecommendationRow mapRecommendation(ResultSet rs) throws SQLException {
        return new RecommendationRow(rs.getBigDecimal("score"), mapPlace(rs));
    }

    private static PlaceDtos.PlaceSummary mapPlace(ResultSet rs) throws SQLException {
        return new PlaceDtos.PlaceSummary(ExternalIds.place(rs.getLong("place_id")),
                rs.getString("actual_place_type"), rs.getString("title"), rs.getString("addr1"),
                rs.getString("image_url"), (Double) rs.getObject("lat"), (Double) rs.getObject("lng"),
                rs.getInt("post_count"), rs.getInt("visit_count"),
                (Integer) rs.getObject("distance_m"), null, (Boolean) rs.getObject("bookmarked"));
    }

    public record RankingRow(int rank, Integer previousRank, BigDecimal score,
                             String period, String theme, PlaceDtos.PlaceSummary place) { }
    public record RecommendationRow(BigDecimal score, PlaceDtos.PlaceSummary place) { }
}
