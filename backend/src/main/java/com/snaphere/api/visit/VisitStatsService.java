package com.snaphere.api.visit;

import com.snaphere.api.place.PlaceDtos;
import com.snaphere.api.place.entity.RegionEntity;
import com.snaphere.api.place.repository.RegionRepository;
import com.snaphere.api.visit.dto.VisitRegionStatResponse;
import com.snaphere.api.visit.dto.VisitStatsResponse;
import com.snaphere.api.visit.repository.VisitRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * API-VST-002 — 방문 통계.
 *
 * <p>기능 명세: 4.3 방문 지도 &gt; 진행률 표시
 * <p>요구사항: VST-004, VST-008, VST-009
 */
@Service
public class VisitStatsService {

    private final VisitRepository visits;
    private final RegionRepository regions;

    public VisitStatsService(VisitRepository visits, RegionRepository regions) {
        this.visits = visits;
        this.regions = regions;
    }

    /**
     * 17개 시도 진행률과 지역별 분포. (VST-004, VST-008, VST-009)
     *
     * <p>집계는 DB 가 한 번에 한다. 방문 행을 다 읽어 자바에서 세면 오래 쓴 사용자의 응답이
     * 점점 느려진다.
     *
     * <p>전체 시도 수를 {@code regions} 에서 센다. 17 을 상수로 박으면 기준정보가 바뀔 때
     * 진행률만 조용히 틀린다. 어떤 이유로 기준정보가 비면 진행률은 0 이다 — 0 으로 나누는 대신
     * "아직 알 수 없음"을 0 으로 표현한다.
     */
    @Transactional(readOnly = true)
    public VisitStatsResponse of(UUID userId) {
        List<Object[]> counted = visits.aggregateByArea(userId);
        int totalRegionCount = (int) regions.count();

        Map<Integer, Object[]> byArea = new LinkedHashMap<>();
        for (Object[] row : counted) {
            byArea.put(((Number) row[0]).intValue(), row);
        }

        Map<Integer, RegionEntity> found = new LinkedHashMap<>();
        for (RegionEntity region : regions.findAllById(byArea.keySet())) {
            found.put(region.getAreaCode(), region);
        }

        List<VisitRegionStatResponse> stats = new ArrayList<>(byArea.size());
        for (Map.Entry<Integer, Object[]> entry : byArea.entrySet()) {
            RegionEntity region = found.get(entry.getKey());
            if (region == null) {
                // 기준정보에 없는 지역 코드다. 통계에서 빼되 방문 자체를 지우지는 않는다.
                continue;
            }
            Object[] row = entry.getValue();
            stats.add(new VisitRegionStatResponse(
                    toRegion(region),
                    ((Number) row[1]).longValue(),
                    ((Number) row[2]).longValue(),
                    (LocalDate) row[3]));
        }

        double progress = totalRegionCount <= 0
                ? 0d
                : (double) stats.size() / totalRegionCount;
        return new VisitStatsResponse(stats.size(), totalRegionCount, progress, stats);
    }

    /**
     * 시도 코드는 비연속이다 (1~8, 31~39).
     *
     * <p>{@code defaultEventVerifyRadiusM} 은 null 을 허용하는 컬럼이라 0 으로 내린다. 이 화면은
     * 반경을 쓰지 않으므로 값이 없다는 사실을 굳이 클라이언트까지 전달하지 않는다.
     */
    private static PlaceDtos.Region toRegion(RegionEntity region) {
        return new PlaceDtos.Region(
                region.getAreaCode(),
                region.getNameKo(),
                region.getNameEn(),
                region.getRepresentativeImageUrl(),
                region.getDefaultEventVerifyRadiusM() == null
                        ? 0
                        : region.getDefaultEventVerifyRadiusM());
    }
}
