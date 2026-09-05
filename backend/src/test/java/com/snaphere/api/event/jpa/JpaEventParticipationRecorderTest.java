package com.snaphere.api.event.jpa;

import com.snaphere.api.event.repository.EventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 행사 참여 판정 — EVT-021 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class JpaEventParticipationRecorderTest {

    @Mock
    private EventRepository events;

    private JpaEventParticipationRecorder recorder;

    @BeforeEach
    void setUp() {
        recorder = new JpaEventParticipationRecorder(events);
    }

    @Test
    @DisplayName("행사 글이면 참여 수를 올린다")
    void 참여() {
        when(events.addParticipantCount(anyLong(), anyInt(), any())).thenReturn(1);

        assertThat(recorder.recordIfEvent(1L)).isTrue();
        verify(events).addParticipantCount(eq(1L), eq(1), any());
    }

    @Test
    @DisplayName("행사 글이 아니면 아무것도 하지 않는다 — 호출자가 분기하지 않게 한다")
    void 일반_글() {
        assertThat(recorder.recordIfEvent(null)).isFalse();
        verify(events, never()).addParticipantCount(anyLong(), anyInt(), any());
    }

    @Test
    @DisplayName("없는 행사면 갱신된 행이 없다")
    void 없는_행사() {
        when(events.addParticipantCount(anyLong(), anyInt(), any())).thenReturn(0);

        assertThat(recorder.recordIfEvent(9L)).isFalse();
    }
}
