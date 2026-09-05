package com.snaphere.api.event;

import com.snaphere.api.post.dto.BadgeSummaryResponse;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

/**
 * {@code badges} 테이블이 생기기 전까지 쓰는 구현. 항상 빈 값.
 *
 * <p><b>실제 구현을 추가할 때 이 파일을 지운다.</b> 조건부 등록을 걸지 않았으므로 구현이
 * 하나 더 생기면 애플리케이션이 뜨지 않고 중복 빈을 알려 준다 — {@code NoOpBadgeAwarder} 와
 * 같은 방식이다.
 */
@Component
public class NoOpEventBadgeReader implements EventBadgeReader {

    @Override
    public Optional<BadgeSummaryResponse> findByEventId(long eventId, UUID viewerId) {
        return Optional.empty();
    }
}
