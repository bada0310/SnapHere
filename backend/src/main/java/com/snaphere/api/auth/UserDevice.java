package com.snaphere.api.auth;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name="user_devices", uniqueConstraints=@UniqueConstraint(columnNames={"user_id","device_identifier"}))
public class UserDevice {
 @Id private UUID id; @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="user_id",nullable=false) private User user;
 @Column(name="device_identifier",nullable=false) private String deviceIdentifier; @Enumerated(EnumType.STRING) @Column(nullable=false) private Platform platform;
 @Column(name="fcm_token") private String fcmToken; @Column(name="app_version") private String appVersion; @Column(name="updated_at",nullable=false) private Instant updatedAt;
 protected UserDevice(){} public static UserDevice create(User u,String identifier,Platform platform,String fcm){ return create(u,identifier,platform,fcm,null); } public static UserDevice create(User u,String identifier,Platform platform,String fcm, String appVersion){ UserDevice d=new UserDevice();d.id=UUID.randomUUID();d.user=u;d.deviceIdentifier=identifier;d.platform=platform;d.fcmToken=fcm;d.appVersion=appVersion;d.updatedAt=Instant.now();return d; }
 public UUID getId(){return id;} public User getUser(){return user;} public String getDeviceIdentifier(){return deviceIdentifier;} public void update(Platform p,String fcm,String appVersion){platform=p;fcmToken=fcm;this.appVersion=appVersion;updatedAt=Instant.now();} public void clearFcmToken(){fcmToken=null;updatedAt=Instant.now();}
 public Platform getPlatform(){return platform;} public String getFcmToken(){return fcmToken;} public String getAppVersion(){return appVersion;}
}
