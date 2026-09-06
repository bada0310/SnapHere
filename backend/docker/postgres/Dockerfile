ARG PERCONA_IMAGE=percona/percona-distribution-postgresql-with-postgis:17.10-5@sha256:3a162e3e590350fb7be8af7210785702ff4874abcd67977c5ee32f45d4d08e1e

FROM ${PERCONA_IMAGE} AS postgis-builder

USER 0

ARG POSTGIS_VERSION=3.6.2
ARG POSTGIS_SHA256=d488089a64ee4060bce7dbba0291fcca358e7f7ac5230e2ee5b344e7485729c4

ENV PATH="/usr/pgsql-17/bin:/usr/geos313/bin:/usr/proj95/bin:${PATH}" \
    PKG_CONFIG_PATH="/usr/geos313/lib64/pkgconfig:/usr/proj95/lib64/pkgconfig:/usr/lib64/pkgconfig" \
    CPPFLAGS="-I/usr/proj95/include -I/usr/geos313/include" \
    LDFLAGS="-L/usr/proj95/lib64 -L/usr/geos313/lib64" \
    LD_LIBRARY_PATH="/usr/proj95/lib64:/usr/geos313/lib64"

RUN dnf -y --enablerepo=ol9_codeready_builder install \
        percona-postgresql17-devel \
        geos313-devel \
        proj95-devel \
        libxml2-devel \
        json-c-devel \
        pcre2-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN curl --fail --location --silent --show-error \
        "https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz" \
        --output /tmp/postgis.tar.gz \
    && echo "${POSTGIS_SHA256}  /tmp/postgis.tar.gz" | sha256sum --check --strict \
    && mkdir /tmp/postgis-source \
    && tar --extract --gzip --file /tmp/postgis.tar.gz --directory /tmp/postgis-source --strip-components=1 \
    && cd /tmp/postgis-source \
    && ./configure \
        --with-pgconfig=/usr/pgsql-17/bin/pg_config \
        --with-geosconfig=/usr/geos313/bin/geos-config \
        --with-projdir=/usr/proj95 \
        --without-raster \
        --without-protobuf \
    && make -j"$(nproc)" \
    && make DESTDIR=/opt/postgis install

FROM ${PERCONA_IMAGE}

USER 0

ENV LD_LIBRARY_PATH="/usr/geos313/lib64:/usr/proj95/lib64"

RUN rpm --erase --nodeps \
        percona-postgis35_17 \
        percona-postgis35_17-client \
        percona-postgis35_17-gui \
        percona-postgis35_17-llvmjit \
        percona-postgis35_17-utils

COPY --from=postgis-builder /opt/postgis/ /

LABEL org.opencontainers.image.title="SnapHere Percona PostgreSQL with PostGIS" \
      org.opencontainers.image.description="Percona PostgreSQL 17.10.2 with source-built PostGIS 3.6.2" \
      org.opencontainers.image.version="17.10.2-postgis3.6.2" \
      org.opencontainers.image.source="https://download.osgeo.org/postgis/source/postgis-3.6.2.tar.gz"
