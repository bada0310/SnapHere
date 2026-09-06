package com.snaphere.api.user;

/** 탈퇴 시 게시글·댓글 처리 방식 (USER-016). */
public enum ContentAction {
    KEEP_ANONYMIZED,
    DELETE_ALL
}
