package com.snaphere.api.ranking;

import com.snaphere.api.place.PlaceDtos;

import java.math.BigDecimal;
import java.util.Map;

public final class RankingDtos {
    private RankingDtos() { }

    public record RankingEntry(int rank, Integer previousRank, Integer change,
                               BigDecimal score, PlaceDtos.PlaceSummary place,
                               String period, String theme) { }

    public record Recommendation(PlaceDtos.PlaceSummary place, String reasonCode,
                                 Map<String, Object> reasonParams, BigDecimal score) { }
}

