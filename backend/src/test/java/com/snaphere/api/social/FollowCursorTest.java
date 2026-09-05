package com.snaphere.api.social;
import com.snaphere.api.common.error.ApiException; import org.junit.jupiter.api.Test; import java.time.Instant; import java.util.UUID; import static org.assertj.core.api.Assertions.*;
class FollowCursorTest { @Test void 커서를_왕복한다(){FollowCursor c=new FollowCursor(Instant.parse("2026-09-06T00:00:00Z"),UUID.randomUUID());assertThat(FollowCursor.decode(c.encode())).isEqualTo(c);}@Test void 깨진_커서는_400이다(){assertThatThrownBy(()->FollowCursor.decode("bad")).isInstanceOf(ApiException.class);}
 /** 밀리초로 자르면 같은 밀리초에 생긴 팔로우가 다음 페이지에서 통째로 빠진다. */
 @Test void 마이크로초를_잃지_않는다(){Instant at=Instant.parse("2026-09-06T00:00:00.123456Z");FollowCursor c=new FollowCursor(at,UUID.randomUUID());FollowCursor d=FollowCursor.decode(c.encode());assertThat(d.createdAt()).isEqualTo(at);assertThat(d.createdAt().getNano()).isEqualTo(123_456_000);}
 /** 앱이 들고 있던 옛 커서를 400 으로 되돌리면 목록이 처음으로 튄다. */
 @Test void 옛_두토막_커서도_받는다(){UUID id=UUID.randomUUID();String legacy=java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(("1788000000000:"+id).getBytes(java.nio.charset.StandardCharsets.UTF_8));FollowCursor d=FollowCursor.decode(legacy);assertThat(d.createdAt().toEpochMilli()).isEqualTo(1788000000000L);assertThat(d.userId()).isEqualTo(id);} }
