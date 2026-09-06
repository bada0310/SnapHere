package com.snaphere.api.media.storage;

import java.util.Optional;

/**
 * 업로드된 객체를 읽고 쓰는 포트.
 *
 * <p>업로드 자체는 클라이언트가 Presigned URL 로 저장소에 직접 올린다 (PST-013). 서버가 객체를
 * 만지는 것은 후처리 때뿐이므로(PST-019) 그때 필요한 연산만 둔다.
 */
public interface MediaObjectStore {

    /** @return 객체가 없으면 비어 있음. 업로드가 끝나지 않은 사진을 조용히 건너뛸 수 있어야 한다 */
    Optional<byte[]> get(String objectKey);

    void put(String objectKey, byte[] content, String contentType);

    /** 원본을 다른 키로 복사한다. 좌표가 남은 원본을 보관하려고 쓴다 (PST-020). */
    void copy(String sourceKey, String targetKey);
    void delete(String objectKey);
}
