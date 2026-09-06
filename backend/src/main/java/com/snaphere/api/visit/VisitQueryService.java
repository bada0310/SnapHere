package com.snaphere.api.visit;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.place.entity.PlaceEntity;
import com.snaphere.api.place.repository.PlaceRepository;
import com.snaphere.api.post.dto.PlaceSummaryResponse;
import com.snaphere.api.visit.dto.VisitResponse;
import com.snaphere.api.visit.entity.VisitEntity;
import com.snaphere.api.visit.repository.VisitRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * API-VST-001 — 내 방문 기록 조회.
 *
 * <p>기능 명세: 해당 없음 — 방문 기록 목록은 화면 정의에 없다. 방문 지도(4.3)가 쓰는 데이터다
 * <p>요구사항: VST-003
 */
@Service
public class VisitQueryService {

    private final VisitRepository visits;
    private final PlaceRepository places;
    private final PagingProperties paging;

    public VisitQueryService(VisitRepository visits,
                             PlaceRepository places,
                             PagingProperties paging) {
        this.visits = visits;
        this.places = places;
        this.paging = paging;
    }

    /**
     * 내가 방문한 장소를 최신순으로. (VST-003)
     *
     * <p>장소 정보는 방문 행마다 조회하지 않고 한 번에 모아 붙인다 — 페이지 크기만큼 쿼리가
     * 늘어나는 자리다 (SYS-018).
     *
     * <p>같은 장소를 여러 날 갔으면 여러 건으로 나온다. 장소 목록이 아니라 방문 기록이고,
     * 며칠에 걸쳐 다녀온 것이 곧 발자국이다.
     */
    @Transactional(readOnly = true)
    public CursorPage<VisitResponse> myVisits(UUID userId, String cursor, Integer size) {
        int pageSize = paging.resolve(size);
        VisitCursor decoded = VisitCursor.decode(cursor);

        List<VisitEntity> rows = visits.findMine(
                userId,
                decoded == null ? null : decoded.visitedOn(),
                decoded == null ? null : decoded.visitId(),
                PageRequest.of(0, pageSize + 1));

        boolean hasNext = rows.size() > pageSize;
        List<VisitEntity> page = hasNext ? rows.subList(0, pageSize) : rows;
        if (page.isEmpty()) {
            return CursorPage.empty();
        }

        Map<Long, PlaceEntity> placeMap = loadPlaces(page);
        List<VisitResponse> items = new ArrayList<>(page.size());
        for (VisitEntity visit : page) {
            PlaceEntity place = placeMap.get(visit.getPlaceId());
            items.add(VisitResponse.of(visit,
                    place == null ? null : PlaceSummaryResponse.from(place)));
        }

        VisitEntity last = page.get(page.size() - 1);
        String nextCursor = hasNext
                ? new VisitCursor(last.getVisitedOn(), last.getVisitId()).encode()
                : null;
        return CursorPage.of(items, nextCursor);
    }

    private Map<Long, PlaceEntity> loadPlaces(List<VisitEntity> rows) {
        Set<Long> placeIds = new LinkedHashSet<>();
        for (VisitEntity visit : rows) {
            placeIds.add(visit.getPlaceId());
        }
        Map<Long, PlaceEntity> found = new LinkedHashMap<>();
        for (PlaceEntity place : places.findAllById(placeIds)) {
            found.put(place.getPlaceId(), place);
        }
        return found;
    }
}
