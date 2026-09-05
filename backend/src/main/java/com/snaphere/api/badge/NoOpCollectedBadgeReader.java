package com.snaphere.api.badge;

import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

/**
 * {@code user_badges} 테이블이 생기기 전까지 쓰는 구현. 항상 빈 목록.
 *
 * <p><b>실제 구현을 추가할 때 이 파일을 지운다.</b> 조건부 등록을 걸지 않았으므로 구현이
 * 하나 더 생기면 애플리케이션이 뜨지 않고 중복 빈을 알려 준다.
 */
@Component
public class NoOpCollectedBadgeReader implements CollectedBadgeReader {

    @Override
    public List<AwardedBadge> findCollected(UUID userId, int limit) {
        return List.of();
    }
}
