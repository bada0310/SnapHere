package com.snaphere.api.visit;

import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.post.dto.UserSummaryResponse;
import com.snaphere.api.user.AuthorSnapshot;
import com.snaphere.api.user.AuthorSnapshotReader;
import com.snaphere.api.visit.entity.VisitEntity;
import com.snaphere.api.visit.repository.VisitRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * API-VST-004 — 장소 방문자 조회.
 *
 * <p>기능 명세: 6.1 장소 정보 &gt; 방문자 · 랭킹
 * <p>요구사항: VST-005
 */
@Service
public class PlaceVisitorService {

    private final VisitRepository visits;
    private final AuthorSnapshotReader users;
    private final PagingProperties paging;

    public PlaceVisitorService(VisitRepository visits,
                               AuthorSnapshotReader users,
                               PagingProperties paging) {
        this.visits = visits;
        this.users = users;
        this.paging = paging;
    }

    /**
     * 이 장소를 다녀간 사용자. 최근에 다녀간 사람이 먼저다. (VST-005)
     *
     * <p>사용자당 한 번만 나온다. 방문 행을 그대로 페이징하면 여러 날 다녀간 사람이 여러 페이지에
     * 나오는데, 이 화면이 보여 주려는 것은 "몇 명이 다녀갔는가"다.
     *
     * <p>탈퇴한 사용자는 목록에서 빠진다. 방문 행은 계정 삭제와 함께 사라지지만(FK CASCADE)
     * 그 사이 상태에서도 이름 없는 칸을 만들지 않는다.
     */
    @Transactional(readOnly = true)
    public CursorPage<UserSummaryResponse> ofPlace(long placeId, String cursor, Integer size) {
        int pageSize = paging.resolve(size);
        VisitCursor decoded = VisitCursor.decode(cursor);

        List<VisitEntity> rows = visits.findVisitorsOfPlace(
                placeId,
                decoded == null ? null : decoded.visitedOn(),
                decoded == null ? null : decoded.visitId(),
                PageRequest.of(0, pageSize + 1));

        boolean hasNext = rows.size() > pageSize;
        List<VisitEntity> page = hasNext ? rows.subList(0, pageSize) : rows;
        if (page.isEmpty()) {
            return CursorPage.empty();
        }

        Set<UUID> userIds = new LinkedHashSet<>();
        for (VisitEntity visit : page) {
            userIds.add(visit.getUserId());
        }
        Map<UUID, AuthorSnapshot> found = users.findAllByIds(userIds);

        List<UserSummaryResponse> items = new ArrayList<>(page.size());
        for (VisitEntity visit : page) {
            AuthorSnapshot user = found.get(visit.getUserId());
            if (user != null) {
                items.add(UserSummaryResponse.from(user));
            }
        }

        VisitEntity last = page.get(page.size() - 1);
        String nextCursor = hasNext
                ? new VisitCursor(last.getVisitedOn(), last.getVisitId()).encode()
                : null;
        return CursorPage.of(items, nextCursor);
    }
}
