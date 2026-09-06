package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.util.Locale;

public enum RankingScope {
    NATIONAL,
    REGION;

    public static RankingScope parse(String value) {
        try {
            if (value == null || value.isBlank()) throw new IllegalArgumentException();
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException error) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
    }
}

