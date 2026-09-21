package com.snaphere.api.place;

import com.fasterxml.jackson.databind.JsonNode;
import com.snaphere.api.common.error.ApiException;
import com.snaphere.api.common.error.ErrorCode;
import com.snaphere.api.config.PlatformProperties;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Locale;

@Component
public class GoogleGeocodingClient {
    private final RestClient client;
    private final PlatformProperties.Google properties;

    public GoogleGeocodingClient(RestClient.Builder builder, PlatformProperties.Google properties) {
        this.client = builder.baseUrl(properties.geocodingBaseUrl()).build();
        this.properties = properties;
    }

    public AdministrativeArea reverse(double lat, double lng) {
        return nearest(lat, lng).administrativeArea();
    }

    public ResolvedPlace nearest(double lat, double lng) {
        if (properties.mapsApiKey() == null || properties.mapsApiKey().isBlank()) {
            throw new ApiException(ErrorCode.COMMON_503);
        }
        JsonNode body = client.get().uri(uri -> uri.queryParam("latlng", lat + "," + lng)
                .queryParam("language", "ko").queryParam("key", properties.mapsApiKey()).build())
                .retrieve().body(JsonNode.class);
        if (body == null || !"OK".equals(body.path("status").asText()) || body.path("results").isEmpty()) {
            throw new ApiException(ErrorCode.PLACE_OUT_OF_SERVICE_AREA);
        }
        String country = null;
        String level1 = null;
        String level2 = null;
        String locality = null;
        String sublocality = null;
        JsonNode firstResult = body.path("results").get(0);
        String suggestedName = null;
        for (JsonNode result : body.path("results")) {
            for (JsonNode component : result.path("address_components")) {
                JsonNode types = component.path("types");
                if (contains(types, "country")) country = component.path("short_name").asText();
                if (contains(types, "administrative_area_level_1")) level1 = component.path("long_name").asText();
                if (contains(types, "administrative_area_level_2")) level2 = component.path("long_name").asText();
                if (contains(types, "locality")) locality = component.path("long_name").asText();
                if (contains(types, "sublocality_level_1")) sublocality = component.path("long_name").asText();
                if (suggestedName == null && isPlaceNameComponent(types)) {
                    suggestedName = component.path("long_name").asText(null);
                }
            }
        }
        if (!"KR".equals(country) || level1 == null) throw new ApiException(ErrorCode.PLACE_OUT_OF_SERVICE_AREA);
        String district = firstNonBlank(sublocality, level2, locality);
        JsonNode location = firstResult.path("geometry").path("location");
        double resolvedLat = location.path("lat").asDouble(lat);
        double resolvedLng = location.path("lng").asDouble(lng);
        String formattedAddress = firstResult.path("formatted_address").asText(null);
        if (suggestedName == null || suggestedName.isBlank()) {
            suggestedName = firstAddressToken(formattedAddress);
        }
        return new ResolvedPlace(
                firstResult.path("place_id").asText(null),
                suggestedName,
                formattedAddress,
                resolvedLat,
                resolvedLng,
                new AdministrativeArea(normalizeRegion(level1), normalizeDistrict(district)));
    }

    static String normalizeRegion(String value) {
        String v = value.replace("특별자치도", "").replace("특별자치시", "")
                .replace("특별시", "").replace("광역시", "").replace("도", "").trim();
        return switch (v) {
            case "경기도" -> "경기";
            case "강원도" -> "강원";
            case "충청북" -> "충북";
            case "충청남" -> "충남";
            case "전라북", "전북특별" -> "전북";
            case "전라남" -> "전남";
            case "경상북" -> "경북";
            case "경상남" -> "경남";
            case "제주" -> "제주";
            default -> v;
        };
    }

    static String normalizeDistrict(String value) {
        return value == null ? null : value.trim().toLowerCase(Locale.ROOT);
    }

    private static boolean contains(JsonNode values, String expected) {
        if (!values.isArray()) return false;
        for (JsonNode value : values) if (expected.equals(value.asText())) return true;
        return false;
    }

    private static boolean isPlaceNameComponent(JsonNode types) {
        return contains(types, "premise") || contains(types, "point_of_interest")
                || contains(types, "establishment") || contains(types, "route")
                || contains(types, "sublocality_level_2");
    }

    private static String firstAddressToken(String value) {
        if (value == null || value.isBlank()) return null;
        String normalized = value.replaceFirst("^대한민국\\s*", "").trim();
        int comma = normalized.indexOf(',');
        return comma < 0 ? normalized : normalized.substring(0, comma).trim();
    }

    private static String firstNonBlank(String... values) {
        for (String value : values) if (value != null && !value.isBlank()) return value;
        return null;
    }

    public record AdministrativeArea(String regionName, String districtName) { }
    public record ResolvedPlace(String googlePlaceId, String suggestedName,
                                String formattedAddress, double lat, double lng,
                                AdministrativeArea administrativeArea) { }
}
