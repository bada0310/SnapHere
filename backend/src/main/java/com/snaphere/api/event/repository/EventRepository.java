package com.snaphere.api.event.repository;

import com.snaphere.api.event.entity.EventEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

/** 행사 조회. (EVT-002, EVT-005 ~ EVT-011) */
public interface EventRepository extends JpaRepository<EventEntity, Long> {

    /**
     * 첫 화면 목록. 진행 → 임박 → 예정 → 종료 순, 그룹 안에서는 시작일 오름차순. (EVT-005)
     *
     * <p>정렬 그룹을 파생 컬럼으로 만들어 바깥에서 한 번만 쓴다. {@code order by} 와 커서 비교와
     * 그룹 필터가 같은 {@code case} 식을 세 번 반복하지 않게 하려는 것이다 — 반복하면 셋 중
     * 하나만 고쳐 놓고 "왜 페이지가 겹치지" 를 찾게 된다. 숫자는
     * {@code EventSortGroup} 의 상수와 같아야 한다.
     *
     * <p>{@code is null} 자리마다 {@code cast} 가 붙어 있다. PostgreSQL 은 {@code IS NULL} 에만
     * 쓰인 파라미터의 타입을 추론하지 못해 {@code could not determine data type} 으로 거절한다
     * (2026-09-04 로컬 검증에서 게시글 피드가 같은 이유로 500 이었다).
     */
    @Query(value = """
            select g.* from (
                select e.*,
                       case
                           when e.start_date <= :today and e.end_date >= :today then 0
                           when e.start_date > :today and e.start_date <= :soon  then 1
                           when e.start_date > :soon                             then 2
                           else 3
                       end as sort_group
                from events e
                where e.status = 'ACTIVE'
                  and (cast(:areaCode as integer) is null or e.area_code = :areaCode)
            ) g
            where g.sort_group in (:groups)
              and (cast(:cursorGroup as integer) is null
                   or g.sort_group > :cursorGroup
                   or (g.sort_group = :cursorGroup
                       and (g.start_date > cast(:cursorStart as date)
                            or (g.start_date = cast(:cursorStart as date)
                                and g.event_id > :cursorId))))
            order by g.sort_group asc, g.start_date asc, g.event_id asc
            limit :size
            """, nativeQuery = true)
    List<EventEntity> findPage(@Param("today") LocalDate today,
                               @Param("soon") LocalDate soon,
                               @Param("areaCode") Integer areaCode,
                               @Param("groups") List<Integer> groups,
                               @Param("cursorGroup") Integer cursorGroup,
                               @Param("cursorStart") LocalDate cursorStart,
                               @Param("cursorId") Long cursorId,
                               @Param("size") int size);

    /**
     * 시도별 진행·예정 행사 수와 신규 수. (EVT-007, EVT-008)
     *
     * <p>행사가 하나도 없는 시도도 0 으로 나와야 한다 — 앱은 17개 시도 칩을 항상 그린다.
     * 그래서 {@code regions} 를 왼쪽에 두고 조건을 {@code on} 절에 넣는다. {@code where} 로
     * 옮기면 행사 없는 시도가 통째로 사라진다.
     *
     * <p><b>네이티브 쿼리가 아니라 JPQL 이다.</b> 처음에는 PostgreSQL 의
     * {@code count(...) filter (where ...)} 를 네이티브로 썼는데 인터페이스 프로젝션과 맞물려
     * 500 이 났다(2026-09-06 로컬 검증). 네이티브 프로젝션은 결과셋 별칭을 대소문자까지 그대로
     * 찾는데 PostgreSQL 은 따옴표 없는 식별자를 소문자로 접는다 — 큰따옴표를 붙여도 어긋났다.
     * JPQL 은 별칭 대신 프로퍼티 이름으로 맞추므로 그 층이 통째로 사라진다. {@code filter} 절은
     * 표준 {@code sum(case when ...)} 으로 바꿨다. 같은 결과이고 이식성도 낫다.
     */
    @Query("""
            select r.areaCode                                               as areaCode,
                   r.nameKo                                                 as areaName,
                   count(e.eventId)                                         as eventCount,
                   sum(case when e.createdAt >= :newSince then 1 else 0 end) as newCount,
                   max(e.createdAt)                                         as latestAddedAt
              from RegionEntity r
              left join EventEntity e
                     on e.areaCode = r.areaCode
                    and e.status = com.snaphere.api.event.EventLifecycle.ACTIVE
                    and e.endDate >= :today
             group by r.areaCode, r.nameKo
             order by r.areaCode
            """)
    List<EventRegionSummaryRow> findRegionSummary(@Param("today") LocalDate today,
                                                  @Param("newSince") OffsetDateTime newSince);

    /**
     * 현재 위치 주변에서 진행·예정 중인 행사. 가까운 순. (EVT-015)
     *
     * <p>행사장은 {@code places} 에 있으므로 좌표 조건은 그쪽에 건다. 좌표 없는 장소는
     * {@code geom} 이 null 이라 자연히 빠진다 (PLC-007).
     *
     * <p><b>콜론 두 개 캐스트를 쓰지 않는다.</b> 네이티브 쿼리에서 {@code :} 는 명명 파라미터
     * 접두어라 {@code ::geography} 가 파라미터로 잘못 읽힌다. PostGIS 의 {@code geography(...)}
     * 생성 함수로 같은 일을 한다 — 장소 주변 검색이 이미 같은 이유로 이 형태를 쓴다.
     *
     * <p>종료된 행사는 뺀다. 주변에 있어도 갈 수 없는 행사를 지도에 찍을 이유가 없다.
     */
    @Query(value = """
            select e.* from events e
              join places p on p.place_id = e.place_id
             where e.status = 'ACTIVE'
               and e.end_date >= :today
               and p.status = 'ACTIVE'
               and p.geom is not null
               and st_dwithin(p.geom, geography(st_setsrid(st_makepoint(:lng, :lat), 4326)), :radiusM)
             order by st_distance(p.geom, geography(st_setsrid(st_makepoint(:lng, :lat), 4326))),
                      e.start_date, e.event_id
             limit :limit
            """, nativeQuery = true)
    List<EventEntity> findNearby(@Param("lat") double lat,
                                 @Param("lng") double lng,
                                 @Param("radiusM") int radiusM,
                                 @Param("today") LocalDate today,
                                 @Param("limit") int limit);

    /**
     * 참여 게시글 수 카운터를 옮긴다. (EVT-021)
     *
     * <p>목록·상세에서 COUNT 를 돌리지 않기 위한 비정규화다. 장소의 {@code post_count} 와 같은
     * 방식이다.
     *
     * <p>등급과 무관하게 센다. 반경 밖에서 올린 글도 그 행사에 참여한 글로 목록(EVT-014)에
     * 나오기 때문이다 — 뱃지를 못 받는 것과 참여로 세지 않는 것은 다른 이야기다 (EVT-023).
     */
    @Modifying
    @Query("update EventEntity e set e.participantCount = e.participantCount + :delta, "
            + "e.updatedAt = :now where e.eventId = :eventId")
    int addParticipantCount(@Param("eventId") Long eventId,
                            @Param("delta") int delta,
                            @Param("now") OffsetDateTime now);

    /**
     * {@link #findRegionSummary} 결과 한 행.
     *
     * <p>{@code getNewCount} 만 래퍼 타입이다. 행사가 없는 시도에서 {@code sum} 은 0 이 아니라
     * <b>null</b> 을 준다 — primitive 로 받으면 그 시도에서 언박싱이 터진다. {@code count} 는
     * 행이 없어도 0 이라 primitive 로 둔다.
     */
    interface EventRegionSummaryRow {
        Integer getAreaCode();

        String getAreaName();

        long getEventCount();

        Long getNewCount();

        OffsetDateTime getLatestAddedAt();
    }
}
