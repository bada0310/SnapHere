package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.repository.EventRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 주변 행사 — EVT-015 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class EventNearbyServiceTest {

    @Mock
    private EventRepository events;

    private EventNearbyService service;

    @BeforeEach
    void setUp() {
        service = new EventNearbyService(events);
        when(events.findNearby(anyDouble(), anyDouble(), anyInt(), any(), anyInt()))
                .thenReturn(List.of());
    }

    @Test
    @DisplayName("반경을 안 주면 20km")
    void 기본_반경() {
        service.nearby(37.57, 126.98, null);

        verify(events).findNearby(anyDouble(), anyDouble(),
                org.mockito.ArgumentMatchers.eq(EventNearbyService.DEFAULT_RADIUS_M),
                any(), anyInt());
    }

    @Test
    @DisplayName("50km 를 넘기면 조용히 자른다 — 400 을 주면 지도가 아예 안 그려진다")
    void 최대_반경() {
        service.nearby(37.57, 126.98, 999_999);

        verify(events).findNearby(anyDouble(), anyDouble(),
                org.mockito.ArgumentMatchers.eq(EventNearbyService.MAX_RADIUS_M),
                any(), anyInt());
    }

    @Test
    @DisplayName("좌표가 없으면 400 — '주변' 을 계산할 방법이 없다")
    void 좌표_필수() {
        assertThatThrownBy(() -> service.nearby(null, 126.98, null))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.PLACE_INVALID_COORDINATE));

        assertThatThrownBy(() -> service.nearby(37.57, null, null))
                .isInstanceOf(ApiException.class);
    }

    @Test
    @DisplayName("범위를 벗어난 좌표도 400")
    void 좌표_범위() {
        assertThatThrownBy(() -> service.nearby(91.0, 126.98, null))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> service.nearby(37.57, 181.0, null))
                .isInstanceOf(ApiException.class);
    }

    @Test
    @DisplayName("커서가 없는 목록이라 상한을 둔다")
    void 결과_상한() {
        service.nearby(37.57, 126.98, null);

        ArgumentCaptor<Integer> limit = ArgumentCaptor.forClass(Integer.class);
        verify(events).findNearby(anyDouble(), anyDouble(), anyInt(), any(), limit.capture());
        assertThat(limit.getValue()).isEqualTo(EventNearbyService.MAX_RESULTS);
    }
}
