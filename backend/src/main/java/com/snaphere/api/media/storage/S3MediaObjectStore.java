package com.snaphere.api.media.storage;

import jakarta.annotation.PreDestroy;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CopyObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;

import java.util.Optional;

/**
 * S3 객체 읽기·쓰기. {@code snaphere.media.provider=s3} 일 때만 등록된다.
 *
 * <p>자격증명은 SDK 기본 체인(환경변수 · 프로파일 · 인스턴스 역할)을 쓴다. 설정 파일에 키를
 * 적지 않는다.
 */
@Component
@ConditionalOnProperty(prefix = "snaphere.media", name = "provider", havingValue = "s3")
public class S3MediaObjectStore implements MediaObjectStore {

    private final MediaStorageProperties properties;
    private final S3Client client;

    public S3MediaObjectStore(MediaStorageProperties properties) {
        this.properties = properties;
        this.client = S3Client.builder()
                .region(Region.of(properties.region()))
                .build();
    }

    @Override
    public Optional<byte[]> get(String objectKey) {
        try {
            return Optional.of(client.getObjectAsBytes(GetObjectRequest.builder()
                    .bucket(properties.bucket())
                    .key(objectKey)
                    .build()).asByteArray());
        } catch (NoSuchKeyException notUploaded) {
            return Optional.empty();
        }
    }

    @Override
    public void put(String objectKey, byte[] content, String contentType) {
        client.putObject(PutObjectRequest.builder()
                        .bucket(properties.bucket())
                        .key(objectKey)
                        .contentType(contentType)
                        .build(),
                RequestBody.fromBytes(content));
    }

    @Override
    public void copy(String sourceKey, String targetKey) {
        client.copyObject(CopyObjectRequest.builder()
                .sourceBucket(properties.bucket())
                .sourceKey(sourceKey)
                .destinationBucket(properties.bucket())
                .destinationKey(targetKey)
                .build());
    }
    @Override public void delete(String objectKey) { client.deleteObject(DeleteObjectRequest.builder().bucket(properties.bucket()).key(objectKey).build()); }

    @PreDestroy
    void close() {
        client.close();
    }
}
