package com.snaphere.api.auth;

import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;

public final class ExternalIds {
    private ExternalIds() {
    }

    public static String user(long id) { return encode("usr", id); }
    public static String place(long id) { return encode("plc", id); }
    public static String post(long id) { return encode("pst", id); }
    public static String event(long id) { return encode("evt", id); }
    public static String badge(long id) { return encode("bdg", id); }
    public static String report(long id) { return encode("rpt", id); }
    public static String run(long id) { return encode("run", id); }
    public static String sync(long id) { return encode("sync", id); }
    public static String tag(long id) { return encode("tag", id); }

    public static long parse(String value, String prefix, ErrorCode error) {
        try {
            if (value == null || !value.startsWith(prefix + "_")) throw new IllegalArgumentException();
            return Long.parseLong(value.substring(prefix.length() + 1), 36);
        } catch (RuntimeException e) {
            throw new ApiException(error);
        }
    }

    private static String encode(String prefix, long id) {
        return prefix + "_" + Long.toString(id, 36);
    }
}
