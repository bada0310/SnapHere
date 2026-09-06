package com.snaphere.api.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class UserFoundationTest {

    @Test
    void 신규_사용자는_USER_기반_기본값을_가지고_온보딩_동의_시각을_저장한다() {
        User user = User.newGoogleUser("google-subject", "user@example.com", "https://image.example/u.jpg");

        assertThat(user.isPushLikeEnabled()).isTrue();
        assertThat(user.isPushFollowEnabled()).isTrue();
        assertThat(user.isPushBadgeEnabled()).isTrue();
        assertThat(user.getBadgeCount()).isZero();
        assertThat(user.getFollowerCount()).isZero();
        assertThat(user.getFollowingCount()).isZero();
        assertThat(user.getPostCount()).isZero();
        assertThat(user.getTermsAgreedAt()).isNull();

        user.completeOnboarding("스내퍼", "2026-08-01", "ko-KR");

        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE);
        assertThat(user.getTermsAgreedAt()).isNotNull();
        assertThat(user.getTermsVersion()).isEqualTo("2026-08-01");
    }
}
