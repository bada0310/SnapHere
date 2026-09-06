package com.snaphere.api.common.error;

import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.TraceIdFilter;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.List;

/**
 * 모든 예외를 공통 실패 봉투로 변환한다. (SYS-001, SYS-002)
 * 명세: 4. 공통 규약 > 응답 > 실패 봉투
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiResponse<Void>> handleApi(ApiException e, HttpServletRequest request) {
        ErrorBody body = ErrorBody.of(e.errorCode(), e.messageParams());
        if (e.retryAfterSec() != null) {
            body = body.withRetryAfter(e.retryAfterSec());
        }
        return ResponseEntity.status(e.errorCode().status())
                .body(ApiResponse.fail(body, TraceIdFilter.currentTraceId(request)));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException e,
                                                              HttpServletRequest request) {
        List<ErrorBody.Violation> violations = e.getBindingResult().getFieldErrors().stream()
                .map(GlobalExceptionHandler::toViolation)
                .toList();
        ErrorBody body = ErrorBody.withViolations(ErrorCode.COMMON_400, violations);
        return ResponseEntity.status(ErrorCode.COMMON_400.status())
                .body(ApiResponse.fail(body, TraceIdFilter.currentTraceId(request)));
    }

    /** JSON 본문이 없거나 문법이 깨진 요청은 서버 오류가 아니라 잘못된 요청이다. */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleUnreadableBody(HttpMessageNotReadableException e,
                                                                   HttpServletRequest request) {
        return ResponseEntity.status(ErrorCode.COMMON_400.status())
                .body(ApiResponse.fail(ErrorBody.of(ErrorCode.COMMON_400), TraceIdFilter.currentTraceId(request)));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e, HttpServletRequest request) {
        String traceId = TraceIdFilter.currentTraceId(request);
        log.error("처리되지 않은 예외 traceId={}", traceId, e);
        return ResponseEntity.status(ErrorCode.COMMON_500.status())
                .body(ApiResponse.fail(ErrorBody.of(ErrorCode.COMMON_500), traceId));
    }

    private static ErrorBody.Violation toViolation(FieldError error) {
        return new ErrorBody.Violation(error.getField(), error.getDefaultMessage());
    }
}
