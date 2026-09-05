package com.snaphere.api.social;
import com.snaphere.api.common.error.*; import java.nio.charset.StandardCharsets; import java.time.*; import java.util.*;
/**
 * 팔로우 목록 커서. (SOC-005, SOC-006)
 *
 * <p><b>시각을 밀리초로 줄이지 않는다.</b> PostgreSQL {@code timestamptz} 는 마이크로초까지
 * 보관한다. 밀리초로 자르면 커서 시각이 실제 값보다 앞서고, 조회 조건의
 * {@code createdAt = :at} 가 영영 맞지 않아 같은 밀리초에 생긴 팔로우가 다음 페이지에서
 * 통째로 빠진다. 초와 나노초를 따로 담는다.
 *
 * <p>두 토막짜리 옛 커서도 계속 받는다 — 앱이 들고 있던 커서를 400 으로 되돌리면
 * 목록이 처음으로 튄다.
 */
record FollowCursor(Instant createdAt,UUID userId){ String encode(){return Base64.getUrlEncoder().withoutPadding().encodeToString((createdAt.getEpochSecond()+":"+createdAt.getNano()+":"+userId).getBytes(StandardCharsets.UTF_8));} static FollowCursor decode(String value){if(value==null||value.isBlank())return null;try{String s=new String(Base64.getUrlDecoder().decode(value),StandardCharsets.UTF_8);String[] p=s.split(":");if(p.length==2)return new FollowCursor(Instant.ofEpochMilli(Long.parseLong(p[0])),UUID.fromString(p[1]));if(p.length!=3)throw new IllegalArgumentException(s);return new FollowCursor(Instant.ofEpochSecond(Long.parseLong(p[0]),Long.parseLong(p[1])),UUID.fromString(p[2]));}catch(Exception e){throw new ApiException(ErrorCode.COMMON_400,Map.of("field","cursor"));}} }
