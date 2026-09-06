package com.snaphere.api.user;

import com.fasterxml.jackson.databind.JsonNode;
import com.snaphere.api.auth.*;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.PagingProperties;
import com.snaphere.api.media.storage.MediaUrlResolver;
import com.snaphere.api.place.PlaceDtos;
import com.snaphere.api.place.RecentPlaceService;
import com.snaphere.api.post.PostCursor;
import com.snaphere.api.post.PostResponseAssembler;
import com.snaphere.api.post.PostStatus;
import com.snaphere.api.post.dto.PostSummaryResponse;
import com.snaphere.api.post.entity.PostEntity;
import com.snaphere.api.post.repository.PostRepository;
import com.snaphere.api.reaction.repository.BookmarkRepository;
import com.snaphere.api.reaction.repository.LikeRepository;
import com.snaphere.api.reaction.BookmarkTargetType;
import com.snaphere.api.reaction.entity.BookmarkEntity;
import com.snaphere.api.social.FollowId;
import com.snaphere.api.social.FollowRepository;
import com.snaphere.api.visit.repository.VisitRepository;
import jakarta.persistence.EntityManager;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.*;

@Service
public class UserService {
    private final UserRepository users; private final UserDeviceRepository devices; private final FollowRepository follows;
    private final PostRepository posts; private final PostResponseAssembler postResponses; private final PagingProperties paging;
    private final MediaUrlResolver mediaUrls; private final RecentPlaceService recentPlaces; private final AccountDeletionLogRepository deletionLogs;
    private final LikeRepository likes; private final BookmarkRepository bookmarks; private final VisitRepository visits; private final EntityManager em;
    private final com.snaphere.api.place.PlaceRepository placeJdbc;
    public UserService(UserRepository users, UserDeviceRepository devices, FollowRepository follows, PostRepository posts,
                       PostResponseAssembler postResponses, PagingProperties paging, MediaUrlResolver mediaUrls,
                       RecentPlaceService recentPlaces, AccountDeletionLogRepository deletionLogs, LikeRepository likes,
                       BookmarkRepository bookmarks, VisitRepository visits, EntityManager em,
                       com.snaphere.api.place.PlaceRepository placeJdbc) {
        this.users=users; this.devices=devices; this.follows=follows; this.posts=posts; this.postResponses=postResponses;
        this.paging=paging; this.mediaUrls=mediaUrls; this.recentPlaces=recentPlaces; this.deletionLogs=deletionLogs;
        this.likes=likes; this.bookmarks=bookmarks; this.visits=visits; this.em=em; this.placeJdbc=placeJdbc;
    }
    @Transactional(readOnly=true) public UserDtos.MyProfile me(UUID id) { return my(requireActive(id)); }
    @Transactional public UserDtos.MyProfile update(UUID id, UserDtos.UpdateProfileRequest body) {
        User u=requireActive(id); JsonNode nickname=body.nickname(), bio=body.bio(), image=body.profileImageKey(), locale=body.locale();
        String n=value(nickname), b=value(bio), imageKey=value(image), l=value(locale);
        if (nickname != null && (n == null || n.isBlank() || n.trim().length()<2 || n.trim().length()>20)) throw new ApiException(ErrorCode.USER_NICKNAME_INVALID);
        if (bio != null && b != null && b.length()>200) throw new ApiException(ErrorCode.COMMON_400, Map.of("field","bio"));
        if (locale != null && !Set.of("ko-KR","en-US","zh-CN","ja-JP").contains(l)) throw new ApiException(ErrorCode.COMMON_400, Map.of("field","locale"));
        if (image != null && imageKey != null && !imageKey.startsWith("profile/"+id+"/")) throw new ApiException(ErrorCode.MEDIA_NOT_FOUND);
        u.updateProfile(n == null ? null : n.trim(), b, imageKey == null ? null : mediaUrls.publicUrl(imageKey), l,
                nickname != null, bio != null, image != null, locale != null);
        return my(u);
    }
    @Transactional public UserDtos.DeviceResult upsertDevice(UUID id, UserDtos.DeviceUpsertRequest body) {
        User user=requireActive(id); UserDevice d=devices.findByUserIdAndDeviceIdentifier(id,body.deviceId())
                .orElseGet(()->devices.save(UserDevice.create(user,body.deviceId(),body.platform(),body.fcmToken(),body.appVersion())));
        d.update(body.platform(), blankToNull(body.fcmToken()), body.appVersion());
        return device(d);
    }
    @Transactional(readOnly=true) public UserDtos.UserProfile profile(UUID id, Optional<UUID> viewer) { return profileOf(requireActive(id),viewer); }
    @Transactional(readOnly=true) public CursorPage<PostSummaryResponse> posts(UUID id,String cursor,Integer size,Optional<UUID> viewer) { requireActive(id); return postPage(posts.findUserPosts(id, at(cursor), postId(cursor), PageRequest.of(0,paging.resolve(size)+1)),cursor,size,viewer); }
    @Transactional(readOnly=true) public CursorPage<PostSummaryResponse> likedPosts(UUID id,String cursor,Integer size) { requireActive(id); return postPage(posts.findLikedPosts(id,at(cursor),postId(cursor),PageRequest.of(0,paging.resolve(size)+1)),cursor,size,Optional.of(id)); }
    @Transactional(readOnly=true) public CursorPage<UserDtos.BookmarkItem> bookmarks(UUID id, BookmarkTargetType type, String cursor, Integer size) {
        requireActive(id); int limit=paging.resolve(size); List<BookmarkEntity> rows=bookmarks.findPage(id,type,at(cursor),postId(cursor),PageRequest.of(0,limit+1)); boolean next=rows.size()>limit; List<BookmarkEntity> page=next?rows.subList(0,limit):rows; if(page.isEmpty()) return CursorPage.empty();
        List<Long> ids=page.stream().map(b->b.getId().getTargetId()).toList(); Map<Long,PostSummaryResponse> postById=new HashMap<>(); Map<Long,PlaceDtos.PlaceSummary> placeById=new HashMap<>();
        if(type==BookmarkTargetType.POST){ Map<Long,PostEntity> raw=new HashMap<>();posts.findAllById(ids).forEach(p->raw.put(p.getPostId(),p)); for(PostSummaryResponse p:postResponses.summaries(ids.stream().map(raw::get).filter(Objects::nonNull).toList(),Optional.of(id))) postById.put(Long.valueOf(p.postId()),p); }
        else { for(PlaceDtos.PlaceSummary p:placeJdbc.summaries(ids,id)) placeById.put(Long.valueOf(p.placeId().replaceFirst("^[^0-9]*","")),p); }
        List<UserDtos.BookmarkItem> items=page.stream().map(b->new UserDtos.BookmarkItem(type.name(),String.valueOf(b.getId().getTargetId()),b.getCreatedAt(),postById.get(b.getId().getTargetId()),placeById.get(b.getId().getTargetId()))).toList(); BookmarkEntity last=page.get(page.size()-1); return CursorPage.of(items,next?new PostCursor(last.getCreatedAt(),last.getId().getTargetId()).encode():null);
    }
    @Transactional(readOnly=true) public UserDtos.DeletionPreview deletionPreview(UUID id) { requireActive(id); return new UserDtos.DeletionPreview(posts.countByUserIdAndStatus(id,PostStatus.ACTIVE), count("select count(*) from post_images i join posts p on p.post_id=i.post_id where p.user_id=?1",id), count("select count(*) from comments where user_id=?1",id), follows.followersCount(id),count("select count(*) from user_badges where user_id=?1",id),visits.countByUserId(id),30); }
    @Transactional public UserDtos.DeletionReceipt deleteAccount(UUID id, UserDtos.DeleteAccountRequest body) {
        User user=requireActive(id); Instant now=Instant.now(), purge=now.plusSeconds(30L*24*60*60); String restoreKey="restore_"+UUID.randomUUID(); deletionLogs.save(AccountDeletionLog.requested(id,body.reason(),body.contentAction(),now));
        for (com.snaphere.api.social.Follow relation : follows.relationsOf(id)) { if (relation.getId().getFollowerId().equals(id)) users.addFollowerCount(relation.getId().getFollowingId(),-1); else users.addFollowingCount(relation.getId().getFollowerId(),-1); } follows.deleteAllRelations(id); likes.deleteByIdUserId(id); bookmarks.deleteByIdUserId(id);
        if(body.contentAction()==ContentAction.DELETE_ALL) posts.softDeleteByUserId(id,OffsetDateTime.ofInstant(now, ZoneOffset.UTC));
        user.withdraw(now,purge,restoreKey); return new UserDtos.DeletionReceipt(UserStatus.WITHDRAWN.name(),now,purge,restoreKey);
    }
    @Transactional public UserDtos.NotificationPreferences preferences(UUID id, UserDtos.NotificationPreferences body) { User u=requireActive(id); u.updateNotificationPreferences(body.postLike(),body.follow(),body.badgeEarned()); return prefs(u); }
    public CursorPage<PlaceDtos.PlaceSummary> recentPlaces(UUID id,String cursor,Integer size) { requireActive(id); return recentPlaces.recent(id,cursor,size==null?20:size); }
    private User requireActive(UUID id) { User u=users.findById(id).orElseThrow(()->new ApiException(ErrorCode.USER_NOT_FOUND)); if(u.getStatus()!=UserStatus.ACTIVE) throw new ApiException(ErrorCode.USER_NOT_FOUND); return u; }
    private UserDtos.MyProfile my(User u){return new UserDtos.MyProfile(profileOf(u,Optional.of(u.getId())),u.getEmail(),u.getLocale(),u.getStatus().name(),u.getRole().name(),prefs(u));}
    private UserDtos.UserProfile profileOf(User u,Optional<UUID> viewer){Boolean following=null,followedBy=null;if(viewer.isPresent()){following=follows.existsById(new FollowId(viewer.get(),u.getId()));followedBy=follows.existsById(new FollowId(u.getId(),viewer.get()));}return new UserDtos.UserProfile(new UserDtos.UserSummary(u.getId(),u.getNickname(),u.getProfileImageUrl(),u.getBio(),following,followedBy),new UserDtos.ProfileStats(u.getPostCount(),u.getFollowerCount(),u.getFollowingCount(),u.getBadgeCount()));}
    private UserDtos.NotificationPreferences prefs(User u){return new UserDtos.NotificationPreferences(u.isPushLikeEnabled(),u.isPushFollowEnabled(),u.isPushBadgeEnabled());}
    private UserDtos.DeviceResult device(UserDevice d){return new UserDtos.DeviceResult(d.getId(),d.getDeviceIdentifier(),d.getPlatform(),d.getFcmToken(),d.getAppVersion());}
    private CursorPage<PostSummaryResponse> postPage(List<PostEntity> rows,String cursor,Integer size,Optional<UUID> viewer){int limit=paging.resolve(size);boolean next=rows.size()>limit;List<PostEntity> page=next?rows.subList(0,limit):rows;if(page.isEmpty())return CursorPage.empty();PostEntity last=page.get(page.size()-1);return CursorPage.of(postResponses.summaries(page,viewer),next?new PostCursor(last.getCreatedAt(),last.getPostId()).encode():null);}
    private PostCursor decoded(String c){return PostCursor.decode(c);} private OffsetDateTime at(String c){PostCursor d=decoded(c);return d==null?null:d.createdAt();} private Long postId(String c){PostCursor d=decoded(c);return d==null?null:d.postId();}
    private long count(String sql,UUID id){return ((Number)em.createNativeQuery(sql).setParameter(1,id).getSingleResult()).longValue();}
    private static String value(JsonNode node){if(node==null||node.isNull())return null;if(!node.isTextual())throw new ApiException(ErrorCode.COMMON_400);return node.textValue();} private static String blankToNull(String x){return x==null||x.isBlank()?null:x;}
}
