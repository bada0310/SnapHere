package com.snaphere.api.post.tier;

/**
 * 등급이 그렇게 판정된 이유. 앱이 이 코드로 안내 문구를 조립한다. (PST-047, PST-049)
 *
 * <p>등급 이름만 보여주면 뜻이 통하지 않는다는 판단으로 요구사항에 추가된 항목이다.
 * "인증 실패" 같은 의심하는 어조를 쓰지 않도록 코드 이름도 중립적으로 둔다.
 */
public enum TierReason {

    /** 촬영 좌표가 없다 → 낮음 (PST-025) */
    NO_TAKEN_COORDINATE,

    /** 촬영 좌표가 인증 반경 밖이다 → 낮음 (PST-025) */
    OUT_OF_RADIUS,

    /** 촬영 후 30일이 지났다 → 낮음 (PST-025) */
    TAKEN_TOO_LONG_AGO,

    /** 촬영 시각을 알 수 없다 → 낮음 */
    NO_TAKEN_AT,

    /** 카메라로 찍고 10분 이내, 반경 안 → 높음 (PST-023) */
    ON_SITE_CAMERA,

    /** 30일 이내 촬영, 반경 안 → 보통 (PST-024) */
    RECENT_WITHIN_RADIUS,

    /** 장소에 좌표가 없어 판정할 수 없다 → 낮음 (PLC-007) */
    PLACE_HAS_NO_COORDINATE,

    /** 기기가 원 좌표를 보내지 않고 수행한 자체 판정 결과다. */
    LOCAL_VERIFICATION;

    public String messageKey() {
        return "tier.reason." + name().toLowerCase();
    }
}
