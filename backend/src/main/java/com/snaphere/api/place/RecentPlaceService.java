package com.snaphere.api.place;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.web.CursorCodec;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.config.PlaceTaskConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * API-USER-011 — 최근 본 장소. (VST-006)
 *
 * <p>기능 명세: 해당 없음 — 화면 정의에 없다. 탐색 화면이 쓰는 보조 데이터다
 *
 * <p><b>왜 Redis 인가.</b> 요구사항이 "유실돼도 무방한 데이터"로 못박았고(VST-006 비고),
 * 장소 상세를 열 때마다 쓰기가 일어나 DB 로 받으면 조회 화면이 쓰기 부하를 만든다. 명세는
 * 저장소를 미정으로 남겨 두었다 — 앱 로컬·Redis·별도 테이블 중 Redis 로 정한다.
 *
 * <p>Redis 가 죽으면 기록은 조용히 버리고 조회는 빈 목록을 준다. 최근 본 장소가 비는 것과
 * 장소 상세가 500 이 되는 것 중에는 앞이 낫다. {@link ViewCounterService} 는 조회수를 DB 로
 * 되돌리지만 여기는 되돌릴 곳이 없다 — 그것이 이 데이터의 성격이다.
 */
@Service
public class RecentPlaceService {

    private static final Logger log = LoggerFactory.getLogger(RecentPlaceService.class);
    private static final String PREFIX = "place:recent:";

    /**
     * 사용자당 보관 개수. 최근 목록이라 오래된 것은 의미가 없고, 상한이 없으면 활동량이 많은
     * 사용자 하나가 키 하나를 무한히 키운다.
     */
    private static final int MAX_KEEP = 50;

    /** 한동안 안 들어온 사용자의 키를 남겨 두지 않는다. 다시 오면 그때부터 다시 쌓인다. */
    private static final Duration TTL = Duration.ofDays(30);

    private static final int DEFAULT_SIZE = 20;
    private static final int MAX_SIZE = 50;

    private final StringRedisTemplate redis;
    private final PlaceRepository places;

    public RecentPlaceService(StringRedisTemplate redis, PlaceRepository places) {
        this.redis = redis;
        this.places = places;
    }

    /**
     * 장소 상세를 열면 최근 목록 맨 앞으로 올린다. (VST-006)
     *
     * <p>같은 장소를 다시 봐도 행이 늘지 않는다 — ZSET 이 점수만 갱신한다. 그래서 "최근 본
     * 20곳"이 같은 장소 20개로 채워지지 않는다.
     *
     * <p>비동기다. 최근 목록 기록이 장소 상세 응답을 늦추면 안 된다.
     */
    @Async(PlaceTaskConfig.PLACE_TASK_EXECUTOR)
    public void record(UUID userId, long placeId) {
        if (userId == null) {
            return;
        }
        String key = PREFIX + userId;
        try {
            redis.opsForZSet().add(key, Long.toString(placeId), System.currentTimeMillis());
            // 점수가 낮은 쪽(오래된 것)부터 잘라 MAX_KEEP 개만 남긴다.
            redis.opsForZSet().removeRange(key, 0, -(MAX_KEEP + 1L));
            redis.expire(key, TTL);
        } catch (RuntimeException e) {
            log.debug("최근 본 장소 기록 실패 userId={} placeId={}", userId, placeId, e);
        }
    }

    /**
     * 최근 본 순서대로 한 페이지. (VST-006)
     *
     * <p>커서는 ZSET 안의 순위다. 목록이 최대 {@value #MAX_KEEP} 개로 짧고 점수가 시각이라,
     * 페이지를 넘기는 사이에 같은 장소를 다시 보면 그 장소가 앞으로 올라가면서 뒷 페이지가 한
     * 칸씩 밀린다. 유실돼도 무방한 데이터라 이 어긋남은 받아들인다 — 정확한 커서를 만들려면
     * 시각을 키로 써야 하고, 그러면 "다시 본 장소가 맨 앞으로 온다"를 포기해야 한다.
     *
     * <p>장소 정보는 한 번에 모아 붙인다. ID 목록만 Redis 에 있고 이름·좌표는 DB 에 있다.
     */
    public CursorPage<PlaceDtos.PlaceSummary> recent(UUID userId, String cursor, int size) {
        int pageSize = size < 1 ? DEFAULT_SIZE : Math.min(size, MAX_SIZE);
        Long decoded = CursorCodec.decode(cursor);
        long start = decoded == null ? 0L : decoded;

        Set<String> ids;
        try {
            ids = redis.opsForZSet().reverseRange(PREFIX + userId, start, start + pageSize);
        } catch (RuntimeException e) {
            log.warn("최근 본 장소 조회 실패 userId={}", userId, e);
            return CursorPage.empty();
        }
        if (ids == null || ids.isEmpty()) {
            return CursorPage.empty();
        }

        List<Long> ordered = new ArrayList<>(ids.size());
        for (String id : ids) {
            try {
                ordered.add(Long.parseLong(id));
            } catch (NumberFormatException ignored) {
                // 형식이 깨진 값은 버린다. 이 목록은 복구 대상이 아니다.
            }
        }

        boolean hasNext = ordered.size() > pageSize;
        List<Long> page = hasNext ? ordered.subList(0, pageSize) : ordered;

        // 조회 결과를 외부 ID 로 색인해 Redis 가 준 순서대로 다시 세운다. IN 조회는 순서를
        // 보장하지 않고, 최근 본 순서가 이 목록의 존재 이유다.
        Map<String, PlaceDtos.PlaceSummary> found = new LinkedHashMap<>();
        for (PlaceDtos.PlaceSummary place : places.summaries(page, userId)) {
            found.put(place.placeId(), place);
        }

        List<PlaceDtos.PlaceSummary> items = new ArrayList<>(page.size());
        for (Long placeId : page) {
            // 숨김·삭제된 장소는 조회에서 빠져 여기서 걸러진다.
            PlaceDtos.PlaceSummary place = found.get(ExternalIds.place(placeId));
            if (place != null) {
                items.add(place);
            }
        }

        String nextCursor = hasNext ? CursorCodec.encode(start + pageSize) : null;
        return CursorPage.of(items, nextCursor);
    }
}
