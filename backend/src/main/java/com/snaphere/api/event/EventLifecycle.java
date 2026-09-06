package com.snaphere.api.event;

/**
 * 행사 행의 노출 여부. {@code events.status} 컬럼에 대응한다.
 *
 * <p>{@link EventStatus} 와 축이 다르다 — 이쪽은 "운영이 보여 줄 행사인가", 저쪽은 "오늘 기준
 * 진행 중인가" 다. 종료된 행사도 {@code ACTIVE} 로 남아 지난 행사 목록에 나온다.
 */
public enum EventLifecycle {

    ACTIVE,
    HIDDEN
}
