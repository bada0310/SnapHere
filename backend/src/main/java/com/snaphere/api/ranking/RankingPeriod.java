package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.time.OffsetDateTime;
import java.util.Locale;

public enum RankingPeriod {
    DAILY,
    WEEKLY,
    MONTHLY,
    ALL;

    public OffsetDateTime from(OffsetDateTime now) {
        return switch (this) {
            case DAILY -> now.minusDays(1);
            case WEEKLY -> now.minusDays(7);
            case MONTHLY -> now.minusMonths(1);
            case ALL -> null;
        };
    }

    public static RankingPeriod parse(String value) {
        try {
            return value == null || value.isBlank()
                    ? WEEKLY
                    : valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException error) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
    }
}

