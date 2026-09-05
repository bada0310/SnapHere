package com.snaphere.api.badge.jpa;

import com.snaphere.api.badge.AwardedBadge;
import com.snaphere.api.badge.BadgeFixtures;
import com.snaphere.api.badge.BadgeProgress;
import com.snaphere.api.badge.BadgeType;
import com.snaphere.api.badge.entity.BadgeEntity;
import com.snaphere.api.badge.repository.BadgeRepository;
import com.snaphere.api.badge.repository.UserBadgeRepository;
import com.snaphere.api.post.repository.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 뱃지 지급 판정 — BDG-001 ~ BDG-006, EVT-023
 *
 * <p>이 구현의 판단은 넷이다 — 낮음 등급을 걸러낼 것, 상관없는 뱃지를 평가하지 않을 것,
 * 중복 지급을 DB 에 맡길 것, 같은 집계를 다시 세지 않을 것.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class JpaBadgeAwarderTest {

    private static final UUID USER = UUID.fromString("11111111-1111-1111-1111-111111111111");

    @Mock
    private BadgeRepository badges;
    @Mock
    private UserBadgeRepository userBadges;
    @Mock
    private PostRepository posts;

    private JpaBadgeAwarder awarder;

    @BeforeEach
    void setUp() {
        awarder = new JpaBadgeAwarder(badges, userBadges, new BadgeProgress(posts));
        when(userBadges.insertIfAbsent(any(), anyLong(), any(), any())).thenReturn(1);
        when(badges.findAwardCandidates(any())).thenReturn(List.of());
    }

    @Test
    @DisplayName("낮음 등급이면 아무것도 하지 않는다 — 반경 밖 글로는 뱃지를 못 모은다 (EVT-023)")
    void 낮음_등급() {
        List<AwardedBadge> awarded = awarder.awardForPost(USER, 1L, 9001L, 1, 9401L, false);

        assertThat(awarded).isEmpty();
        verify(badges, never()).findAwardCandidates(any());
        verify(userBadges, never()).insertIfAbsent(any(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("조건을 채우면 지급하고 획득자 수를 올린다")
    void 지급() {
        BadgeEntity badge = areaBadge(2L, 1, 2);
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(badge));
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(2L);

        List<AwardedBadge> awarded = awarder.awardForPost(USER, 100L, 9001L, 1, null, true);

        assertThat(awarded).hasSize(1);
        assertThat(awarded.get(0).badgeId()).isEqualTo(2L);
        assertThat(awarded.get(0).name()).isEqualTo("뱃지 2");
        verify(userBadges).insertIfAbsent(eq(USER), eq(2L), any(), eq(100L));
        verify(badges).addEarnedCount(eq(2L), eq(1), any());
    }

    @Test
    @DisplayName("조건에 못 미치면 지급하지 않는다")
    void 미달() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(areaBadge(2L, 1, 5)));
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(3L);

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, null, true)).isEmpty();
        verify(userBadges, never()).insertIfAbsent(any(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("다른 지역 뱃지는 평가조차 하지 않는다 — 카운트 쿼리를 아낀다")
    void 다른_지역() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(areaBadge(2L, 6, 1)));

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, null, true)).isEmpty();
        verify(posts, never()).countEligibleByUserAndArea(any(), anyInt());
    }

    @Test
    @DisplayName("다른 행사 뱃지도 평가하지 않는다")
    void 다른_행사() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(eventBadge(3L, 9404L)));

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, 9401L, true)).isEmpty();
        verify(posts, never()).countEligibleByUserAndEvent(any(), anyLong());
    }

    @Test
    @DisplayName("행사 글이면 그 행사 뱃지를 준다")
    void 행사_뱃지() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(eventBadge(3L, 9401L)));
        when(posts.countEligibleByUserAndEvent(USER, 9401L)).thenReturn(1L);

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, 9401L, true)).hasSize(1);
    }

    @Test
    @DisplayName("이미 갖고 있으면 지급으로 세지 않는다 — 중복 판정은 DB 가 한다 (BDG-006)")
    void 중복() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(areaBadge(2L, 1, 1)));
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(5L);
        when(userBadges.insertIfAbsent(any(), anyLong(), any(), any())).thenReturn(0);

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, null, true)).isEmpty();
        verify(badges, never()).addEarnedCount(anyLong(), anyInt(), any());
    }

    @Test
    @DisplayName("임계값만 다른 지역 뱃지가 여럿이어도 카운트는 한 번만")
    void 집계_재사용() {
        when(badges.findAwardCandidates(USER))
                .thenReturn(List.of(areaBadge(2L, 1, 2), areaBadge(3L, 1, 5), areaBadge(4L, 1, 10)));
        when(posts.countEligibleByUserAndArea(USER, 1)).thenReturn(6L);

        List<AwardedBadge> awarded = awarder.awardForPost(USER, 100L, 9001L, 1, null, true);

        assertThat(awarded).hasSize(2);   // 2개·5개는 통과, 10개는 미달
        verify(posts, times(1)).countEligibleByUserAndArea(USER, 1);
    }

    @Test
    @DisplayName("조건 JSON 이 깨진 뱃지는 절대 지급되지 않는다")
    void 깨진_조건() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(BadgeFixtures.badge(
                9L, BadgeType.RECORD, BadgeFixtures.condition("SOMETHING_UNKNOWN", 1))));

        assertThat(awarder.awardForPost(USER, 100L, 9001L, 1, null, true)).isEmpty();
        verify(userBadges, never()).insertIfAbsent(any(), anyLong(), any(), any());
    }

    @Test
    @DisplayName("완주·기록 뱃지는 어떤 글이든 평가한다")
    void 완주_기록() {
        when(badges.findAwardCandidates(USER)).thenReturn(List.of(
                BadgeFixtures.badge(5L, BadgeType.COMPLETION,
                        BadgeFixtures.condition("VISITED_AREA_COUNT", 3)),
                BadgeFixtures.badge(6L, BadgeType.RECORD,
                        BadgeFixtures.condition("TOTAL_POST_COUNT", 10))));
        when(posts.countDistinctAreasByUser(USER)).thenReturn(3L);
        when(posts.countEligibleByUser(USER)).thenReturn(4L);

        List<AwardedBadge> awarded = awarder.awardForPost(USER, 100L, 9001L, 1, null, true);

        assertThat(awarded).hasSize(1);   // 완주(3/3)만 통과, 기록(4/10)은 미달
        assertThat(awarded.get(0).badgeId()).isEqualTo(5L);
    }

    private static BadgeEntity areaBadge(long badgeId, int areaCode, int threshold) {
        return BadgeFixtures.badge(badgeId, BadgeType.AREA,
                BadgeFixtures.condition("AREA_POST_COUNT", threshold), true, null, areaCode);
    }

    private static BadgeEntity eventBadge(long badgeId, long eventId) {
        return BadgeFixtures.badge(badgeId, BadgeType.EVENT,
                BadgeFixtures.condition("EVENT_PARTICIPATE", null), true, eventId, null);
    }
}
