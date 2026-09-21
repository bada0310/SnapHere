package com.snaphere.api.post.dto;

import com.snaphere.api.post.tier.PhotoSource;
import com.snaphere.api.post.tier.TrustTier;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;
import java.util.List;

/**
 * 게시글 생성 요청. 명세: 2. 요청 파라미터 &gt; API-PST-003
 *
 * <p><b>개수 제약은 Bean Validation 으로 걸지 않는다.</b> 사진 0장·장소 없음·태그 0개는 각각
 * 다른 에러 코드로 거부해야 하는데(PST-017), {@code @Size} 는 전부 {@code COMMON_400} 의
 * violations 로 뭉쳐 버린다. 그래서 개수는 서비스에서 검사하고 여기서는 형식만 본다.
 *
 * <p>{@code localTier} 는 앱이 기기 안에서 사진 위치와 촬영 시각을 비교한 결과다. 원 좌표와
 * 정확한 촬영 시각은 이 요청에 포함하지 않는다. 지역 코드는 장소에서 역산한다(PST-018).
 */
public record CreatePostRequest(

        Long placeId,

        Long eventId,

        @Size(max = 5000)
        String content,

        @NotBlank
        @Size(max = 10)
        String originalLanguageCode,

        @Valid
        List<PostImageRequest> images,

        List<String> tagNames,

        @NotNull
        PhotoSource source,

        OffsetDateTime takenAt,

        @DecimalMin("-90") @DecimalMax("90")
        Double lat,

        @DecimalMin("-180") @DecimalMax("180")
        Double lng,

        TrustTier localTier,

        Boolean localWithinRadius
) {
    /** 이전 앱·테스트의 요청 생성 호환용 생성자. 새 앱은 localTier를 보낸다. */
    public CreatePostRequest(Long placeId, Long eventId, String content,
                             String originalLanguageCode, List<PostImageRequest> images,
                             List<String> tagNames, PhotoSource source,
                             OffsetDateTime takenAt, Double lat, Double lng) {
        this(placeId, eventId, content, originalLanguageCode, images, tagNames, source,
                takenAt, lat, lng, null, null);
    }
    /** 촬영 좌표는 둘 다 있거나 둘 다 없어야 한다. 하나만 오면 없는 것으로 본다. */
    public boolean hasCoordinate() {
        return lat != null && lng != null;
    }

    public List<PostImageRequest> imagesOrEmpty() {
        return images == null ? List.of() : images;
    }

    public List<String> tagNamesOrEmpty() {
        return tagNames == null ? List.of() : tagNames;
    }
}
