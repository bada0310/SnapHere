package com.snaphere.api.ranking;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RankingAggregationServiceTest {
    @Mock RankingRepository repository;

    @Test
    void 기간별_집계는_잠금_업서트_오래된행삭제_순서로_실행한다() {
        when(repository.upsert(eq(RankingPeriod.WEEKLY), any(), any())).thenReturn(12);
        RankingAggregationService service = new RankingAggregationService(repository);

        int changed = service.rebuild(RankingPeriod.WEEKLY);

        assertThat(changed).isEqualTo(12);
        var order = inOrder(repository);
        order.verify(repository).lockAggregation();
        ArgumentCaptor<OffsetDateTime> from = ArgumentCaptor.forClass(OffsetDateTime.class);
        ArgumentCaptor<OffsetDateTime> at = ArgumentCaptor.forClass(OffsetDateTime.class);
        order.verify(repository).upsert(eq(RankingPeriod.WEEKLY), from.capture(), at.capture());
        order.verify(repository).deleteStale(RankingPeriod.WEEKLY, at.getValue());
        assertThat(from.getValue()).isEqualTo(at.getValue().minusDays(7));
    }
}

