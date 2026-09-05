package com.snaphere.api.event.jpa;

import com.snaphere.api.event.EventFixtures;
import com.snaphere.api.event.repository.EventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/** 행사 고정 태그 조회 — EVT-017, EVT-018 */
@ExtendWith(MockitoExtension.class)
class JpaEventFixedTagReaderTest {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Mock
    private EventRepository events;

    private JpaEventFixedTagReader reader;

    @BeforeEach
    void setUp() {
        reader = new JpaEventFixedTagReader(events);
    }

    @Test
    @DisplayName("행사의 고정 태그 이름을 그대로 준다 — 정규화는 태그 도메인 몫이다")
    void 고정_태그() {
        LocalDate today = LocalDate.now(KST);
        when(events.findById(1L)).thenReturn(Optional.of(EventFixtures.detailed(
                1L, today, today.plusDays(3), OffsetDateTime.now(KST), 101L, null,
                List.of("서울", "경복궁야간개장"))));

        assertThat(reader.fixedTagNames(1L)).containsExactly("서울", "경복궁야간개장");
    }

    @Test
    @DisplayName("없는 행사는 빈 목록 — 업로드가 실패하지 않는다")
    void 없는_행사() {
        when(events.findById(9L)).thenReturn(Optional.empty());

        assertThat(reader.fixedTagNames(9L)).isEmpty();
    }

    @Test
    @DisplayName("숨긴 행사도 빈 목록 — 내린 행사 이름이 새 글에 붙으면 안 된다")
    void 숨긴_행사() {
        LocalDate today = LocalDate.now(KST);
        when(events.findById(2L)).thenReturn(Optional.of(
                EventFixtures.hidden(2L, today, today.plusDays(3), OffsetDateTime.now(KST))));

        assertThat(reader.fixedTagNames(2L)).isEmpty();
    }
}
