package com.snaphere.api.place;

import com.snaphere.api.common.web.CursorPage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 최근 본 장소 — VST-006
 *
 * <p>Redis 순서를 DB 조회가 흐트러뜨리지 않는지, Redis 가 죽었을 때 화면을 죽이지 않는지가
 * 이 서비스의 판단이다.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class RecentPlaceServiceTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");
    private static final String KEY = "place:recent:" + USER;

    @Mock private StringRedisTemplate redis;
    @Mock private ZSetOperations<String, String> zset;
    @Mock private PlaceRepository places;

    private RecentPlaceService service;

    @BeforeEach
    void setUp() {
        service = new RecentPlaceService(redis, places);
        when(redis.opsForZSet()).thenReturn(zset);
    }

    private static PlaceDtos.PlaceSummary place(String externalId, String title) {
        return new PlaceDtos.PlaceSummary(externalId, "TOURIST", title, "서울", null,
                37.5, 127.0, 0, 0, null, null, null);
    }

    private static LinkedHashSet<String> ids(String... values) {
        return new LinkedHashSet<>(List.of(values));
    }

    @Test
    @DisplayName("Redis 가 준 최근 순서를 DB 조회 결과로 다시 세운다 — IN 조회는 순서를 보장하지 않는다")
    void keepsRecentOrder() {
        when(zset.reverseRange(eq(KEY), anyLong(), anyLong())).thenReturn(ids("2", "1"));
        // 일부러 뒤집어 돌려준다.
        when(places.summaries(any(), any())).thenReturn(List.of(
                place("plc_1", "경복궁"), place("plc_2", "창덕궁")));

        CursorPage<PlaceDtos.PlaceSummary> page = service.recent(USER, null, 20);

        assertThat(page.items()).extracting(PlaceDtos.PlaceSummary::title)
                .containsExactly("창덕궁", "경복궁");
    }

    @Test
    @DisplayName("숨김·삭제되어 조회에서 빠진 장소는 목록에서도 뺀다 — 누르면 404 가 날 칸이다")
    void skipsMissingPlace() {
        when(zset.reverseRange(eq(KEY), anyLong(), anyLong())).thenReturn(ids("1", "2"));
        when(places.summaries(any(), any())).thenReturn(List.of(place("plc_1", "경복궁")));

        assertThat(service.recent(USER, null, 20).items())
                .extracting(PlaceDtos.PlaceSummary::title).containsExactly("경복궁");
    }

    @Test
    @DisplayName("Redis 가 죽으면 빈 목록이다 — 최근 목록 때문에 화면이 500 이 되면 안 된다")
    void redisDownReturnsEmpty() {
        when(zset.reverseRange(anyString(), anyLong(), anyLong()))
                .thenThrow(new IllegalStateException("redis down"));

        CursorPage<PlaceDtos.PlaceSummary> page = service.recent(USER, null, 20);

        assertThat(page.items()).isEmpty();
        assertThat(page.hasNext()).isFalse();
        verify(places, never()).summaries(any(), any());
    }

    @Test
    @DisplayName("요청 크기보다 하나 더 읽어 다음 페이지를 판단한다")
    void paginates() {
        when(zset.reverseRange(eq(KEY), eq(0L), eq(2L))).thenReturn(ids("3", "2", "1"));
        when(places.summaries(any(), any())).thenReturn(List.of(
                place("plc_3", "가"), place("plc_2", "나")));

        CursorPage<PlaceDtos.PlaceSummary> page = service.recent(USER, null, 2);

        assertThat(page.items()).hasSize(2);
        assertThat(page.hasNext()).isTrue();
        assertThat(page.nextCursor()).isNotNull();
    }

    @Test
    @DisplayName("기록은 점수를 갱신하고 오래된 것을 잘라내며 만료를 건다")
    void recordTrimsAndExpires() {
        service.record(USER, 5L);

        verify(zset).add(eq(KEY), eq("5"), anyDouble());
        verify(zset).removeRange(KEY, 0, -51L);
        verify(redis).expire(eq(KEY), any());
    }

    @Test
    @DisplayName("비회원은 남길 곳이 없어 아무것도 하지 않는다")
    void anonymousIsSkipped() {
        service.record(null, 5L);

        verify(redis, never()).opsForZSet();
    }

    @Test
    @DisplayName("Redis 가 죽어도 기록 실패가 장소 상세를 깨뜨리지 않는다")
    void recordSwallowsRedisFailure() {
        when(zset.add(anyString(), anyString(), anyDouble()))
                .thenThrow(new IllegalStateException("redis down"));

        service.record(USER, 5L);
    }
}
