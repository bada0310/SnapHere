package com.snaphere.api.auth;
import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface UserDeviceRepository extends JpaRepository<UserDevice, UUID> { Optional<UserDevice> findByUserIdAndDeviceIdentifier(UUID userId, String deviceIdentifier); Optional<UserDevice> findFirstByUserIdOrderByUpdatedAtDesc(UUID userId); }
