package com.snaphere.api.user;

import com.snaphere.api.common.security.CurrentUser;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.ApiResponse;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.common.web.TraceIdFilter;
import com.snaphere.api.post.dto.PostSummaryResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class UserController {
    private final UserService users;
    private final CurrentUserProvider current;
    public UserController(UserService users, CurrentUserProvider current) { this.users = users; this.current = current; }

    @GetMapping("/me") public ResponseEntity<ApiResponse<UserDtos.MyProfile>> me(HttpServletRequest r) { return ok(users.me(current.require(r).userId()), r); }
    @PatchMapping("/me") public ResponseEntity<ApiResponse<UserDtos.MyProfile>> updateMe(@RequestBody UserDtos.UpdateProfileRequest body, HttpServletRequest r) { return ok(users.update(current.require(r).userId(), body), r); }
    @PutMapping("/me/device") public ResponseEntity<ApiResponse<UserDtos.DeviceResult>> device(@Valid @RequestBody UserDtos.DeviceUpsertRequest body, HttpServletRequest r) { return ok(users.upsertDevice(current.require(r).userId(), body), r); }
    @GetMapping("/users/{userId}") public ResponseEntity<ApiResponse<UserDtos.UserProfile>> profile(@PathVariable UUID userId, HttpServletRequest r) { return ok(users.profile(userId, current.optional(r).map(CurrentUser::userId)), r); }
    @GetMapping("/users/{userId}/posts") public ResponseEntity<ApiResponse<CursorPage<PostSummaryResponse>>> posts(@PathVariable UUID userId, @RequestParam(required=false) String cursor, @RequestParam(required=false) Integer size, HttpServletRequest r) { return ok(users.posts(userId, cursor, size, current.optional(r).map(CurrentUser::userId)), r); }
    @GetMapping("/me/liked-posts") public ResponseEntity<ApiResponse<CursorPage<PostSummaryResponse>>> liked(@RequestParam(required=false) String cursor, @RequestParam(required=false) Integer size, HttpServletRequest r) { return ok(users.likedPosts(current.require(r).userId(), cursor, size), r); }
    @GetMapping("/me/bookmarks") public ResponseEntity<ApiResponse<CursorPage<UserDtos.BookmarkItem>>> bookmarks(@RequestParam com.snaphere.api.reaction.BookmarkTargetType type, @RequestParam(required=false) String cursor, @RequestParam(required=false) Integer size, HttpServletRequest r) { return ok(users.bookmarks(current.require(r).userId(), type, cursor, size), r); }
    @GetMapping("/me/deletion-preview") public ResponseEntity<ApiResponse<UserDtos.DeletionPreview>> preview(HttpServletRequest r) { return ok(users.deletionPreview(current.require(r).userId()), r); }
    @PostMapping("/me/deletion") public ResponseEntity<ApiResponse<UserDtos.DeletionReceipt>> delete(@Valid @RequestBody UserDtos.DeleteAccountRequest body, HttpServletRequest r) { return ResponseEntity.status(HttpStatus.ACCEPTED).body(ApiResponse.ok(users.deleteAccount(current.require(r).userId(), body), TraceIdFilter.currentTraceId(r))); }
    @PatchMapping("/me/notification-preferences") public ResponseEntity<ApiResponse<UserDtos.NotificationPreferences>> preferences(@RequestBody UserDtos.NotificationPreferences body, HttpServletRequest r) { return ok(users.preferences(current.require(r).userId(), body), r); }
    private <T> ResponseEntity<ApiResponse<T>> ok(T body, HttpServletRequest r) { return ResponseEntity.ok(ApiResponse.ok(body, TraceIdFilter.currentTraceId(r))); }
}
