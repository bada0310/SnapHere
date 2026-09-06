package com.snaphere.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.simple.JdbcClient;
import com.snaphere.api.map.MapAggregationService;
import com.snaphere.api.map.MapPeriod;
import com.snaphere.api.ranking.RankingAggregationService;
import com.snaphere.api.ranking.RankingPlaceType;
import com.snaphere.api.ranking.RankingPeriod;
import com.snaphere.api.ranking.RankingRepository;
import com.snaphere.api.ranking.RankingScope;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import java.util.UUID;

@SpringBootTest(properties = {
        "snaphere.jobs.enabled=false",
        "snaphere.jobs.place-sync-cron=-",
        "snaphere.jobs.view-flush-cron=-"
})
@Testcontainers(disabledWithoutDocker = true)
class PlaceSchemaIntegrationTests {
    @Container
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("percona/percona-distribution-postgresql-with-postgis:17.10-5")
                    .asCompatibleSubstituteFor("postgres"));
    @Container
    static final GenericContainer<?> REDIS = new GenericContainer<>(DockerImageName.parse("redis:7.4-alpine"))
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
    }

    @Autowired JdbcClient jdbc;
    @Autowired MapAggregationService mapAggregation;
    @Autowired RankingAggregationService rankingAggregation;
    @Autowired RankingRepository rankingRepository;
    @Autowired com.snaphere.api.place.PlaceRepository placeJdbcRepository;

    @Test
    void 시도_코드는_비연속_17개이고_고정된_DB_버전과_PostGIS가_활성화된다() {
        assertThat(jdbc.sql("SELECT area_code FROM regions ORDER BY area_code").query(Integer.class).list())
                .containsExactly(1,2,3,4,5,6,7,8,31,32,33,34,35,36,37,38,39);
        assertThat(jdbc.sql("SHOW server_version").query(String.class).single()).startsWith("17.10");
        assertThat(jdbc.sql("SELECT PostGIS_Lib_Version()").query(String.class).single()).isEqualTo("3.5.7");
        assertThat(jdbc.sql("SELECT to_regclass('public.heatmap_cells') IS NOT NULL").query(Boolean.class).single()).isTrue();
        assertThat(jdbc.sql("SELECT to_regclass('public.region_stats') IS NOT NULL").query(Boolean.class).single()).isTrue();
    }

    @Test
    void 게시글을_네_격자와_지역_통계로_사전_집계한다() {
        UUID userId = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO users(id,google_subject,email,status,role,created_at,updated_at)
                VALUES (:id,:subject,'map@example.com','ACTIVE','USER',now(),now())
                """).param("id", userId).param("subject", "map-" + userId).update();
        long placeId = jdbc.sql("""
                INSERT INTO places(place_type,title,normalized_title,lat,lng,verify_radius_m,area_code)
                VALUES ('OFFICIAL','지도 테스트','지도 테스트',37.55,126.99,500,1) RETURNING place_id
                """).query(Long.class).single();
        long postId = jdbc.sql("""
                INSERT INTO posts(user_id,place_id,area_code,tier,lat,lng,status,created_at,updated_at)
                VALUES (:user,:place,1,'HIGH',37.55,126.99,'ACTIVE',now(),now()) RETURNING post_id
                """).param("user", userId).param("place", placeId).query(Long.class).single();
        jdbc.sql("""
                INSERT INTO post_images(post_id,image_key,thumbnail_url,sort_order)
                VALUES (:post,'posts/map-test.jpg','https://cdn.example/map-thumb.jpg',1)
                """).param("post", postId).update();

        assertThat(placeJdbcRepository.posts(placeId, null, 10, null))
                .singleElement()
                .satisfies(post -> assertThat(post.aspectRatio()).isEqualTo(1.0));

        mapAggregation.rebuild(MapPeriod.WEEKLY);

        assertThat(jdbc.sql("SELECT count(*) FROM heatmap_cells WHERE period='WEEKLY'")
                .query(Long.class).single()).isEqualTo(4);
        assertThat(jdbc.sql("SELECT sample_post_ids[1] FROM heatmap_cells WHERE period='WEEKLY' AND grid_level=2")
                .query(Long.class).single()).isEqualTo(postId);
        assertThat(jdbc.sql("SELECT sample_thumbnail_urls[1] FROM heatmap_cells WHERE period='WEEKLY' AND grid_level=2")
                .query(String.class).single()).isEqualTo("https://cdn.example/map-thumb.jpg");
        assertThat(jdbc.sql("SELECT post_count FROM region_stats WHERE area_code=1 AND period='WEEKLY'")
                .query(Integer.class).single()).isEqualTo(1);
    }

    @Test
    void 장소_랭킹을_범위와_장소유형별로_사전_집계하고_직전순위를_보관한다() {
        UUID userId = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO users(id,google_subject,email,status,role,created_at,updated_at)
                VALUES (:id,:subject,:email,'ACTIVE','USER',now(),now())
                """).param("id", userId).param("subject", "rank-" + userId)
                .param("email", "rank-" + userId + "@example.com").update();
        long official = jdbc.sql("""
                INSERT INTO places(place_type,title,normalized_title,lat,lng,verify_radius_m,area_code,
                                   visit_count,view_count,is_curated)
                VALUES ('OFFICIAL','랭킹 공식','랭킹 공식',37.5,127.0,500,31,3,20,true)
                RETURNING place_id
                """).query(Long.class).single();
        long userPlace = jdbc.sql("""
                INSERT INTO places(place_type,title,normalized_title,lat,lng,verify_radius_m,area_code)
                VALUES ('USER','랭킹 사용자','랭킹 사용자',37.6,127.1,100,31)
                RETURNING place_id
                """).query(Long.class).single();
        long officialPost = insertRankingPost(userId, official, "HIGH", 2, 1);
        long userPost = insertRankingPost(userId, userPlace, "LOW", 0, 0);
        jdbc.sql("INSERT INTO likes(user_id,target_type,target_id) VALUES (:user,'POST',:post)")
                .param("user", userId).param("post", officialPost).update();
        long tagId = jdbc.sql("""
                INSERT INTO tags(name,normalized_name,theme_code) VALUES ('케이팝',:name,'KPOP')
                RETURNING tag_id
                """).param("name", "kpop-" + userId).query(Long.class).single();
        jdbc.sql("INSERT INTO post_tags(post_id,tag_id) VALUES (:post,:tag)")
                .param("post", officialPost).param("tag", tagId).update();

        rankingAggregation.rebuild(RankingPeriod.WEEKLY);

        assertThat(jdbc.sql("""
                SELECT score FROM place_rankings
                 WHERE place_id=:place AND period='WEEKLY' AND theme='ALL'
                   AND scope='REGION' AND place_type='ALL'
                """).param("place", official).query(String.class).single()).isEqualTo("12.5000");
        assertThat(jdbc.sql("""
                SELECT rank_no FROM place_rankings
                 WHERE place_id=:place AND period='WEEKLY' AND theme='KPOP'
                   AND scope='REGION' AND place_type='OFFICIAL'
                """).param("place", official).query(Integer.class).single()).isEqualTo(1);
        assertThat(jdbc.sql("""
                SELECT rank_no FROM place_rankings
                 WHERE place_id=:place AND period='WEEKLY' AND theme='ALL'
                   AND scope='REGION' AND place_type='USER'
                """).param("place", userPlace).query(Integer.class).single()).isEqualTo(1);

        jdbc.sql("UPDATE posts SET like_count=100 WHERE post_id=:post")
                .param("post", userPost).update();
        rankingAggregation.rebuild(RankingPeriod.WEEKLY);

        assertThat(jdbc.sql("""
                SELECT rank_no,previous_rank FROM place_rankings
                 WHERE place_id=:place AND period='WEEKLY' AND theme='ALL'
                   AND scope='REGION' AND place_type='ALL'
                """).param("place", userPlace).query((rs, row) ->
                java.util.List.of(rs.getInt(1), rs.getInt(2))).single()).containsExactly(1, 2);
        assertThat(rankingRepository.rankings(RankingScope.REGION, 31, RankingPeriod.WEEKLY,
                "ALL", RankingPlaceType.ALL, null, 10, null))
                .extracting(row -> row.place().placeId())
                .startsWith(com.snaphere.api.auth.ExternalIds.place(userPlace));
        assertThat(rankingRepository.recommendations(31, null, null, 10, null)).isNotEmpty();
        assertThat(rankingRepository.recommendations(31, 37.5, 127.0, 10, null))
                .allSatisfy(row -> assertThat(row.place().distanceM()).isNotNull().isLessThanOrEqualTo(20_000));
        assertThat(rankingRepository.curated(31, null, null, 10, null))
                .extracting(row -> row.place().placeId())
                .contains(com.snaphere.api.auth.ExternalIds.place(official));
    }

    private long insertRankingPost(UUID userId, long placeId, String tier, int likes, int comments) {
        return jdbc.sql("""
                INSERT INTO posts(user_id,place_id,area_code,tier,like_count,comment_count,status,
                                  created_at,updated_at)
                VALUES (:user,:place,31,:tier,:likes,:comments,'ACTIVE',now(),now())
                RETURNING post_id
                """).param("user", userId).param("place", placeId).param("tier", tier)
                .param("likes", likes).param("comments", comments).query(Long.class).single();
    }
}
