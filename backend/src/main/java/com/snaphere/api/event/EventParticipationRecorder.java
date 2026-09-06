package com.snaphere.api.event;

/**
 * 행사 참여 판정 포트. (EVT-021)
 *
 * <p>게시글이 행사에 연결되면 그 행사의 참여 수를 올린다. 게시글 도메인이 {@code events}
 * 테이블을 직접 쓰지 않도록 여기서 끊는다 — 방문 기록을 {@code VisitRecorder} 로 가른 것과
 * 같은 방식이다.
 */
public interface EventParticipationRecorder {

    /**
     * @param eventId 행사. null 이면 아무것도 하지 않는다 — 호출자가 분기하지 않게 한다
     * @return 참여로 셌으면 true
     */
    boolean recordIfEvent(Long eventId);
}
