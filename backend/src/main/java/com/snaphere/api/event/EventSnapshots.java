package com.snaphere.api.event;

import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.place.EventSnapshot;

/**
 * 행사 엔터티를 등급·반경 판정용 읽기 뷰로 바꾼다.
 *
 * <p>{@code VerifyRadiusResolver} 는 {@code place} 패키지의 {@link EventSnapshot} 만 안다.
 * 이벤트 도메인이 생기기 전에 그렇게 잘라 둔 것이고, 지금도 그 경계를 유지한다 — 반경 규칙
 * (이벤트별 값 → 지역 기본값 → 2,000m)이 한 곳에만 있어야 상세 화면과 실제 등급 판정이
 * 어긋나지 않는다 (EVT-023, PLC-022).
 */
public final class EventSnapshots {

    private EventSnapshots() {
    }

    public static EventSnapshot of(EventEntity event) {
        return new EventSnapshot(
                event.getEventId(),
                event.getVerifyRadiusM(),
                event.getAreaCode(),
                event.getPlaceId());
    }
}
