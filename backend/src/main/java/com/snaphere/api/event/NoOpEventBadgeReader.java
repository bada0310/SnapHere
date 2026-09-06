package com.snaphere.api.event;

import com.snaphere.api.post.dto.BadgeSummaryResponse;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

/**
 * {@code badges} 테이블이 생기기 전까지 쓰는 구현. 항상 빈 값.
 *
 * <p>뱃지 스키마(V15)가 들어온 뒤에는 {@code JpaEventBadgeReader} 가 {@code @Primary} 로
 * 우선한다. 이 파일을 지우지 않고 남긴 이유는 이벤트 도메인이 뱃지 도메인 없이도 컴파일·기동되게
 * 했던 장치이기 때문이다 — 브랜치를 되돌리거나 뱃지 스키마 없이 이벤트만 띄울 때 필요하다.
 *
 * <p>{@code @Primary} 로 갈라 두면 중복 빈 오류도 나지 않는다. {@code Slf4jTierDecisionLogger}
 * 와 {@code JpaTierDecisionLogger} 가 같은 관계다.
 */
@Component
public class NoOpEventBadgeReader implements EventBadgeReader {

    @Override
    public Optional<BadgeSummaryResponse> findByEventId(long eventId, UUID viewerId) {
        return Optional.empty();
    }
}
