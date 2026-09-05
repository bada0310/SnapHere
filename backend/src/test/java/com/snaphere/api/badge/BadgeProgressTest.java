package com.snaphere.api.badge;

import com.snaphere.api.post.repository.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** 뱃지 조건 진행값 — BDG-007 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class BadgeProgressTest {

    private static final UUID USER = UUID.fromString("11111111-1111-1111-1111-111111111111");

    @Mock
    private PostRepository posts;

    private BadgeProgress progress;

    @BeforeEach
    void setUp() {
        progress = new BadgeProgress(posts);
    }

    @Test
    @DisplayName("행사 참여는 그 행사의 게시글 수를 센다")
    void 행사_참여() {
        when(posts.countEligibleByUserAndEvent(USER, 9401L)).thenReturn(1L);

        assertThat(progress.currentValue(
                BadgeFixtures.badge(1L, BadgeType.EVENT,
                        BadgeFixtures.condition("EVENT_PARTICIPATE", null), true, 9401L, null),
                USER)).isEqualTo(1);
    }

    @Test
    @DisplayName("지역 뱃지는 그 시도의 게시글 수를 센다")
    void 지역() {
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(3L);

        assertThat(progress.currentValue(
                BadgeFixtures.badge(2L, BadgeType.AREA,
                        BadgeFixtures.condition("AREA_POST_COUNT", 5), true, null, 1),
                USER)).isEqualTo(3);
    }

    @Test
    @DisplayName("완주 뱃지는 게시글을 남긴 시도 수를 센다")
    void 완주() {
        when(posts.countDistinctAreasByUser(USER)).thenReturn(4L);

        assertThat(progress.currentValue(
                BadgeFixtures.badge(3L, BadgeType.COMPLETION,
                        BadgeFixtures.condition("VISITED_AREA_COUNT", 17)),
                USER)).isEqualTo(4);
    }

    @Test
    @DisplayName("기록 뱃지는 전체 게시글 수를 센다")
    void 기록() {
        when(posts.countEligibleByUser(USER)).thenReturn(12L);

        assertThat(progress.currentValue(
                BadgeFixtures.badge(4L, BadgeType.RECORD,
                        BadgeFixtures.condition("TOTAL_POST_COUNT", 10)),
                USER)).isEqualTo(12);
    }

    @Test
    @DisplayName("비회원은 0 — 쿼리를 돌리지도 않는다")
    void 비회원() {
        assertThat(progress.currentValue(
                BadgeFixtures.badge(4L, BadgeType.RECORD,
                        BadgeFixtures.condition("TOTAL_POST_COUNT", 10)),
                null)).isZero();

        verify(posts, never()).countEligibleByUser(any());
    }

    @Test
    @DisplayName("모르는 조건은 0 이고 절대 지급되지 않는다 — 뱃지 하나의 오타가 수집함을 깨뜨리지 않는다")
    void 모르는_조건() {
        var badge = BadgeFixtures.badge(9L, BadgeType.RECORD,
                BadgeFixtures.condition("SOMETHING_UNKNOWN", 3));

        assertThat(progress.currentValue(badge, USER)).isZero();
        assertThat(progress.satisfied(badge, USER)).isFalse();
    }

    @Test
    @DisplayName("대상이 지정되지 않은 행사·지역 뱃지는 지급되지 않는다")
    void 대상_없음() {
        var noEvent = BadgeFixtures.badge(5L, BadgeType.EVENT,
                BadgeFixtures.condition("EVENT_PARTICIPATE", null), true, null, null);
        var noArea = BadgeFixtures.badge(6L, BadgeType.AREA,
                BadgeFixtures.condition("AREA_POST_COUNT", 5), true, null, null);

        assertThat(progress.satisfied(noEvent, USER)).isFalse();
        assertThat(progress.satisfied(noArea, USER)).isFalse();
        verify(posts, never()).countEligibleByUserAndEvent(any(), anyLong());
        verify(posts, never()).countEligibleByUserAndArea(any(), anyInt());
    }

    @Test
    @DisplayName("진행값이 목표에 닿으면 충족")
    void 충족() {
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(5L);

        assertThat(progress.satisfied(
                BadgeFixtures.badge(2L, BadgeType.AREA,
                        BadgeFixtures.condition("AREA_POST_COUNT", 5), true, null, 1),
                USER)).isTrue();
    }

    @Test
    @DisplayName("조건 JSON 이 아예 없어도 터지지 않는다")
    void 조건_없음() {
        var badge = BadgeFixtures.badge(7L, BadgeType.RECORD, Map.of());

        assertThat(progress.currentValue(badge, USER)).isZero();
        assertThat(progress.satisfied(badge, USER)).isFalse();
    }
}
