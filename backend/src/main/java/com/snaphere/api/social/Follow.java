package com.snaphere.api.social;
import jakarta.persistence.*; import java.time.Instant; import java.util.UUID;
@Entity @Table(name="follows") public class Follow { @EmbeddedId private FollowId id; @Column(name="created_at",nullable=false) private Instant createdAt; protected Follow(){} public static Follow of(UUID follower,UUID following){Follow f=new Follow();f.id=new FollowId(follower,following);f.createdAt=Instant.now();return f;} public FollowId getId(){return id;} public Instant getCreatedAt(){return createdAt;} }
