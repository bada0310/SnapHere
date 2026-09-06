package com.snaphere.api.social;
import org.springframework.data.domain.Pageable; import org.springframework.data.jpa.repository.*; import org.springframework.data.repository.query.Param; import java.time.Instant; import java.util.*;
public interface FollowRepository extends JpaRepository<Follow,FollowId> {
 @Modifying @Query(value="insert into follows(follower_id,following_id,created_at) values(:follower,:following,now()) on conflict do nothing",nativeQuery=true) int insertIfAbsent(@Param("follower") UUID follower,@Param("following") UUID following);
 @Modifying @Query("delete from Follow f where f.id.followerId=:follower and f.id.followingId=:following") int deleteRelation(@Param("follower") UUID follower,@Param("following") UUID following);
 boolean existsById(FollowId id); long countByIdFollowerIdAndCreatedAtGreaterThanEqual(UUID id,Instant from);
 @Query("select f from Follow f where f.id.followingId=:id and (cast(:at as timestamp) is null or f.createdAt<:at or (f.createdAt=:at and f.id.followerId<:cursor)) order by f.createdAt desc,f.id.followerId desc") List<Follow> followers(@Param("id") UUID id,@Param("at") Instant at,@Param("cursor") UUID cursor,Pageable page);
 @Query("select f from Follow f where f.id.followerId=:id and (cast(:at as timestamp) is null or f.createdAt<:at or (f.createdAt=:at and f.id.followingId<:cursor)) order by f.createdAt desc,f.id.followingId desc") List<Follow> following(@Param("id") UUID id,@Param("at") Instant at,@Param("cursor") UUID cursor,Pageable page);
 @Query("select f.id.followingId from Follow f where f.id.followerId=:viewer and f.id.followingId in :ids") Set<UUID> followed(@Param("viewer") UUID viewer,@Param("ids") Collection<UUID> ids);
 @Query("select f.id.followerId from Follow f where f.id.followingId=:viewer and f.id.followerId in :ids") Set<UUID> followedBy(@Param("viewer") UUID viewer,@Param("ids") Collection<UUID> ids);
 @Query("select count(f) from Follow f where f.id.followingId=:id") long followersCount(@Param("id") UUID id); @Query("select count(f) from Follow f where f.id.followerId=:id") long followingCount(@Param("id") UUID id);
 @Modifying @Query("delete from Follow f where f.id.followerId=:userId or f.id.followingId=:userId") int deleteAllRelations(@Param("userId") UUID userId);
 @Query("select f from Follow f where f.id.followerId=:userId or f.id.followingId=:userId") List<Follow> relationsOf(@Param("userId") UUID userId);
}
