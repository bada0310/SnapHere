package com.snaphere.api.event.jpa;

import com.snaphere.api.event.EventLifecycle;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import com.snaphere.api.place.EventFixedTagReader;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * {@code events.fixed_tags} 를 읽는다. (EVT-017, EVT-018, CMU-028)
 *
 * <p>행사 참여 업로드에는 지역 태그 1개와 행사 이름 태그 1개가 자동으로 붙고 사용자가 뗄 수
 * 없다. 그 이름이 여기서 나온다.
 *
 * <p>표시용 이름만 준다. 정규화와 {@code tags} 행 연결은 태그 도메인이 한다 — 포트의 계약이
 * 그렇게 정해져 있고, 그래야 태그 정규화 규칙이 한 곳에만 남는다.
 *
 * <p>숨긴 행사는 빈 목록이다. 운영이 내린 행사의 이름이 새 게시글에 계속 붙으면 안 된다.
 * 등급 판정 쪽 {@code JpaEventSnapshotReader} 도 같은 기준으로 거른다.
 */
@Component
public class JpaEventFixedTagReader implements EventFixedTagReader {

    private final EventRepository events;

    public JpaEventFixedTagReader(EventRepository events) {
        this.events = events;
    }

    @Override
    @Transactional(readOnly = true)
    public List<String> fixedTagNames(long eventId) {
        return events.findById(eventId)
                .filter(event -> event.getStatus() == EventLifecycle.ACTIVE)
                .map(EventEntity::getFixedTags)
                .orElseGet(List::of);
    }
}
