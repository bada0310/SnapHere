package com.snaphere.api.ranking;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;

@Service
public class RankingAggregationService {
    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final OffsetDateTime EPOCH = OffsetDateTime.ofInstant(Instant.EPOCH, ZoneOffset.UTC);

    private final RankingRepository rankings;

    public RankingAggregationService(RankingRepository rankings) {
        this.rankings = rankings;
    }

    /** 기간 하나가 한 트랜잭션이다. 다른 기간 실패가 이미 계산된 결과를 되돌리지 않는다. */
    @Transactional
    public int rebuild(RankingPeriod period) {
        rankings.lockAggregation();
        OffsetDateTime calculatedAt = OffsetDateTime.now(KST);
        OffsetDateTime from = period.from(calculatedAt);
        int upserted = rankings.upsert(period, from == null ? EPOCH : from, calculatedAt);
        rankings.deleteStale(period, calculatedAt);
        return upserted;
    }
}

