package com.snaphere.api.post.repository;

import com.snaphere.api.post.PostStatus;
import com.snaphere.api.post.entity.PostEntity;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * 게시글 조회.
 *
 * <p>목록은 전부 커서 기반이다 (SYS-003). {@code createdAt} 이 같은 행이 있을 수 있어
 * {@code postId} 를 2차 키로 함께 비교한다 — 그러지 않으면 같은 행이 두 페이지에 나온다.
 */
public interface PostRepository extends JpaRepository<PostEntity, Long> {

    Optional<PostEntity> findByPostIdAndStatus(Long postId, PostStatus status);

    /**
     * 목록 조회. 지역·장소·태그·기간을 조합한다. (PST-034)
     *
     * <p>필터는 전부 선택이고 null 이면 조건에서 빠진다. 조합마다 메서드를 따로 두면
     * 커서 비교 조건을 여러 곳에 복사하게 되고, 한 곳만 고치면 페이징이 어긋난다.
     *
     * <p>{@code areaCode} 만 준 경우 {@code idx_posts_area_created} 부분 인덱스를 탄다
     * (CMU-001, PLC-013).
     *
     * <p>태그는 ID 로 받는다. 정규화 이름 → ID 변환은 조회 전에 한 번만 하면 되고,
     * 그 이름을 쓴 태그가 없으면 애초에 이 쿼리를 돌릴 필요가 없다 (CMU-030).
     *
     * <p><b>시각 파라미터의 null 검사에 cast 를 씌운 이유.</b> {@code :x is null} 은 그 자리에서
     * 타입을 추론할 근거가 없다. Hibernate 가 Integer·Long 은 {@code setNull(idx, INTEGER)} 로
     * JDBC 타입까지 실어 보내지만 {@code OffsetDateTime} null 은 타입 없이 나가고, PostgreSQL 은
     * {@code could not determine data type of parameter $n} 으로 준비 단계에서 거부한다.
     * H2 는 이를 받아 주므로 테스트로는 잡히지 않는다 — 실제 PostgreSQL 에서만 드러난다.
     */
    @Query("""
            select p from PostEntity p
             where p.status = com.snaphere.api.post.PostStatus.ACTIVE
               and (:areaCode is null or p.areaCode = :areaCode)
               and (:placeId is null or p.placeId = :placeId)
               and (cast(:createdFrom as timestamp) is null or p.createdAt >= :createdFrom)
               and (:tagId is null
                    or exists (select pt.id.postId from PostTagEntity pt
                                where pt.id.postId = p.postId and pt.id.tagId = :tagId))
               and (cast(:cursorCreatedAt as timestamp) is null
                    or p.createdAt < :cursorCreatedAt
                    or (p.createdAt = :cursorCreatedAt and p.postId < :cursorPostId))
             order by p.createdAt desc, p.postId desc
            """)
    List<PostEntity> findFeed(@Param("areaCode") Integer areaCode,
                              @Param("placeId") Long placeId,
                              @Param("tagId") Long tagId,
                              @Param("createdFrom") OffsetDateTime createdFrom,
                              @Param("cursorCreatedAt") OffsetDateTime cursorCreatedAt,
                              @Param("cursorPostId") Long cursorPostId,
                              Pageable pageable);

    /**
     * 행사에 참여한 공개 게시글. 최신순. (EVT-014)
     *
     * <p>{@link #findFeed} 에 {@code eventId} 를 더하지 않고 메서드를 나눴다. findFeed 는
     * 피드·태그·장소 세 곳이 쓰고 테스트도 그 시그니처에 묶여 있어, 파라미터 하나를 늘리면
     * 이 슬라이스와 무관한 코드 다섯 곳이 함께 바뀐다. 여기 필터는 {@code eventId} 하나뿐이라
     * 조건을 복사해도 갈라질 여지가 작다.
     *
     * <p>커서 비교의 {@code cast} 는 findFeed 와 같은 이유다 — PostgreSQL 은 {@code IS NULL}
     * 에만 쓰인 시각 파라미터의 타입을 추론하지 못한다.
     */
    @Query("""
            select p from PostEntity p
             where p.status = com.snaphere.api.post.PostStatus.ACTIVE
               and p.eventId = :eventId
               and (cast(:cursorCreatedAt as timestamp) is null
                    or p.createdAt < :cursorCreatedAt
                    or (p.createdAt = :cursorCreatedAt and p.postId < :cursorPostId))
             order by p.createdAt desc, p.postId desc
            """)
    List<PostEntity> findEventPosts(@Param("eventId") Long eventId,
                                    @Param("cursorCreatedAt") OffsetDateTime cursorCreatedAt,
                                    @Param("cursorPostId") Long cursorPostId,
                                    Pageable pageable);

    /** 장소 상세의 게시글 그리드. (PLC-013) */
    List<PostEntity> findByPlaceIdAndStatusOrderByCreatedAtDescPostIdDesc(
            Long placeId, PostStatus status, Pageable pageable);

    /**
     * 뱃지 조건 평가에 쓰는 집계. (BDG-002 ~ BDG-004, BDG-007)
     *
     * <p>낮음 등급은 전부 제외한다 (PST-026). 반경 밖에서 올린 글로 뱃지를 모을 수 있으면
     * 현장 인증이라는 전제가 무너진다.
     *
     * <p>세 메서드가 같은 조건을 공유해 한 곳에 모아 뒀다 — 하나만 등급 조건을 빠뜨리면
     * 뱃지 종류에 따라 기준이 달라진다.
     */
    @Query("select count(p) from PostEntity p "
            + "where p.userId = :userId and p.status = com.snaphere.api.post.PostStatus.ACTIVE "
            + "  and p.tier <> com.snaphere.api.post.tier.TrustTier.LOW")
    long countEligibleByUser(@Param("userId") UUID userId);

    @Query("select count(p) from PostEntity p "
            + "where p.userId = :userId and p.areaCode = :areaCode "
            + "  and p.status = com.snaphere.api.post.PostStatus.ACTIVE "
            + "  and p.tier <> com.snaphere.api.post.tier.TrustTier.LOW")
    long countEligibleByUserAndArea(@Param("userId") UUID userId,
                                    @Param("areaCode") Integer areaCode);

    /**
     * 게시글을 남긴 시도 수. 완주 뱃지(BDG-003)의 진행값이다.
     *
     * <p>방문 기록(visits)이 아니라 게시글로 센다. VST 도메인이 아직 이 브랜치에 없고, 방문
     * 기록 자체가 "높음·보통 게시글을 올리면 남는" 것이라 같은 집합이다 (VST-001). visits 가
     * develop 에 들어오면 그쪽으로 옮기는 편이 정확하다 — 같은 장소를 여러 번 올려도 방문은
     * 하루 한 번이기 때문이다.
     */
    @Query("select count(distinct p.areaCode) from PostEntity p "
            + "where p.userId = :userId and p.status = com.snaphere.api.post.PostStatus.ACTIVE "
            + "  and p.tier <> com.snaphere.api.post.tier.TrustTier.LOW")
    long countDistinctAreasByUser(@Param("userId") UUID userId);

    /** 행사 참여 여부. 행사 뱃지(BDG-001)의 진행값이다. */
    @Query("select count(p) from PostEntity p "
            + "where p.userId = :userId and p.eventId = :eventId "
            + "  and p.status = com.snaphere.api.post.PostStatus.ACTIVE "
            + "  and p.tier <> com.snaphere.api.post.tier.TrustTier.LOW")
    long countEligibleByUserAndEvent(@Param("userId") UUID userId,
                                     @Param("eventId") Long eventId);

    /** 프로필 그리드. (USER-008) */
    List<PostEntity> findByUserIdAndStatusOrderByCreatedAtDescPostIdDesc(
            UUID userId, PostStatus status, Pageable pageable);

    /** 하루 업로드 한도 판정. 기준일은 Asia/Seoul 자정이다 (SYS-005) — 호출자가 경계를 넘긴다. */
    long countByUserIdAndStatusAndCreatedAtGreaterThanEqual(
            UUID userId, PostStatus status, OffsetDateTime from);

    /** 같은 장소 하루 한도 판정. (PST-030) */
    long countByUserIdAndPlaceIdAndStatusAndCreatedAtGreaterThanEqual(
            UUID userId, Long placeId, PostStatus status, OffsetDateTime from);

    /** 조회수 증가. 엔티티를 읽어 고치면 같은 게시글 동시 조회에서 값이 밀린다. (PST-042) */
    @Modifying
    @Query("update PostEntity p set p.viewCount = p.viewCount + 1 where p.postId = :postId")
    int increaseViewCount(@Param("postId") Long postId);

    @Modifying
    @Query("update PostEntity p set p.likeCount = p.likeCount + :delta where p.postId = :postId")
    int addLikeCount(@Param("postId") Long postId, @Param("delta") int delta);

    @Modifying
    @Query("update PostEntity p set p.commentCount = p.commentCount + :delta where p.postId = :postId")
    int addCommentCount(@Param("postId") Long postId, @Param("delta") int delta);
}
