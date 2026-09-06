package com.snaphere.api.visit;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.CollectedBadgeReader;
import com.snaphere.api.post.dto.BadgeSummaryResponse;
import com.snaphere.api.visit.dto.VisitMapBoundsResponse;
import com.snaphere.api.visit.dto.VisitMapPointResponse;
import com.snaphere.api.visit.dto.VisitMapResponse;
import com.snaphere.api.visit.dto.VisitStatsResponse;
import com.snaphere.api.visit.repository.VisitRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * API-VST-003 — 방문 지도.
 *
 * <p>기능 명세: 4.3 방문 지도
 * <p>요구사항: VST-007, VST-008, VST-009, VST-010
 *
 * <p>화면 하나가 쓰는 값을 한 번에 준다. 마커·채색·진행률·뱃지를 각각 부르게 하면 요청이 넷이
 * 되고, 그 사이에 방문이 하나 기록되면 지도와 진행률이 서로 다른 시점을 보여 준다.
 */
@Service
public class VisitMapService {

    /**
     * 마커 상한. 오래 쓴 사용자는 방문 장소가 수천 개가 될 수 있고, 그만큼 내려보내면 응답이
     * 커지는 것보다 클라이언트가 지도에 다 찍지 못하는 것이 먼저 문제가 된다. 잘릴 때는 방문
     * 횟수가 많은 곳이 남는다.
     */
    private static final int MAX_POINTS = 500;

    /** 지도 하단 요약이라 전부 내리지 않는다. 수집함 화면은 BDG 조회 API 가 따로 담당한다. */
    private static final int MAX_BADGES = 20;

    private final VisitRepository visits;
    private final VisitStatsService visitStatsService;
    private final CollectedBadgeReader badges;

    public VisitMapService(VisitRepository visits,
                           VisitStatsService visitStatsService,
                           CollectedBadgeReader badges) {
        this.visits = visits;
        this.visitStatsService = visitStatsService;
        this.badges = badges;
    }

    /** 마커·경계·시도 집계·수집 뱃지. (VST-007 ~ VST-010) */
    @Transactional(readOnly = true)
    public VisitMapResponse of(UUID userId) {
        List<Object[]> rows = visits.findVisitMapPoints(userId, PageRequest.of(0, MAX_POINTS));

        List<VisitMapPointResponse> points = new ArrayList<>(rows.size());
        for (Object[] row : rows) {
            points.add(new VisitMapPointResponse(
                    ExternalIds.place(((Number) row[0]).longValue()),
                    ((Number) row[1]).doubleValue(),
                    ((Number) row[2]).doubleValue(),
                    ((Number) row[3]).longValue()));
        }

        VisitStatsResponse stats = visitStatsService.of(userId);

        List<BadgeSummaryResponse> collected = new ArrayList<>();
        for (AwardedBadge badge : badges.findCollected(userId, MAX_BADGES)) {
            collected.add(BadgeSummaryResponse.from(badge));
        }

        return new VisitMapResponse(points, boundsOf(points), stats, collected);
    }

    /**
     * 마커 전체를 담는 사각형. 마커가 없으면 null 이다 — 0,0 을 주면 지도가 기니 만 앞바다를
     * 비춘다.
     *
     * <p>대한민국 안에서만 도는 서비스라(GeoUtils 서비스 범위) 경도 180도 경계를 넘는 경우를
     * 다루지 않는다. 태평양을 가로지르는 방문 목록이 생기면 여기서부터 다시 봐야 한다.
     */
    private static VisitMapBoundsResponse boundsOf(List<VisitMapPointResponse> points) {
        if (points.isEmpty()) {
            return null;
        }
        double south = Double.MAX_VALUE;
        double north = -Double.MAX_VALUE;
        double west = Double.MAX_VALUE;
        double east = -Double.MAX_VALUE;
        for (VisitMapPointResponse point : points) {
            south = Math.min(south, point.lat());
            north = Math.max(north, point.lat());
            west = Math.min(west, point.lng());
            east = Math.max(east, point.lng());
        }
        return new VisitMapBoundsResponse(south, west, north, east);
    }
}
