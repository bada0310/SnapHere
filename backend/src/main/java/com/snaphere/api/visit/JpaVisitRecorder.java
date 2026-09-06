package com.snaphere.api.visit;

import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.visit.repository.VisitRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.UUID;

/**
 * {@link VisitRecorder} 구현. (VST-001, VST-002)
 *
 * <p>게시글 등록 트랜잭션 안에서 돌아간다. 방문 기록이 실패해도 게시글은 남아야 하지만, 반대로
 * 게시글이 되돌려지면 방문도 없어야 한다 — 그래서 같은 트랜잭션에 두고, 대신 중복은 예외 없이
 * 처리한다 ({@code on conflict do nothing}).
 */
@Component
public class JpaVisitRecorder implements VisitRecorder {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final VisitRepository visits;
    private final PlaceRepository places;

    public JpaVisitRecorder(VisitRepository visits, PlaceRepository places) {
        this.visits = visits;
        this.places = places;
    }

    /**
     * 등급이 방문으로 인정될 때만 기록한다. (VST-001)
     *
     * <p>낮음 등급은 아무것도 하지 않는다. 좌표가 확인되지 않은 사진으로 발자국을 남길 수 있으면
     * 앨범 사진만으로 17개 시도를 채울 수 있다.
     *
     * <p>날짜는 Asia/Seoul 기준이다 (SYS-005). UTC 로 자르면 한국 시간 오전 9시 전에 올린 두
     * 게시글이 서로 다른 날로 취급돼 같은 장소가 이틀로 기록된다.
     *
     * <p>{@code places.visit_count} 는 새로 기록된 경우에만 올린다 — 같은 사람이 매일 가도
     * 방문자 수가 아니라 방문 횟수가 되지만, 중복 삽입에서 올리면 그조차 어긋난다.
     */
    @Override
    @Transactional
    public boolean recordIfEligible(UUID userId, long placeId, long postId,
                                    boolean countsForVisit, OffsetDateTime at) {
        if (!countsForVisit) {
            return false;
        }
        LocalDate visitedOn = at.atZoneSameInstant(KST).toLocalDate();
        boolean recorded = visits.insertIfAbsent(userId, placeId, postId, visitedOn) > 0;
        if (recorded) {
            places.addVisitCount(placeId, 1, at);
        }
        return recorded;
    }
}
