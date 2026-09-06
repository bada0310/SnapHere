package com.snaphere.api.event;

import com.snaphere.api.event.entity.EventEntity;
import org.springframework.beans.BeanUtils;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.time.OffsetDateTime;

/** 테스트용 행사 엔터티. 필드가 전부 private 이라 리플렉션으로 채운다. */
public final class EventFixtures {

    private EventFixtures() {
    }

    public static EventEntity event(long eventId, LocalDate startDate, LocalDate endDate,
                                    OffsetDateTime createdAt) {
        EventEntity event = BeanUtils.instantiateClass(EventEntity.class);
        ReflectionTestUtils.setField(event, "eventId", eventId);
        ReflectionTestUtils.setField(event, "title", "행사 " + eventId);
        ReflectionTestUtils.setField(event, "areaCode", 1);
        ReflectionTestUtils.setField(event, "placeId", 100L + eventId);
        ReflectionTestUtils.setField(event, "startDate", startDate);
        ReflectionTestUtils.setField(event, "endDate", endDate);
        ReflectionTestUtils.setField(event, "participantCount", 3);
        ReflectionTestUtils.setField(event, "source", "MANUAL");
        ReflectionTestUtils.setField(event, "status", EventLifecycle.ACTIVE);
        ReflectionTestUtils.setField(event, "createdAt", createdAt);
        ReflectionTestUtils.setField(event, "updatedAt", createdAt);
        return event;
    }
}
