package com.snaphere.api.event;

import com.snaphere.api.post.dto.TagSummaryResponse;

import java.util.ArrayList;
import java.util.List;

/**
 * {@code events.fixed_tags} 의 이름 목록을 응답 태그로 바꾼다. (EVT-017, EVT-018)
 *
 * <p>{@code locked = true} 로 내보낸다. 앱은 이 태그의 삭제 버튼을 감추고, 서버도 게시글
 * 등록에서 이 태그를 다시 주입한다 — 클라이언트가 빼고 보내도 되살아난다 (EVT-019).
 *
 * <p>{@code tagId} 는 null 이다. {@code events.fixed_tags} 는 표시용 이름만 담고 {@code tags}
 * 행과 연결하지 않는다. 태그가 병합되거나 지워질 때 이 열이 낡지 않게 하려는 것이고, 실제
 * 연결은 게시글을 만드는 시점에 태그 도메인이 한다.
 */
public final class EventFixedTags {

    private EventFixedTags() {
    }

    public static List<TagSummaryResponse> of(List<String> names) {
        if (names == null || names.isEmpty()) {
            return List.of();
        }
        List<TagSummaryResponse> tags = new ArrayList<>(names.size());
        for (String name : names) {
            if (name == null || name.isBlank()) {
                continue;
            }
            tags.add(new TagSummaryResponse(null, name.trim(), null, 0L, true, false));
        }
        return List.copyOf(tags);
    }
}
