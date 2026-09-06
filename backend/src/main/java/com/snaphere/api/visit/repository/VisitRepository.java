package com.snaphere.api.visit.repository;

import com.snaphere.api.visit.entity.VisitEntity;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** 방문 기록. (VST-001 ~ VST-005) */
public interface VisitRepository extends JpaRepository<VisitEntity, Long> {

    long countByUserId(UUID userId);

    /**
     * 같은 날 같은 장소가 아직 없으면 넣는다. (VST-001, VST-002)
     *
     * <p>조회 후 삽입하지 않는다. 그 사이에 다른 요청이 끼어들면 두 건이 들어가고, 유니크 제약이
     * 튕기면 예외가 게시글 등록 트랜잭션 전체를 되돌린다 — 방문 중복 때문에 게시글이 실패하면
     * 안 된다.
     *
     * <p>{@code on conflict do nothing} 은 예외를 만들지 않고 0행을 돌려준다. 그래서 판정과
     * 보장이 한 문장에 들어가고 트랜잭션이 오염되지 않는다. PostgreSQL 전용 문법이라 네이티브
     * 쿼리다 — 테스트는 H2 라서 이 문장을 실행하지 않고, 실제 동작은 마이그레이션을 적용한
     * PostgreSQL 에서 확인한다.
     *
     * @return 새로 기록했으면 1, 이미 있었으면 0
     */
    @Modifying
    @Query(value = """
            insert into visits (user_id, place_id, post_id, visited_on)
            values (:userId, :placeId, :postId, :visitedOn)
            on conflict (user_id, place_id, visited_on) do nothing
            """, nativeQuery = true)
    int insertIfAbsent(@Param("userId") UUID userId,
                       @Param("placeId") long placeId,
                       @Param("postId") long postId,
                       @Param("visitedOn") LocalDate visitedOn);

    /**
     * 내 방문 기록 한 페이지. 최신순이다. (VST-003, SYS-003)
     *
     * <p>커서는 {@code (visitedOn, visitId)} 두 키를 본다. 정렬 키가 날짜라 같은 값이 흔하고,
     * 2차 키가 없으면 같은 날 방문이 두 페이지에 나오거나 사라진다.
     *
     * <p><b>{@code cast(:cursorVisitedOn as date)} 인 이유.</b> {@code :x is null} 은 그 자리에서
     * 타입을 추론할 근거가 없다. Hibernate 가 Long 은 {@code setNull(idx, BIGINT)} 로 JDBC 타입까지
     * 실어 보내지만 {@code LocalDate} null 은 타입 없이 나가고, PostgreSQL 은
     * {@code could not determine data type of parameter $n} 으로 준비 단계에서 거부한다.
     * 그래서 {@code cursorVisitId} 는 그냥 두고 날짜에만 씌운다. H2 는 cast 없이도 받아 주므로
     * 테스트로는 잡히지 않는다 — 게시글 피드가 같은 이유로 실제 DB 에서 항상 500 이었다 (a493e38).
     */
    @Query("""
            select v from VisitEntity v
             where v.userId = :userId
               and (cast(:cursorVisitedOn as date) is null
                    or v.visitedOn < :cursorVisitedOn
                    or (v.visitedOn = :cursorVisitedOn and v.visitId < :cursorVisitId))
             order by v.visitedOn desc, v.visitId desc
            """)
    List<VisitEntity> findMine(@Param("userId") UUID userId,
                               @Param("cursorVisitedOn") LocalDate cursorVisitedOn,
                               @Param("cursorVisitId") Long cursorVisitId,
                               Pageable pageable);

    /**
     * 지역별 방문 집계. (VST-004, VST-008, VST-009)
     *
     * <p>{@code visits} 에 지역 코드를 두지 않고 {@code places} 를 조인한다. 장소의 지역이
     * 바뀌면(행정구역 개편·데이터 정정) 과거 방문의 지역도 함께 따라가야 맞다 — 복사해 두면
     * 두 값이 갈린다.
     *
     * @return {@code [areaCode, 방문 횟수, 방문 장소 수, 최근 방문일]}
     */
    @Query("""
            select p.areaCode, count(v.visitId), count(distinct v.placeId), max(v.visitedOn)
              from VisitEntity v, PlaceEntity p
             where v.placeId = p.placeId
               and v.userId = :userId
             group by p.areaCode
             order by count(v.visitId) desc, p.areaCode asc
            """)
    List<Object[]> aggregateByArea(@Param("userId") UUID userId);

    /**
     * 장소를 다녀간 사용자 한 페이지. 사용자당 가장 최근 방문 한 건만 준다. (VST-005)
     *
     * <p>방문 행을 그대로 페이징하면 여러 날 다녀간 사람이 여러 페이지에 나온다. 사용자별 최신
     * 방문 ID 만 골라 놓고 그 위에서 커서를 굴린다 — 서브쿼리가 이 장소의 방문만 훑으므로
     * {@code idx_visits_place} 로 끝난다.
     */
    @Query("""
            select v from VisitEntity v
             where v.placeId = :placeId
               and v.visitId in (select max(v2.visitId) from VisitEntity v2
                                  where v2.placeId = :placeId
                                  group by v2.userId)
               and (cast(:cursorVisitedOn as date) is null
                    or v.visitedOn < :cursorVisitedOn
                    or (v.visitedOn = :cursorVisitedOn and v.visitId < :cursorVisitId))
             order by v.visitedOn desc, v.visitId desc
            """)
    List<VisitEntity> findVisitorsOfPlace(@Param("placeId") long placeId,
                                          @Param("cursorVisitedOn") LocalDate cursorVisitedOn,
                                          @Param("cursorVisitId") Long cursorVisitId,
                                          Pageable pageable);

    /**
     * 방문 지도 마커. 장소 하나당 한 점이다. (VST-007)
     *
     * <p>좌표 없는 장소는 뺀다 (PLC-007). 지도에 찍을 수 없는 점을 내려보내면 클라이언트가
     * 경계 계산에서 걸러야 하고, 그러면 서버가 준 bounds 와 어긋난다.
     *
     * <p>방문 횟수가 많은 곳부터 준다. 오래 쓴 사용자는 장소가 수천 개가 될 수 있어 상한을
     * 두는데, 잘릴 때 남는 것이 자주 간 곳이어야 지도가 덜 이상해진다.
     *
     * @return {@code [placeId, lat, lng, 방문 횟수]}
     */
    @Query("""
            select p.placeId, p.lat, p.lng, count(v.visitId)
              from VisitEntity v, PlaceEntity p
             where v.placeId = p.placeId
               and v.userId = :userId
               and p.lat is not null
               and p.lng is not null
             group by p.placeId, p.lat, p.lng
             order by count(v.visitId) desc, p.placeId asc
            """)
    List<Object[]> findVisitMapPoints(@Param("userId") UUID userId, Pageable pageable);
}
