package com.snaphere.api.ranking;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "snaphere.jobs", name = "enabled", matchIfMissing = true)
public class RankingJobs {
    private static final Logger log = LoggerFactory.getLogger(RankingJobs.class);

    private final RankingAggregationService aggregation;

    public RankingJobs(RankingAggregationService aggregation) {
        this.aggregation = aggregation;
    }

    /** JOB-008. 실패한 기간만 건너뛰고 다른 기간 결과는 계속 갱신한다. */
    @Scheduled(fixedDelayString = "${snaphere.jobs.ranking-delay:PT10M}", initialDelayString = "PT50S")
    public void recalc() {
        for (RankingPeriod period : RankingPeriod.values()) {
            try {
                log.info("장소 랭킹 집계 완료. period={} rows={}", period, aggregation.rebuild(period));
            } catch (RuntimeException failure) {
                log.error("장소 랭킹 집계 실패. period={}", period, failure);
            }
        }
    }
}

