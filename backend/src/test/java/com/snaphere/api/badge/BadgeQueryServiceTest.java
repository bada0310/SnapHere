package com.snaphere.api.badge;

import com.snaphere.api.badge.dto.BadgeCollectionResponse;
import com.snaphere.api.badge.dto.BadgeDetailResponse;
import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.badge.entity.UserBadgeEntity;
import com.snaphere.api.badge.repository.BadgeRepository;
import com.snaphere.api.badge.repository.UserBadgeRepository;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.when;

/** 뱃지 수집함·상세 — BDG-009 ~ BDG-013 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BadgeQueryServiceTest {

    private static final UUID OWNER = UUID.fromString("11111111-1111-1111-1111-111111111111");
    private static final OffsetDateTime EARNED_AT =
            OffsetDateTime.parse("2026-09-01T10:00:00+09:00");

    @Mock
    private BadgeRepository badges;
    @Mock
    private UserBadgeRepository userBadges;
    @Mock
    private BadgeProgress progress;

    private BadgeQueryService service;

    @BeforeEach
    void setUp() {
        service = new BadgeQueryService(badges, userBadges, progress);
        when(userBadges.findByUserIdAndBadgeIds(any(), any())).thenReturn(List.of());
        when(badges.countObtainable()).thenReturn(2L);
    }

    @Test
    @DisplayName("미획득 뱃지도 함께 준다 — 화면이 회색으로 그린다 (BDG-010)")
    void 미획득_포함() {
        when(badges.findCollection(OWNER)).thenReturn(List.of(earned(), unearned()));
        when(userBadges.findByUserIdAndBadgeIds(any(), any()))
                .thenReturn(List.of(UserBadgeEntity.of(OWNER, 1L, 100L, EARNED_AT)));

        BadgeCollectionResponse collection = service.collection(OWNER, null, "ko");

        assertThat(collection.items()).hasSize(2);
        assertThat(collection.earnedCount()).isEqualTo(1);
        assertThat(collection.items().get(0).earned()).isTrue();
        assertThat(collection.items().get(0).earnedAt()).isEqualTo(EARNED_AT);
        assertThat(collection.items().get(1).earned()).isFalse();
        assertThat(collection.items().get(1).earnedAt()).isNull();
    }

    @Test
    @DisplayName("분류를 고르면 그 분류만 조회한다 (BDG-011)")
    void 분류_필터() {
        when(badges.findCollectionByType(OWNER, BadgeType.AREA)).thenReturn(List.of(unearned()));
        when(badges.countObtainableByType(BadgeType.AREA)).thenReturn(1L);

        BadgeCollectionResponse collection = service.collection(OWNER, "AREA", "ko");

        assertThat(collection.items()).hasSize(1);
        assertThat(collection.obtainableCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("Accept-Language 가 en 이면 영어 이름")
    void 다국어() {
        when(badges.findCollection(OWNER)).thenReturn(List.of(earned()));

        assertThat(service.collection(OWNER, null, "en").items().get(0).name())
                .isEqualTo("Badge 1");
        assertThat(service.collection(OWNER, null, "ko").items().get(0).name())
                .isEqualTo("뱃지 1");
    }

    @Test
    @DisplayName("badgeId 는 bdg_ 외부 ID")
    void 외부_id() {
        when(badges.findCollection(OWNER)).thenReturn(List.of(earned()));

        assertThat(service.collection(OWNER, null, "ko").items().get(0).badgeId())
                .startsWith("bdg_");
    }

    @Test
    @DisplayName("상세는 해석된 조건과 진행값을 준다 (BDG-013)")
    void 상세() {
        BadgeEntity badge = BadgeFixtures.badge(2L, BadgeType.AREA,
                BadgeFixtures.condition("AREA_POST_COUNT", 5), true, null, 1);
        when(badges.findById(2L)).thenReturn(Optional.of(badge));
        when(userBadges.findOne(OWNER, 2L)).thenReturn(Optional.empty());
        when(progress.currentValue(any(), any())).thenReturn(3);

        BadgeDetailResponse detail = service.detail(2L, OWNER, "ko");

        assertThat(detail.condition()).containsEntry("type", "AREA_POST_COUNT");
        assertThat(detail.currentValue()).isEqualTo(3);
        assertThat(detail.targetValue()).isEqualTo(5);
        assertThat(detail.badge().earned()).isFalse();
        assertThat(detail.sourcePostId()).isNull();
    }

    @Test
    @DisplayName("받은 뱃지는 근거 게시글을 함께 준다")
    void 상세_획득() {
        when(badges.findById(1L)).thenReturn(Optional.of(earned()));
        when(userBadges.findOne(OWNER, 1L))
                .thenReturn(Optional.of(UserBadgeEntity.of(OWNER, 1L, 9101L, EARNED_AT)));

        BadgeDetailResponse detail = service.detail(1L, OWNER, "ko");

        assertThat(detail.badge().earned()).isTrue();
        assertThat(detail.sourcePostId()).isEqualTo("pst_" + Long.toString(9101L, 36));
    }

    @Test
    @DisplayName("모르는 조건이어도 상세는 열린다 — 목표값만 0 이다")
    void 상세_모르는_조건() {
        when(badges.findById(9L)).thenReturn(Optional.of(BadgeFixtures.badge(
                9L, BadgeType.RECORD, BadgeFixtures.condition("SOMETHING_UNKNOWN", 3))));
        when(userBadges.findOne(any(), anyLong())).thenReturn(Optional.empty());

        BadgeDetailResponse detail = service.detail(9L, OWNER, "ko");

        assertThat(detail.condition()).containsEntry("type", "UNKNOWN");
        assertThat(detail.targetValue()).isZero();
    }

    @Test
    @DisplayName("없는 뱃지는 404")
    void 없는_뱃지() {
        when(badges.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.detail(99L, OWNER, "ko"))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(((ApiException) t).errorCode())
                        .isEqualTo(ErrorCode.BADGE_NOT_FOUND));
    }

    private static BadgeEntity earned() {
        return BadgeFixtures.badge(1L, BadgeType.EVENT,
                BadgeFixtures.condition("EVENT_PARTICIPATE", null), true, 9401L, null);
    }

    private static BadgeEntity unearned() {
        return BadgeFixtures.badge(2L, BadgeType.AREA,
                BadgeFixtures.condition("AREA_POST_COUNT", 5), true, null, 1);
    }
}
