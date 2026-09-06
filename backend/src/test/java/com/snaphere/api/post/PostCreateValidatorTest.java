package com.snaphere.api.post;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.media.storage.MediaStorageProperties;
import com.snaphere.api.media.storage.MediaUrlResolver;
import com.snaphere.api.post.dto.CreatePostRequest;
import com.snaphere.api.post.dto.PostImageRequest;
import com.snaphere.api.post.tier.PhotoSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 게시글 생성 필수값 검증 — PST-001, PST-002, PST-004, PST-014, PST-017, PST-023
 *
 * <p>PST-017 의 핵심은 "각각 다른 에러 코드"다. 그래서 어떤 코드가 나오는지를 검사한다.
 */
class PostCreateValidatorTest {

    private static final UUID USER = UUID.fromString("11111111-2222-3333-4444-555555555555");
    private static final UUID OTHER = UUID.fromString("99999999-8888-7777-6666-555555555555");
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-09-02T12:00:00+09:00");

    private final PostCreateValidator validator = new PostCreateValidator(
            new MediaUrlResolver(new MediaStorageProperties(
                    "stub", "b", "ap-northeast-2", "https://cdn.test", Duration.ofMinutes(5), 1)));

    private static PostImageRequest image(UUID owner, int sortOrder) {
        return new PostImageRequest("posts/" + owner + "/img" + sortOrder + ".webp", sortOrder, null, null);
    }

    private static CreatePostRequest request(List<PostImageRequest> images) {
        return new CreatePostRequest(1L, null, null, "ko", images, List.of("서울"),
                PhotoSource.ALBUM, null, null, null);
    }

    private static ErrorCode codeOf(Throwable t) {
        return ((ApiException) t).errorCode();
    }

    // ───────────────────────────────────────────── 사진 (PST-001)

    @Test
    @DisplayName("사진 0장은 POST_IMAGE_REQUIRED")
    void 사진_없음() {
        assertThatThrownBy(() -> validator.validateImages(request(List.of()), USER))
                .isInstanceOf(ApiException.class)
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("images 를 아예 보내지 않아도 POST_IMAGE_REQUIRED")
    void 사진_필드_없음() {
        CreatePostRequest req = new CreatePostRequest(1L, null, null, "ko", null, List.of("서울"),
                PhotoSource.ALBUM, null, null, null);
        assertThatThrownBy(() -> validator.validateImages(req, USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("5장은 POST_IMAGE_REQUIRED")
    void 사진_초과() {
        List<PostImageRequest> five = new ArrayList<>();
        for (int i = 1; i <= 5; i++) {
            five.add(image(USER, i));
        }
        assertThatThrownBy(() -> validator.validateImages(request(five), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("1~4장은 통과한다")
    void 사진_정상() {
        for (int n = 1; n <= 4; n++) {
            List<PostImageRequest> images = new ArrayList<>();
            for (int i = 1; i <= n; i++) {
                images.add(image(USER, i));
            }
            assertThat(validator.validateImages(request(images), USER)).hasSize(n);
        }
    }

    @Test
    @DisplayName("정렬 순서가 겹치면 POST_IMAGE_REQUIRED")
    void 정렬_순서_중복() {
        List<PostImageRequest> images = List.of(
                new PostImageRequest("posts/" + USER + "/a.webp", 1, null, null),
                new PostImageRequest("posts/" + USER + "/b.webp", 1, null, null));
        assertThatThrownBy(() -> validator.validateImages(request(images), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("정렬 순서는 1~4 밖이면 POST_IMAGE_REQUIRED")
    void 정렬_순서_범위() {
        assertThatThrownBy(() -> validator.validateImages(request(List.of(image(USER, 0))), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
        assertThatThrownBy(() -> validator.validateImages(request(List.of(image(USER, 5))), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("같은 키를 두 번 보내면 POST_IMAGE_REQUIRED")
    void 같은_키_중복() {
        List<PostImageRequest> images = List.of(
                new PostImageRequest("posts/" + USER + "/a.webp", 1, null, null),
                new PostImageRequest("posts/" + USER + "/a.webp", 2, null, null));
        assertThatThrownBy(() -> validator.validateImages(request(images), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_IMAGE_REQUIRED));
    }

    @Test
    @DisplayName("남에게 발급된 키는 MEDIA_NOT_FOUND — 사진을 다시 고를 문제가 아니다")
    void 남의_키() {
        assertThatThrownBy(() -> validator.validateImages(request(List.of(image(OTHER, 1))), USER))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.MEDIA_NOT_FOUND));
    }

    // ───────────────────────────────────────────── 장소 (PST-002)

    @Test
    @DisplayName("장소가 없으면 POST_PLACE_REQUIRED")
    void 장소_없음() {
        assertThatThrownBy(() -> validator.requirePlaceId(null))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_PLACE_REQUIRED));
        assertThat(validator.requirePlaceId(7L)).isEqualTo(7L);
    }

    // ───────────────────────────────────────────── 태그 (PST-004)

    @Test
    @DisplayName("태그 0개와 11개는 POST_TAG_REQUIRED, 1~10개는 통과")
    void 태그_개수() {
        assertThatThrownBy(() -> validator.validateTagCount(0))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_TAG_REQUIRED));
        assertThatThrownBy(() -> validator.validateTagCount(11))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_TAG_REQUIRED));
        validator.validateTagCount(1);
        validator.validateTagCount(10);
    }

    // ───────────────────────────────────────────── 촬영 시각 (PST-023)

    @Test
    @DisplayName("카메라 경로에 촬영 시각이 없으면 POST_INVALID_TAKEN_AT")
    void 카메라_촬영시각_필수() {
        CreatePostRequest req = new CreatePostRequest(1L, null, null, "ko",
                List.of(image(USER, 1)), List.of("서울"), PhotoSource.CAMERA, null, null, null);
        assertThatThrownBy(() -> validator.validateTakenAt(req, NOW))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_INVALID_TAKEN_AT));
    }

    @Test
    @DisplayName("앨범 경로는 촬영 시각이 없어도 된다 — 등급만 낮아진다")
    void 앨범_촬영시각_선택() {
        validator.validateTakenAt(request(List.of(image(USER, 1))), NOW);
    }

    @Test
    @DisplayName("하루 이상 앞선 촬영 시각은 POST_INVALID_TAKEN_AT")
    void 미래_촬영시각() {
        CreatePostRequest req = new CreatePostRequest(1L, null, null, "ko",
                List.of(image(USER, 1)), List.of("서울"), PhotoSource.ALBUM,
                NOW.plusDays(2), null, null);
        assertThatThrownBy(() -> validator.validateTakenAt(req, NOW))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_INVALID_TAKEN_AT));
    }

    @Test
    @DisplayName("시차·시계 오차 범위(하루 이내 미래)는 허용한다")
    void 약간_앞선_시각_허용() {
        CreatePostRequest req = new CreatePostRequest(1L, null, null, "ko",
                List.of(image(USER, 1)), List.of("서울"), PhotoSource.ALBUM,
                NOW.plusHours(6), null, null);
        validator.validateTakenAt(req, NOW);
    }

    // ─────────────────────────────────── 행사 자유 태그 상한 (EVT-020)

    @Test
    @DisplayName("고정 태그 2개면 자유 태그는 8개까지")
    void 자유_태그_상한() {
        validator.validateFreeTagCount(8, 2);

        assertThatThrownBy(() -> validator.validateFreeTagCount(9, 2))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_TAG_REQUIRED));
    }

    @Test
    @DisplayName("행사가 아니면 고정 0개 — 상한 10개 그대로")
    void 고정_없음() {
        validator.validateFreeTagCount(10, 0);

        assertThatThrownBy(() -> validator.validateFreeTagCount(11, 0))
                .satisfies(t -> assertThat(codeOf(t)).isEqualTo(ErrorCode.POST_TAG_REQUIRED));
    }

    @Test
    @DisplayName("고정 태그가 상한을 다 먹으면 자유 태그는 0개")
    void 고정이_전부() {
        validator.validateFreeTagCount(0, 10);

        assertThatThrownBy(() -> validator.validateFreeTagCount(1, 10))
                .isInstanceOf(ApiException.class);
    }

    @Test
    @DisplayName("자유 태그가 하나도 없어도 된다 — 고정 태그가 최소 개수를 채운다")
    void 자유_태그_없음() {
        validator.validateFreeTagCount(0, 2);
    }
}
