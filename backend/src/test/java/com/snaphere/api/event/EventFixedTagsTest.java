package com.snaphere.api.event;

import com.snaphere.api.post.dto.TagSummaryResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** 행사 고정 태그 변환 — EVT-017, EVT-018 */
class EventFixedTagsTest {

    @Test
    @DisplayName("고정 태그는 locked 로 나간다 — 앱이 삭제 버튼을 감춘다")
    void 잠김() {
        List<TagSummaryResponse> tags = EventFixedTags.of(List.of("서울", "경복궁야간개장"));

        assertThat(tags).hasSize(2);
        assertThat(tags).allMatch(TagSummaryResponse::locked);
        assertThat(tags).extracting(TagSummaryResponse::name)
                .containsExactly("서울", "경복궁야간개장");
    }

    @Test
    @DisplayName("tagId 는 null — fixed_tags 는 표시용 이름만 담는다")
    void 태그_id_없음() {
        assertThat(EventFixedTags.of(List.of("서울")).get(0).tagId()).isNull();
    }

    @Test
    @DisplayName("추천 태그로 표시하지 않는다 — 사용자가 고른 것이 아니다")
    void 추천_아님() {
        assertThat(EventFixedTags.of(List.of("서울")).get(0).suggested()).isFalse();
    }

    @Test
    @DisplayName("빈 목록과 null 은 빈 결과")
    void 비어_있음() {
        assertThat(EventFixedTags.of(null)).isEmpty();
        assertThat(EventFixedTags.of(List.of())).isEmpty();
    }

    @Test
    @DisplayName("빈 문자열과 null 항목은 버린다 — jsonb 는 무엇이든 담을 수 있다")
    void 쓰레기_항목() {
        List<TagSummaryResponse> tags = EventFixedTags.of(Arrays.asList("서울", "", "  ", null));

        assertThat(tags).hasSize(1);
        assertThat(tags.get(0).name()).isEqualTo("서울");
    }

    @Test
    @DisplayName("앞뒤 공백은 다듬는다")
    void 공백_정리() {
        assertThat(EventFixedTags.of(List.of("  서울  ")).get(0).name()).isEqualTo("서울");
    }
}
