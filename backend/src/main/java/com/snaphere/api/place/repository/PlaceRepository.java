package com.snaphere.api.place.repository;

import com.snaphere.api.place.PlaceStatus;
import com.snaphere.api.place.entity.PlaceEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

/**
 * 장소 조회.
 *
 * <p>공간 조건은 JPQL 로 표현할 수 없어 네이티브 쿼리로 둔다. {@code geom} 은
 * {@code geography} 라서 {@code ST_DWithin} 의 반경이 그대로 미터다 — 도(degree) 환산이 필요 없다.
 */
public interface PlaceRepository extends JpaRepository<PlaceEntity, Long> {

    Optional<PlaceEntity> findByPlaceIdAndStatus(Long placeId, PlaceStatus status);

    Optional<PlaceEntity> findByContentIdAndContentTypeId(Long contentId, Integer contentTypeId);

    /**
     * 반경 안의 장소를 가까운 순으로. 주변 탐색·지도 마커가 쓴다. (MAP-026, MAP-030)
     *
     * <p>{@code gix_places_geom} GiST 인덱스를 탄다. 좌표 없는 장소는 {@code geom} 이 null 이라
     * 자연히 빠진다 (PLC-007).
     *
     * <p>PostgreSQL 의 콜론 두 개 캐스트 대신 PostGIS 의 {@code geography(...)} 생성 함수를 쓴다.
     * 네이티브 쿼리에서 콜론은 명명 파라미터 접두어라 캐스트 문법과 충돌한다.
     */
    @Query(value = """
            select p.place_id, p.place_type, p.content_id, p.content_type_id, p.title, p.addr1,
                   p.lat, p.lng, p.verify_radius_m, p.area_code, p.sigungu_code, p.status,
                   p.post_count, p.visit_count, p.view_count, p.created_by, p.created_at, p.updated_at
              from places p
             where p.status = 'ACTIVE'
               and p.geom is not null
               and st_dwithin(p.geom, geography(st_setsrid(st_makepoint(:lng, :lat), 4326)), :radiusM)
             order by st_distance(p.geom, geography(st_setsrid(st_makepoint(:lng, :lat), 4326)))
             limit :limit
            """, nativeQuery = true)
    List<PlaceEntity> findNearby(@Param("lat") double lat,
                                 @Param("lng") double lng,
                                 @Param("radiusM") int radiusM,
                                 @Param("limit") int limit);

    /** 게시글 등록·삭제 시 장소 카운터를 옮긴다. 목록 조회에서 COUNT 를 돌리지 않기 위한 비정규화다. */
    @Modifying
    @Query("update PlaceEntity p set p.postCount = p.postCount + :delta, p.updatedAt = :now "
            + "where p.placeId = :placeId")
    int addPostCount(@Param("placeId") Long placeId,
                     @Param("delta") int delta,
                     @Param("now") OffsetDateTime now);

    /** 방문자 수 증가. 방문이 새로 기록된 경우에만 부른다 (VST-001). */
    @Modifying
    @Query("update PlaceEntity p set p.visitCount = p.visitCount + :delta, p.updatedAt = :now "
            + "where p.placeId = :placeId")
    int addVisitCount(@Param("placeId") Long placeId,
                      @Param("delta") int delta,
                      @Param("now") OffsetDateTime now);
}
