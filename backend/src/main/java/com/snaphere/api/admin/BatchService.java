package com.snaphere.api.admin;

import com.snaphere.api.auth.ExternalIds;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.common.web.CursorCodec;
import com.snaphere.api.common.web.CursorPage;
import com.snaphere.api.config.PlaceTaskConfig;
import com.snaphere.api.map.MapAggregationService;
import com.snaphere.api.map.MapPeriod;
import com.snaphere.api.ranking.RankingAggregationService;
import com.snaphere.api.ranking.RankingPeriod;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.core.task.TaskExecutor;

import java.sql.Types;
import java.time.OffsetDateTime;
import java.util.List;

@Service
public class BatchService {
    private static final Logger log = LoggerFactory.getLogger(BatchService.class);
    private static final List<Integer> AREAS = List.of(1,2,3,4,5,6,7,8,31,32,33,34,35,36,37,38,39);
    private static final List<Integer> TYPES = List.of(12,14,15,28,38,39);
    private final JdbcClient jdbc;
    private final PlaceSyncWorker worker;
    private final TaskExecutor taskExecutor;
    private final MapAggregationService mapAggregation;
    private final RankingAggregationService rankingAggregation;

    public BatchService(JdbcClient jdbc, PlaceSyncWorker worker,
                        @Qualifier(PlaceTaskConfig.PLACE_TASK_EXECUTOR) TaskExecutor taskExecutor,
                        MapAggregationService mapAggregation,
                        RankingAggregationService rankingAggregation) {
        this.jdbc = jdbc; this.worker = worker; this.taskExecutor = taskExecutor;
        this.mapAggregation = mapAggregation;
        this.rankingAggregation = rankingAggregation;
    }

    public BatchDtos.BatchRun start(String jobType, BatchDtos.StartRequest request) {
        if (!List.of("PLACE_SYNC", "HEATMAP_RECALC", "RANKING_RECALC").contains(jobType)) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
        Integer area = request == null ? null : request.areaCode();
        Integer type = request == null ? null : request.contentTypeId();
        if (!"PLACE_SYNC".equals(jobType) && (area != null || type != null)) {
            throw new ApiException(ErrorCode.COMMON_400);
        }
        if (area != null && !AREAS.contains(area)) throw new ApiException(ErrorCode.COMMON_400);
        if (type != null && !TYPES.contains(type)) throw new ApiException(ErrorCode.COMMON_400);
        try {
            long runId = jdbc.sql("INSERT INTO batch_runs(job_type,status) VALUES (:job,'QUEUED') RETURNING run_id")
                    .param("job", jobType).query(Long.class).single();
            taskExecutor.execute(() -> {
                if ("HEATMAP_RECALC".equals(jobType)) executeHeatmap(runId);
                else if ("RANKING_RECALC".equals(jobType)) executeRanking(runId);
                else execute(runId, area, type);
            });
            return get(runId);
        } catch (DuplicateKeyException e) {
            throw new ApiException(ErrorCode.BATCH_ALREADY_RUNNING);
        }
    }

    public void executeHeatmap(long runId) {
        jdbc.sql("UPDATE batch_runs SET status='RUNNING',started_at=now() WHERE run_id=:id").param("id", runId).update();
        int processed = 0;
        try {
            for (MapPeriod period : MapPeriod.values()) processed += mapAggregation.rebuild(period);
            jdbc.sql("UPDATE batch_runs SET status='SUCCESS',processed_count=:count,finished_at=now() WHERE run_id=:id")
                    .param("count", processed).param("id", runId).update();
        } catch (RuntimeException failure) {
            jdbc.sql("UPDATE batch_runs SET status='FAIL',processed_count=:count,failed_count=1,finished_at=now() WHERE run_id=:id")
                    .param("count", processed).param("id", runId).update();
            log.error("지도 수동 집계 실패. runId={}", runId, failure);
        }
    }

    public void executeRanking(long runId) {
        OffsetDateTime started = OffsetDateTime.now();
        jdbc.sql("UPDATE batch_runs SET status='RUNNING',started_at=now() WHERE run_id=:id")
                .param("id", runId).update();
        int processed = 0;
        try {
            for (RankingPeriod period : RankingPeriod.values()) {
                processed += rankingAggregation.rebuild(period);
            }
            jdbc.sql("""
                    UPDATE batch_runs SET status='SUCCESS',processed_count=:count,finished_at=now()
                    WHERE run_id=:id
                    """).param("count", processed).param("id", runId).update();
            log(runId, null, null, "RANKING_RECALC", "SUCCESS", processed, null, started);
        } catch (RuntimeException failure) {
            jdbc.sql("""
                    UPDATE batch_runs SET status='FAIL',processed_count=:count,failed_count=1,finished_at=now()
                    WHERE run_id=:id
                    """).param("count", processed).param("id", runId).update();
            log(runId, null, null, "RANKING_RECALC", "FAIL", processed,
                    rootMessage(failure), started);
            log.error("장소 랭킹 수동 집계 실패. runId={}", runId, failure);
        }
    }

    public void execute(long runId, Integer areaFilter, Integer typeFilter) {
        jdbc.sql("UPDATE batch_runs SET status='RUNNING',started_at=now() WHERE run_id=:id").param("id", runId).update();
        int processed = 0, failed = 0;
        for (int area : areaFilter == null ? AREAS : List.of(areaFilter)) {
            for (int type : typeFilter == null ? TYPES : List.of(typeFilter)) {
                OffsetDateTime started = OffsetDateTime.now();
                try {
                    int count = worker.syncCombination(area, type);
                    processed += count;
                    log(runId, area, type, "SUCCESS", count, null, started);
                } catch (RuntimeException e) {
                    failed++;
                    log(runId, area, type, "FAIL", 0, rootMessage(e), started);
                    log.warn("장소 동기화 조합 실패 area={} type={}", area, type, e);
                }
            }
        }
        String status = failed == 0 ? "SUCCESS" : "FAIL";
        jdbc.sql("""
                UPDATE batch_runs SET status=:status,processed_count=:processed,failed_count=:failed,finished_at=now()
                WHERE run_id=:id
                """).param("status", status).param("processed", processed).param("failed", failed).param("id", runId).update();
    }

    @Scheduled(cron = "${snaphere.jobs.place-sync-cron:0 0 4 * * *}", zone = "Asia/Seoul")
    public void scheduled() {
        try { start("PLACE_SYNC", new BatchDtos.StartRequest(null, null)); }
        catch (ApiException e) { if (e.errorCode() != ErrorCode.BATCH_ALREADY_RUNNING) throw e; }
    }

    public BatchDtos.BatchRun get(long runId) {
        return jdbc.sql("SELECT run_id,job_type,status,processed_count,failed_count,started_at FROM batch_runs WHERE run_id=:id")
                .param("id", runId).query((rs,n) -> new BatchDtos.BatchRun(ExternalIds.run(rs.getLong(1)),
                        rs.getString(2), rs.getString(3), rs.getInt(4), rs.getInt(5),
                        rs.getObject(6, OffsetDateTime.class))).optional()
                .orElseThrow(() -> new ApiException(ErrorCode.COMMON_404));
    }

    public CursorPage<BatchDtos.SyncLog> logs(String result, String cursor, int size) {
        if (size < 1 || size > 50) throw new ApiException(ErrorCode.COMMON_400);
        Long after = CursorCodec.decode(cursor);
        StringBuilder sql = new StringBuilder("""
                SELECT sync_id,job_type,area_code,content_type_id,result,count,message,started_at,finished_at
                FROM sync_logs WHERE 1=1
                """);
        if (result != null) sql.append(" AND result=:result");
        if (after != null) sql.append(" AND sync_id<:after");
        sql.append(" ORDER BY sync_id DESC LIMIT :limit");
        JdbcClient.StatementSpec spec = jdbc.sql(sql.toString()).param("limit", size + 1);
        if (result != null) spec = spec.param("result", result);
        if (after != null) spec = spec.param("after", after);
        List<BatchDtos.SyncLog> rows = spec.query((rs,n) -> new BatchDtos.SyncLog(ExternalIds.sync(rs.getLong(1)),
                rs.getString(2), (Integer)rs.getObject(3), (Integer)rs.getObject(4), rs.getString(5),
                rs.getInt(6), rs.getString(7), rs.getObject(8,OffsetDateTime.class),
                rs.getObject(9,OffsetDateTime.class))).list();
        boolean hasNext = rows.size() > size;
        List<BatchDtos.SyncLog> items = hasNext ? rows.subList(0,size) : rows;
        String next = hasNext ? CursorCodec.encode(ExternalIds.parse(items.get(items.size()-1).syncId(),"sync",ErrorCode.COMMON_400)) : null;
        return new CursorPage<>(List.copyOf(items),next,hasNext);
    }

    private void log(long runId, int area, int type, String result, int count, String message, OffsetDateTime started) {
        log(runId, area, type, "PLACE_SYNC", result, count, message, started);
    }

    private void log(long runId, Integer area, Integer type, String jobType, String result,
                     int count, String message, OffsetDateTime started) {
        jdbc.sql("""
                INSERT INTO sync_logs(run_id,job_type,area_code,content_type_id,result,count,message,started_at,finished_at)
                VALUES (:run,:job,:area,:type,:result,:count,:message,:started,now())
                """).param("run",runId).param("job",jobType)
                .param("area",area,Types.INTEGER).param("type",type,Types.INTEGER).param("result",result)
                .param("count",count).param("message",message).param("started",started).update();
    }

    private static String rootMessage(Throwable error) {
        Throwable current=error; while(current.getCause()!=null) current=current.getCause();
        String value=current.getMessage(); return value==null?current.getClass().getSimpleName():value.substring(0,Math.min(1000,value.length()));
    }
}
