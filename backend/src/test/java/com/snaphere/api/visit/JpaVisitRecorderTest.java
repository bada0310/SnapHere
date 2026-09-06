package com.snaphere.api.visit;

import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.visit.repository.VisitRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 방문 자동 기록 — VST-001, VST-002
 *
 * <p>등급 판정, 날짜 기준 시간대, 중복일 때 방문자 수를 올리지 않는지가 이 구현의 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class JpaVisitRecorderTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");
    private static final long PLACE_ID = 5L;
    private static final long POST_ID = 7L;

    @Mock private VisitRepository visits;
    @Mock private PlaceRepository places;

    private JpaVisitRecorder recorder;

    @BeforeEach
    void setUp() {
        recorder = new JpaVisitRecorder(visits, places);
        when(visits.insertIfAbsent(any(), anyLong(), anyLong(), any())).thenReturn(1);
    }

    @Test
    @DisplayName("방문으로 인정되는 등급이면 기록하고 장소 방문자 수를 올린다")
    void recordsEligibleVisit() {
        boolean recorded = recorder.recordIfEligible(USER, PLACE_ID, POST_ID, true,
                OffsetDateTime.parse("2026-09-04T12:00:00+09:00"));

        assertThat(recorded).isTrue();
        verify(visits).insertIfAbsent(USER, PLACE_ID, POST_ID, LocalDate.of(2026, 9, 4));
        verify(places).addVisitCount(eq(PLACE_ID), eq(1), any(OffsetDateTime.class));
    }

    @Test
    @DisplayName("낮음 등급은 아무것도 하지 않는다 — 좌표가 확인되지 않은 사진으로 발자국을 남길 수 없다")
    void skipsIneligibleTier() {
        boolean recorded = recorder.recordIfEligible(USER, PLACE_ID, POST_ID, false,
                OffsetDateTime.parse("2026-09-04T12:00:00+09:00"));

        assertThat(recorded).isFalse();
        verify(visits, never()).insertIfAbsent(any(), anyLong(), anyLong(), any());
        verify(places, never()).addVisitCount(anyLong(), anyInt(), any());
    }

    @Test
    @DisplayName("같은 날 이미 있으면 0행이 돌아오고 방문자 수를 올리지 않는다 (VST-002)")
    void duplicateDoesNotCount() {
        when(visits.insertIfAbsent(any(), anyLong(), anyLong(), any())).thenReturn(0);

        boolean recorded = recorder.recordIfEligible(USER, PLACE_ID, POST_ID, true,
                OffsetDateTime.parse("2026-09-04T12:00:00+09:00"));

        assertThat(recorded).isFalse();
        verify(places, never()).addVisitCount(anyLong(), anyInt(), any());
    }

    @Test
    @DisplayName("날짜는 Asia/Seoul 기준이다 — UTC 로 자르면 오전 9시 전 게시글이 어제로 기록된다")
    void usesKoreaDate() {
        ArgumentCaptor<LocalDate> date = ArgumentCaptor.forClass(LocalDate.class);

        // UTC 로는 9월 3일 23시, 한국 시간으로는 9월 4일 오전 8시다.
        recorder.recordIfEligible(USER, PLACE_ID, POST_ID, true,
                OffsetDateTime.parse("2026-09-03T23:00:00Z"));

        verify(visits).insertIfAbsent(any(), anyLong(), anyLong(), date.capture());
        assertThat(date.getValue()).isEqualTo(LocalDate.of(2026, 9, 4));
    }

    @Test
    @DisplayName("다른 시간대로 들어온 요청도 같은 순간이면 같은 날짜다")
    void normalizesOffset() {
        ArgumentCaptor<LocalDate> date = ArgumentCaptor.forClass(LocalDate.class);

        recorder.recordIfEligible(USER, PLACE_ID, POST_ID, true,
                OffsetDateTime.parse("2026-09-04T00:30:00+09:00"));

        verify(visits).insertIfAbsent(any(), anyLong(), anyLong(), date.capture());
        assertThat(date.getValue()).isEqualTo(LocalDate.of(2026, 9, 4));
    }
}
