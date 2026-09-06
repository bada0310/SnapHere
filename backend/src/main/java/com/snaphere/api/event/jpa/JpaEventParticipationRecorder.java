package com.snaphere.api.event.jpa;

import com.snaphere.api.event.EventParticipationRecorder;
import com.snaphere.api.event.repository.EventRepository;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.time.ZoneId;

/**
 * {@code events.participant_count} 를 올린다. (EVT-021)
 *
 * <p>게시글 생성 트랜잭션 안에서 돈다. 게시글이 롤백되면 참여 수도 함께 되돌아가야 한다 —
 * 별도 트랜잭션으로 빼면 실패한 업로드가 카운터만 남긴다.
 *
 * <p>등급을 보지 않는다. 반경 밖에서 올린 글도 참여 게시글 목록(EVT-014)에는 나오므로
 * 카운터도 같이 세야 화면과 숫자가 맞는다. 뱃지를 못 받는 것은 별개다 (EVT-023).
 */
@Component
public class JpaEventParticipationRecorder implements EventParticipationRecorder {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final EventRepository events;

    public JpaEventParticipationRecorder(EventRepository events) {
        this.events = events;
    }

    @Override
    public boolean recordIfEvent(Long eventId) {
        if (eventId == null) {
            return false;
        }
        return events.addParticipantCount(eventId, 1, OffsetDateTime.now(KST)) > 0;
    }
}
