package com.snaphere.api.ranking;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

import java.util.Locale;

public enum RankingPlaceType {
    ALL,
    OFFICIAL,
    USER;

    public static RankingPlaceType parse(String value) {
        try {
            return value == null || value.isBlank()
                    ? ALL
                    : valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException error) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
    }
}

