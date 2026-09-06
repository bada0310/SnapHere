package com.snaphere.api.media.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 로컬 개발용 저장소. {@code snaphere.media.provider=stub} 일 때 등록된다.
 *
 * <p>{@link StubPresignedUrlIssuer} 는 실제로 업로드하지 않으므로 여기에는 아무 객체도 없다.
 * 그래서 후처리가 돌면 "원본을 찾을 수 없음"으로 건너뛰고, 그 경로가 정상 동작하는지도
 * 이 구현으로 확인된다. 테스트에서 직접 {@link #put} 해서 넣어 볼 수도 있다.
 *
 * <p>프로세스 메모리에만 있으므로 재시작하면 사라진다. 운영에서 쓰면 안 된다.
 */
@Component
@ConditionalOnProperty(prefix = "snaphere.media", name = "provider", havingValue = "stub", matchIfMissing = true)
public class InMemoryMediaObjectStore implements MediaObjectStore {

    private static final Logger log = LoggerFactory.getLogger(InMemoryMediaObjectStore.class);

    private final Map<String, byte[]> objects = new ConcurrentHashMap<>();

    @Override
    public Optional<byte[]> get(String objectKey) {
        return Optional.ofNullable(objects.get(objectKey));
    }

    @Override
    public void put(String objectKey, byte[] content, String contentType) {
        objects.put(objectKey, content);
        log.debug("스텁 저장소에 담았다. key={} bytes={} contentType={}",
                objectKey, content.length, contentType);
    }

    @Override
    public void copy(String sourceKey, String targetKey) {
        byte[] content = objects.get(sourceKey);
        if (content != null) {
            objects.put(targetKey, content);
        }
    }
    @Override public void delete(String objectKey) { objects.remove(objectKey); }
}
