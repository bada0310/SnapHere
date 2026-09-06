package com.snaphere.api.post;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.media.storage.MediaUrlResolver;
import com.snaphere.api.post.dto.CreatePostRequest;
import com.snaphere.api.post.dto.PostImageRequest;
import com.snaphere.api.post.entity.PostImageEntity;
import com.snaphere.api.post.entity.PostTagEntity;
import com.snaphere.api.post.tier.PhotoSource;
import org.springframework.stereotype.Component;

import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * 게시글 생성 필수값 검증. (PST-017)
 *
 * <p>사진 0장·장소 없음·태그 0개를 <b>각각 다른 에러 코드</b>로 거부한다. 앱이 어느 단계로
 * 되돌려야 하는지가 코드마다 다르기 때문이다 — 사진 선택, 장소 단계, 태그 입력.
 *
 * <p>DB 도 리포지토리도 쓰지 않는다. 검증 규칙만 따로 떼어 두면 스키마 없이 시험할 수 있고,
 * 게시글 등록 서비스는 흐름만 남는다.
 */
@Component
public class PostCreateValidator {

    /** 사진 장수. (PST-001) */
    public static final int MIN_IMAGES = 1;
    public static final int MAX_IMAGES = PostImageEntity.MAX_PER_POST;

    /** 태그 개수. (PST-004) */
    public static final int MIN_TAGS = PostTagEntity.MIN_PER_POST;
    public static final int MAX_TAGS = PostTagEntity.MAX_PER_POST;

    private final MediaUrlResolver mediaUrls;

    public PostCreateValidator(MediaUrlResolver mediaUrls) {
        this.mediaUrls = mediaUrls;
    }

    /**
     * 사진 검증. 없거나 4장을 넘거나 순서·키가 겹치면 전부 {@code POST_IMAGE_REQUIRED} 다 —
     * 앱이 사진 선택 단계로 되돌려야 하는 상황이 하나이기 때문이다.
     *
     * <p>발급되지 않은 키는 {@code MEDIA_NOT_FOUND} 로 가른다. 사진을 다시 고르는 문제가 아니라
     * 업로드가 끝나지 않은 문제다.
     */
    public List<PostImageRequest> validateImages(CreatePostRequest request, UUID userId) {
        List<PostImageRequest> images = request.imagesOrEmpty();
        if (images.size() < MIN_IMAGES || images.size() > MAX_IMAGES) {
            throw new ApiException(ErrorCode.POST_IMAGE_REQUIRED,
                    Map.of("min", MIN_IMAGES, "max", MAX_IMAGES, "actual", images.size()));
        }

        Set<Integer> orders = new HashSet<>();
        Set<String> keys = new HashSet<>();
        for (PostImageRequest image : images) {
            if (image.sortOrder() == null || image.sortOrder() < 1 || image.sortOrder() > MAX_IMAGES
                    || !orders.add(image.sortOrder())) {
                throw new ApiException(ErrorCode.POST_IMAGE_REQUIRED,
                        Map.of("field", "sortOrder", "value", String.valueOf(image.sortOrder())));
            }
            if (!keys.add(image.imageKey())) {
                throw new ApiException(ErrorCode.POST_IMAGE_REQUIRED,
                        Map.of("field", "imageKey", "reason", "duplicated"));
            }
            // 남의 발급 키를 넣어 남의 사진을 자기 게시글로 만들 수 없게 한다 (PST-014).
            if (!mediaUrls.isOwnedPostImageKey(image.imageKey(), userId)) {
                throw new ApiException(ErrorCode.MEDIA_NOT_FOUND,
                        Map.of("imageKey", String.valueOf(image.imageKey())));
            }
        }
        return images;
    }

    /** 장소는 필수다. (PST-002) */
    public long requirePlaceId(Long placeId) {
        if (placeId == null) {
            throw new ApiException(ErrorCode.POST_PLACE_REQUIRED);
        }
        return placeId;
    }

    /**
     * 정규화·중복 제거를 마친 태그 개수 검증. (PST-004)
     *
     * <p>세는 대상은 요청에 담긴 문자열이 아니라 실제 태그 수다. {@code #서울}·{@code 서 울} 을
     * 열 번 보내도 태그는 하나다.
     */
    /**
     * 행사 참여 업로드의 자유 태그 상한. (EVT-020)
     *
     * <p>고정 태그는 서버가 붙이므로 사용자 몫은 {@code MAX_TAGS - 고정 개수} 다. 고정 2개면 8개다.
     *
     * <p>상한을 넘겼을 때 조용히 자르지 않고 막는 이유: 사용자가 공들여 붙인 태그가 말없이
     * 사라지면 게시 결과가 입력과 달라진다. 사진 장수·태그 개수처럼 "내가 넣은 것"은 초과를
     * 알려 주고 되돌려 보낸다.
     */
    public void validateFreeTagCount(int requestedCount, int fixedCount) {
        int allowed = Math.max(0, MAX_TAGS - fixedCount);
        if (requestedCount > allowed) {
            throw new ApiException(ErrorCode.POST_TAG_REQUIRED,
                    Map.of("max", allowed, "fixed", fixedCount, "actual", requestedCount));
        }
    }

    public void validateTagCount(int resolvedCount) {
        if (resolvedCount < MIN_TAGS || resolvedCount > MAX_TAGS) {
            throw new ApiException(ErrorCode.POST_TAG_REQUIRED,
                    Map.of("min", MIN_TAGS, "max", MAX_TAGS, "actual", resolvedCount));
        }
    }

    /**
     * 촬영 시각 검증.
     *
     * <p>카메라 경로는 촬영 시각이 있어야 한다 — 없으면 "지금 찍었다"를 확인할 방법이 없어
     * 높음 등급 판정이 성립하지 않는다 (PST-023). 기기 시계가 하루 이상 앞선 값도 거른다.
     */
    public void validateTakenAt(CreatePostRequest request, OffsetDateTime now) {
        if (request.source() == PhotoSource.CAMERA && request.takenAt() == null) {
            throw new ApiException(ErrorCode.POST_INVALID_TAKEN_AT,
                    Map.of("reason", "requiredForCamera"));
        }
        if (request.takenAt() != null && request.takenAt().isAfter(now.plusDays(1))) {
            throw new ApiException(ErrorCode.POST_INVALID_TAKEN_AT,
                    Map.of("takenAt", request.takenAt().toString()));
        }
    }
}
