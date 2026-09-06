package com.snaphere.api.event;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.event.dto.EventSummaryResponse;
import com.snaphere.api.event.entity.EventEntity;
import com.snaphere.api.event.repository.EventRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

/**
 * API-EVT-002 — 주변 행사. (EVT-015)
 *
 * <p>기능 명세: 3.1 이벤트 홈 (현재 위치 기준 탐색)
 *
 * <p>장소 주변 검색(MAP-027)의 20km 와 숫자가 같지만 별개 기준이다. 축제는 하루 이동을
 * 감수하고 찾아가는 대상이라 반경이 넓어도 의미가 있고, 장소 탐색과 함께 조정되지 않아야 한다.
 */
@Service
public class EventNearbyService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    /** 명세 API-EVT-002: 기본 20,000m, 최대 50,000m */
    static final int DEFAULT_RADIUS_M = 20_000;
    static final int MAX_RADIUS_M = 50_000;

    /** 커서가 없는 목록이라 상한을 둔다. 지도 위에 찍을 수 있는 수를 넘기면 앱이 느려진다. */
    static final int MAX_RESULTS = 50;

    private final EventRepository events;

    public EventNearbyService(EventRepository events) {
        this.events = events;
    }

    @Transactional(readOnly = true)
    public List<EventSummaryResponse> nearby(Double lat, Double lng, Integer radiusM) {
        double latitude = requireCoordinate(lat, "lat", -90, 90);
        double longitude = requireCoordinate(lng, "lng", -180, 180);

        OffsetDateTime now = OffsetDateTime.now(KST);
        LocalDate today = now.toLocalDate();

        List<EventEntity> rows = events.findNearby(
                latitude, longitude, resolveRadius(radiusM), today, MAX_RESULTS);

        return EventDetailService.summaries(rows, today, now);
    }

    /**
     * 좌표는 필수다. 목록 조회의 다른 파라미터와 달리 조용히 넘길 수 없다 — 위치 없이
     * "주변" 을 계산할 방법이 없고, 임의의 기본 좌표를 쓰면 엉뚱한 지역 행사를 주변이라고
     * 내보내게 된다.
     */
    private static double requireCoordinate(Double value, String field, double min, double max) {
        if (value == null || value < min || value > max) {
            throw new ApiException(ErrorCode.PLACE_INVALID_COORDINATE, Map.of("field", field));
        }
        return value;
    }

    /** 범위 밖 반경은 400 이 아니라 상한으로 자른다 — 페이지 크기와 같은 규약이다 (SYS-003). */
    private static int resolveRadius(Integer requested) {
        if (requested == null || requested <= 0) {
            return DEFAULT_RADIUS_M;
        }
        return Math.min(requested, MAX_RADIUS_M);
    }
}
