package com.snaphere.api.post.tier;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

/** 위치 신뢰 등급 판정 규칙 — PST-022 ~ PST-026 */
class TierPolicyTest {

    private static final OffsetDateTime NOW =
            OffsetDateTime.of(2026, 9, 2, 12, 0, 0, 0, ZoneOffset.ofHours(9));
    private static final int RADIUS = 500;

    private static TierInput input(PhotoSource source, OffsetDateTime takenAt, Integer distanceM) {
        return new TierInput(source, takenAt, distanceM, RADIUS, true, NOW);
    }

    private static TierDecision decide(TierInput in) {
        return TierPolicy.decide(in, TierThresholds.DEFAULT);
    }

    private static TierInput inputAt200m(PhotoSource source, OffsetDateTime takenAt, int distanceM) {
        return new TierInput(source, takenAt, distanceM, 200, true, NOW);
    }

    @Nested
    @DisplayName("높음 (PST-023)")
    class 높음 {

        @Test
        @DisplayName("카메라로 촬영 5분 뒤, 반경 안이면 높음")
        void 카메라_5분_반경안() {
            TierDecision d = decide(input(PhotoSource.CAMERA, NOW.minusMinutes(5), 120));

            assertThat(d.tier()).isEqualTo(TrustTier.HIGH);
            assertThat(d.reason()).isEqualTo(TierReason.ON_SITE_CAMERA);
            assertThat(d.tier().rankingWeight()).isEqualTo(3.0);
            assertThat(d.improvementHints()).isEmpty();
        }

        @Test
        @DisplayName("정확히 10분은 높음 (경계값)")
        void 카메라_10분_경계() {
            assertThat(decide(input(PhotoSource.CAMERA, NOW.minusMinutes(10), 120)).tier())
                    .isEqualTo(TrustTier.HIGH);
        }

        @Test
        @DisplayName("11분이면 높음이 아니라 보통")
        void 카메라_11분() {
            assertThat(decide(input(PhotoSource.CAMERA, NOW.minusMinutes(11), 120)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
        }

        @Test
        @DisplayName("앨범 사진은 촬영 직후라도 높음이 아니다")
        void 앨범은_높음_불가() {
            assertThat(decide(input(PhotoSource.ALBUM, NOW.minusMinutes(1), 120)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
        }

        @Test
        @DisplayName("기기 시계가 앞서 미래 시각이어도 카메라면 높음으로 본다")
        void 미래_시각_보정() {
            assertThat(decide(input(PhotoSource.CAMERA, NOW.plusMinutes(3), 120)).tier())
                    .isEqualTo(TrustTier.HIGH);
        }
    }

    @Nested
    @DisplayName("보통 (PST-024)")
    class 보통 {

        @Test
        @DisplayName("30일 이내 촬영, 반경 안이면 보통")
        void 며칠전_반경안() {
            TierDecision d = decide(input(PhotoSource.ALBUM, NOW.minusDays(3), 300));

            assertThat(d.tier()).isEqualTo(TrustTier.MEDIUM);
            assertThat(d.reason()).isEqualTo(TierReason.RECENT_WITHIN_RADIUS);
            assertThat(d.tier().rankingWeight()).isEqualTo(1.8);
            assertThat(d.daysSinceTaken()).isEqualTo(3L);
            assertThat(d.improvementHints()).contains(TierImprovementHint.SHOOT_NOW_WITH_CAMERA);
        }

        @Test
        @DisplayName("정확히 30일은 보통 (경계값)")
        void 삼십일_경계() {
            assertThat(decide(input(PhotoSource.ALBUM, NOW.minusDays(30), 300)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
        }
    }

    @Nested
    @DisplayName("낮음 (PST-025)")
    class 낮음 {

        @Test
        @DisplayName("사진 위치 199m·200m는 인증하고 201m는 인증하지 않는다")
        void 사진위치_이백미터_경계() {
            assertThat(decide(inputAt200m(PhotoSource.ALBUM, NOW.minusDays(1), 199)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
            assertThat(decide(inputAt200m(PhotoSource.ALBUM, NOW.minusDays(1), 200)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
            assertThat(decide(inputAt200m(PhotoSource.ALBUM, NOW.minusDays(1), 201)).reason())
                    .isEqualTo(TierReason.OUT_OF_RADIUS);
        }

        @Test
        @DisplayName("촬영 좌표가 없으면 낮음")
        void 좌표_없음() {
            TierDecision d = decide(input(PhotoSource.ALBUM, NOW.minusDays(1), null));

            assertThat(d.tier()).isEqualTo(TrustTier.LOW);
            assertThat(d.reason()).isEqualTo(TierReason.NO_TAKEN_COORDINATE);
            assertThat(d.hasTakenCoordinate()).isFalse();
            assertThat(d.improvementHints())
                    .contains(TierImprovementHint.ENABLE_LOCATION_ON_CAMERA);
        }

        @Test
        @DisplayName("반경 밖이면 촬영 시각과 무관하게 낮음")
        void 반경_밖() {
            TierDecision d = decide(input(PhotoSource.CAMERA, NOW.minusMinutes(1), RADIUS + 1));

            assertThat(d.tier()).isEqualTo(TrustTier.LOW);
            assertThat(d.reason()).isEqualTo(TierReason.OUT_OF_RADIUS);
            assertThat(d.withinRadius()).isFalse();
            assertThat(d.improvementHints()).contains(TierImprovementHint.TAKE_CLOSER_TO_PLACE);
        }

        @Test
        @DisplayName("반경 경계값은 안쪽으로 본다")
        void 반경_경계값() {
            assertThat(decide(input(PhotoSource.ALBUM, NOW.minusDays(1), RADIUS)).tier())
                    .isEqualTo(TrustTier.MEDIUM);
        }

        @Test
        @DisplayName("31일 지난 사진은 반경 안이어도 낮음")
        void 오래된_사진() {
            TierDecision d = decide(input(PhotoSource.ALBUM, NOW.minusDays(31), 100));

            assertThat(d.tier()).isEqualTo(TrustTier.LOW);
            assertThat(d.reason()).isEqualTo(TierReason.TAKEN_TOO_LONG_AGO);
            assertThat(d.improvementHints()).contains(TierImprovementHint.USE_RECENT_PHOTO);
        }

        @Test
        @DisplayName("촬영 시각을 모르면 낮음")
        void 촬영시각_없음() {
            assertThat(decide(input(PhotoSource.ALBUM, null, 100)).reason())
                    .isEqualTo(TierReason.NO_TAKEN_AT);
        }

        @Test
        @DisplayName("장소에 좌표가 없으면 판정 불가로 낮음 (PLC-007)")
        void 장소_좌표_없음() {
            TierInput in = new TierInput(PhotoSource.CAMERA, NOW.minusMinutes(1), 10, RADIUS, false, NOW);

            assertThat(decide(in).reason()).isEqualTo(TierReason.PLACE_HAS_NO_COORDINATE);
        }

        @Test
        @DisplayName("낮음은 0점이 아니라 0.5점이며 뱃지·방문·히트맵에서만 빠진다 (PST-026)")
        void 낮음_혜택_제외() {
            TrustTier low = decide(input(PhotoSource.ALBUM, NOW.minusDays(1), null)).tier();

            assertThat(low.rankingWeight()).isEqualTo(0.5);
            assertThat(low.eligibleForBadge()).isFalse();
            assertThat(low.countsForVisit()).isFalse();
            assertThat(low.countsForHeatmap()).isFalse();
        }
    }

    @Test
    @DisplayName("판정 로그에 임계값 스냅샷이 남는다 (PST-028)")
    void 임계값_스냅샷() {
        TierDecision d = decide(input(PhotoSource.CAMERA, NOW.minusMinutes(5), 120));

        assertThat(d.thresholds().highWithinMinutes()).isEqualTo(10);
        assertThat(d.thresholds().mediumWithinDays()).isEqualTo(30);
        assertThat(d.appliedRadiusM()).isEqualTo(RADIUS);
        assertThat(d.decidedAt()).isEqualTo(NOW);
    }

    @Test
    @DisplayName("임계값을 바꾸면 판정도 바뀐다 — 기준이 데이터임을 보장")
    void 임계값_변경() {
        TierInput in = input(PhotoSource.CAMERA, NOW.minusMinutes(20), 120);

        assertThat(TierPolicy.decide(in, TierThresholds.DEFAULT).tier()).isEqualTo(TrustTier.MEDIUM);
        assertThat(TierPolicy.decide(in, new TierThresholds(30, 30)).tier()).isEqualTo(TrustTier.HIGH);
    }

    @Test
    @DisplayName("높음·보통만 방문 기록과 뱃지 대상이다 (VST-001, BDG-005)")
    void 혜택_등급() {
        assertThat(TrustTier.HIGH.countsForVisit()).isTrue();
        assertThat(TrustTier.MEDIUM.countsForVisit()).isTrue();
        assertThat(TrustTier.LOW.countsForVisit()).isFalse();
    }
}
