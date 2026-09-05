package com.snaphere.api.common.error;

import org.springframework.http.HttpStatus;

/**
 * 앱은 HTTP 상태가 아니라 이 code 로 분기한다. (SYS-002)
 * 명세: 5. 에러 코드 시트. 도메인 코드는 해당 기능 구현 시 함께 추가한다.
 */
public enum ErrorCode {

    // 공통
    COMMON_400(HttpStatus.BAD_REQUEST, "error.common.badRequest"),
    COMMON_404(HttpStatus.NOT_FOUND, "error.common.notFound"),
    COMMON_409(HttpStatus.CONFLICT, "error.common.conflict"),
    COMMON_422(HttpStatus.UNPROCESSABLE_ENTITY, "error.common.unprocessable"),
    COMMON_429(HttpStatus.TOO_MANY_REQUESTS, "error.common.tooManyRequests"),
    COMMON_500(HttpStatus.INTERNAL_SERVER_ERROR, "error.common.internal"),
    COMMON_503(HttpStatus.SERVICE_UNAVAILABLE, "error.common.unavailable"),

    // 인증·권한
    AUTH_REQUIRED(HttpStatus.UNAUTHORIZED, "error.auth.required"),
    AUTH_INVALID_GOOGLE_TOKEN(HttpStatus.UNAUTHORIZED, "error.auth.invalidGoogleToken"),
    AUTH_AUDIENCE_MISMATCH(HttpStatus.UNAUTHORIZED, "error.auth.audienceMismatch"),
    AUTH_INVALID_REFRESH(HttpStatus.UNAUTHORIZED, "error.auth.invalidRefresh"),
    AUTH_REFRESH_EXPIRED(HttpStatus.UNAUTHORIZED, "error.auth.refreshExpired"),
    AUTH_TOKEN_REUSED(HttpStatus.UNAUTHORIZED, "error.auth.tokenReused"),
    AUTH_TERMS_REQUIRED(HttpStatus.FORBIDDEN, "error.auth.termsRequired"),
    USER_NICKNAME_INVALID(HttpStatus.UNPROCESSABLE_ENTITY, "error.user.nicknameInvalid"),
    USER_WITHDRAWN(HttpStatus.CONFLICT, "error.user.withdrawn"),
    USER_NOT_FOUND(HttpStatus.NOT_FOUND, "error.user.notFound"),
    ADMIN_REQUIRED(HttpStatus.FORBIDDEN, "error.auth.adminRequired"),

    // 미디어
    MEDIA_COUNT_INVALID(HttpStatus.UNPROCESSABLE_ENTITY, "error.media.countInvalid"),
    MEDIA_TOO_LARGE(HttpStatus.PAYLOAD_TOO_LARGE, "error.media.tooLarge"),
    MEDIA_TYPE_UNSUPPORTED(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "error.media.typeUnsupported"),
    MEDIA_NOT_FOUND(HttpStatus.UNPROCESSABLE_ENTITY, "error.media.notFound"),

    // 장소·이벤트
    PLACE_NOT_FOUND(HttpStatus.NOT_FOUND, "error.place.notFound"),
    PLACE_INVALID_COORDINATE(HttpStatus.UNPROCESSABLE_ENTITY, "error.place.invalidCoordinate"),
    PLACE_OUT_OF_SERVICE_AREA(HttpStatus.UNPROCESSABLE_ENTITY, "error.place.outOfServiceArea"),
    PLACE_RADIUS_TOO_LARGE(HttpStatus.UNPROCESSABLE_ENTITY, "error.place.radiusTooLarge"),
    PLACE_DAILY_LIMIT(HttpStatus.TOO_MANY_REQUESTS, "error.place.dailyLimit"),
    EVENT_NOT_FOUND(HttpStatus.NOT_FOUND, "error.event.notFound"),

    // 뱃지 (BDG-013)
    BADGE_NOT_FOUND(HttpStatus.NOT_FOUND, "error.badge.notFound"),

    // 지도
    MAP_INVALID_BOUNDS(HttpStatus.UNPROCESSABLE_ENTITY, "error.map.invalidBounds"),

    SOC_SELF_FOLLOW(HttpStatus.BAD_REQUEST, "error.social.selfFollow"),
    SOC_DAILY_LIMIT(HttpStatus.TOO_MANY_REQUESTS, "error.social.dailyLimit"),

    // 댓글 (CMU-012 ~ CMU-018)
    COMMENT_NOT_FOUND(HttpStatus.NOT_FOUND, "error.comment.notFound"),
    COMMENT_NOT_AUTHOR(HttpStatus.FORBIDDEN, "error.comment.notAuthor"),
    COMMENT_LENGTH_INVALID(HttpStatus.UNPROCESSABLE_ENTITY, "error.comment.lengthInvalid"),

    // 태그 (CMU-030, SCH-007)
    TAG_NOT_FOUND(HttpStatus.NOT_FOUND, "error.tag.notFound"),

    // 게시글 (PST-*)
    POST_NOT_FOUND(HttpStatus.NOT_FOUND, "error.post.notFound"),
    POST_NOT_VISIBLE(HttpStatus.NOT_FOUND, "error.post.notVisible"),
    POST_NOT_AUTHOR(HttpStatus.FORBIDDEN, "error.post.notAuthor"),
    POST_INVALID_TAKEN_AT(HttpStatus.UNPROCESSABLE_ENTITY, "error.post.invalidTakenAt"),
    POST_IMAGE_REQUIRED(HttpStatus.UNPROCESSABLE_ENTITY, "error.post.imageRequired"),
    POST_PLACE_REQUIRED(HttpStatus.UNPROCESSABLE_ENTITY, "error.post.placeRequired"),
    POST_TAG_REQUIRED(HttpStatus.UNPROCESSABLE_ENTITY, "error.post.tagRequired"),
    POST_DAILY_LIMIT(HttpStatus.TOO_MANY_REQUESTS, "error.post.dailyLimit"),
    POST_PLACE_DAILY_LIMIT(HttpStatus.TOO_MANY_REQUESTS, "error.post.placeDailyLimit"),
    POST_DUPLICATE_IMAGE(HttpStatus.CONFLICT, "error.post.duplicateImage"),
    POST_UPLOAD_SUSPENDED(HttpStatus.FORBIDDEN, "error.post.uploadSuspended"),

    // 신고·운영
    REPORT_DUPLICATE(HttpStatus.CONFLICT, "error.report.duplicate"),
    REPORT_NOT_FOUND(HttpStatus.NOT_FOUND, "error.report.notFound"),
    BATCH_ALREADY_RUNNING(HttpStatus.CONFLICT, "error.batch.alreadyRunning");

    private final HttpStatus status;
    private final String messageKey;

    ErrorCode(HttpStatus status, String messageKey) {
        this.status = status;
        this.messageKey = messageKey;
    }

    public HttpStatus status() {
        return status;
    }

    /** 서버는 완성 문장을 만들지 않는다. 앱이 이 키로 다국어를 조립한다. (NTF-009, SYS-010) */
    public String messageKey() {
        return messageKey;
    }
}
