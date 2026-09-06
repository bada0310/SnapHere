package com.snaphere.api.auth;
import com.snaphere.api.social.Follow;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*; import org.springframework.data.repository.query.Param; import java.util.*;
public interface UserRepository extends JpaRepository<User, UUID> {
 Optional<User> findByGoogleSubject(String googleSubject);
 Optional<User> findByRestoreKey(String restoreKey);
 @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select u from User u where u.id=:id") Optional<User> findLockedById(@Param("id") UUID id);
 @Modifying @Query("update User u set u.followerCount=u.followerCount+:delta where u.id=:id") int addFollowerCount(@Param("id") UUID id,@Param("delta") int delta);
 @Modifying @Query("update User u set u.followingCount=u.followingCount+:delta where u.id=:id") int addFollowingCount(@Param("id") UUID id,@Param("delta") int delta);
 @Modifying @Query("update User u set u.followerCount=:followers,u.followingCount=:following where u.id=:id") int replaceFollowCounts(@Param("id") UUID id,@Param("followers") int followers,@Param("following") int following);
 @Query("select u from User u where u.id<>:viewer and u.status=com.snaphere.api.auth.UserStatus.ACTIVE and u.id not in (select f.id.followingId from Follow f where f.id.followerId=:viewer) order by u.followerCount desc,u.postCount desc,u.id") List<User> recommendations(@Param("viewer") UUID viewer,org.springframework.data.domain.Pageable page);
 List<User> findByStatusAndPurgeScheduledAtLessThanEqual(UserStatus status, java.time.Instant now);
}
