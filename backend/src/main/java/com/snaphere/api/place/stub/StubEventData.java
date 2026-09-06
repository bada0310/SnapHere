package com.snaphere.api.place.stub;

import com.snaphere.api.place.EventSnapshot;
import com.snaphere.api.place.EventSnapshotReader;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 행사 고정 데이터.
 *
 * <p><b>{@code events} 테이블이 생기면 이 클래스를 삭제한다.</b> 이벤트 도메인(EVT)은 이 브랜치
 * 범위가 아니어서 스키마가 아직 없다. 그래도 등급 판정은 행사 인증 반경을 먼저 보므로
 * (EVT-023, PLC-022) 판정 경로를 끊지 않기 위해 남긴다.
 *
 * <p>이제 {@code snaphere.stub-data=true} 일 때만 등록된다. 기본값 {@code false} 에서는
 * {@code JpaEventSnapshotReader} 가 {@code events} 테이블을 읽는다 (EVT-002). 조건을 걸지 않으면
 * 두 구현이 동시에 등록돼 애플리케이션이 뜨지 않는다.
 */
@Configuration
@ConditionalOnProperty(prefix = "snaphere", name = "stub-data", havingValue = "true")
public class StubEventData {

    private static final Map<Long, EventSnapshot> EVENTS = new LinkedHashMap<>();

    static {
        // 이벤트별 반경이 없는 행사 → 지역 기본값으로 내려간다 (EVT-023)
        EVENTS.put(1L, new EventSnapshot(1L, null, 37, 4L));
        // 이벤트별 반경이 지정된 행사 → 이 값이 최우선 (PLC-022)
        EVENTS.put(2L, new EventSnapshot(2L, 3_000, 1, 1L));
    }

    @Bean
    public EventSnapshotReader stubEventSnapshotReader() {
        return eventId -> Optional.ofNullable(EVENTS.get(eventId));
    }
}
