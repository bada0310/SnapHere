package com.snaphere.api.post;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.place.EventSnapshot;
import com.snaphere.api.place.EventSnapshotReader;
import com.snaphere.api.place.PlaceSnapshot;
import com.snaphere.api.place.PlaceSnapshotReader;
import com.snaphere.api.post.dto.TierPreviewRequest;
import com.snaphere.api.post.tier.GeoDistance;
import com.snaphere.api.post.tier.TierDecision;
import com.snaphere.api.post.tier.TierDecisionLogger;
import com.snaphere.api.post.tier.TierInput;
import com.snaphere.api.post.tier.TierPolicy;
import com.snaphere.api.post.tier.TierThresholds;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.UUID;

/**
 * 업로드 전 등급 미리보기. (PST-048)
 *
 * <p>기능 명세: 2.2 위치 확인 &gt; 등급 미리보기
 *
 * <p>게시글 등록(API-PST-003)도 같은 {@link TierPolicy} 를 쓴다. 미리보기와 실제 판정이
 * 다른 결과를 내면 사용자가 속았다고 느끼므로 규칙을 한 곳에만 둔다.
 */
@Service
public class TierPreviewService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul"); // SYS-005

    private final PlaceSnapshotReader placeReader;
    private final EventSnapshotReader eventReader;
    private final TierDecisionLogger decisionLogger;

    public TierPreviewService(PlaceSnapshotReader placeReader,
                              EventSnapshotReader eventReader,
                              TierDecisionLogger decisionLogger) {
        this.placeReader = placeReader;
        this.eventReader = eventReader;
        this.decisionLogger = decisionLogger;
    }

    public TierDecision preview(UUID userId, TierPreviewRequest request) {
        OffsetDateTime now = OffsetDateTime.now(KST);
        validateTakenAt(request.takenAt(), now);

        PlaceSnapshot place = placeReader.findById(request.placeId())
                .orElseThrow(() -> new ApiException(ErrorCode.PLACE_NOT_FOUND,
                        Map.of("placeId", request.placeId())));

        EventSnapshot event = null;
        if (request.eventId() != null) {
            event = eventReader.findById(request.eventId())
                    .orElseThrow(() -> new ApiException(ErrorCode.EVENT_NOT_FOUND,
                            Map.of("eventId", request.eventId())));
        }

        // 실제 게시 등록과 반드시 같은 200m 사진 위치 인증 규칙을 사용한다.
        int radiusM = 200;
        Integer distanceM = distanceOrNull(place, request);

        TierInput input = new TierInput(request.source(), request.takenAt(), distanceM,
                radiusM, place.hasCoordinate(), now);
        TierDecision decision = TierPolicy.decide(input, TierThresholds.DEFAULT);

        decisionLogger.record(null, userId, place.placeId(),
                event == null ? null : event.eventId(), input, decision);
        return decision;
    }

    /** 촬영 좌표가 없으면 거리를 계산하지 않는다. 그 자체가 낮음 판정 근거다 (PST-025). */
    private Integer distanceOrNull(PlaceSnapshot place, TierPreviewRequest request) {
        if (!request.hasCoordinate() || !place.hasCoordinate()) {
            return null;
        }
        return GeoDistance.meters(place.lat(), place.lng(), request.lat(), request.lng());
    }

    /** 기기 시계가 크게 앞선 사진은 판정 근거로 쓸 수 없다. */
    private void validateTakenAt(OffsetDateTime takenAt, OffsetDateTime now) {
        if (takenAt != null && takenAt.isAfter(now.plusDays(1))) {
            throw new ApiException(ErrorCode.POST_INVALID_TAKEN_AT,
                    Map.of("takenAt", takenAt.toString()));
        }
    }
}
