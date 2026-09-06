package com.snaphere.api.event.jpa;

import com.snaphere.api.event.EventLifecycle;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.EventSnapshot;
import com.snaphere.api.place.EventSnapshotReader;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * {@code events} 테이블을 읽어 등급 판정에 필요한 값만 넘긴다. (EVT-023, PLC-022)
 *
 * <p>숨긴 행사는 없는 것으로 본다. 행사를 내렸는데 그 행사 반경으로 등급이 계속 나오면
 * 운영이 내린 결정이 판정에 반영되지 않는다.
 *
 * <p>{@code StubEventData} 를 대신한다. 둘 다 {@code EventSnapshotReader} 빈이라 조건이
 * 겹치면 애플리케이션이 뜨지 않는다 — 그래서 서로 반대 조건을 건다.
 */
@Component
@ConditionalOnProperty(prefix = "snaphere", name = "stub-data", havingValue = "false", matchIfMissing = true)
public class JpaEventSnapshotReader implements EventSnapshotReader {

    private final EventRepository events;

    public JpaEventSnapshotReader(EventRepository events) {
        this.events = events;
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<EventSnapshot> findById(long eventId) {
        return events.findById(eventId)
                .filter(event -> event.getStatus() == EventLifecycle.ACTIVE)
                .map(JpaEventSnapshotReader::toSnapshot);
    }

    private static EventSnapshot toSnapshot(EventEntity event) {
        return new EventSnapshot(
                event.getEventId(),
                event.getVerifyRadiusM(),
                event.getAreaCode(),
                event.getPlaceId());
    }
}
