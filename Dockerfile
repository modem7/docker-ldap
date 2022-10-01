# syntax = docker/dockerfile-upstream:master-labs

FROM alpine:edge as final

ENV PUID="500"
ENV PGID="500"

RUN <<EOF
    set -xe
    apk add -U --no-cache \
    libltdl \
    openldap \
    openssl \
    libsodium \
    shadow \
    libuuid
EOF

RUN <<EOF
    set -xe
    addgroup -S -g 500 openldap
    adduser -S -H -h /data -u 500 -G openldap -D -s /sbin/nologin openldap
    mkdir -pv /data /config/slapd.d /ssl /socket /default /run/openldap
    chown -R openldap:openldap /data /config /ssl /socket
EOF

COPY --link --chmod=755 entrypoint.sh /entrypoint.sh
COPY --link slapd.conf /default/slapd.conf

RUN <<EOF
    set -xe
    slaptest -f /default/slapd.conf -F /config/slapd.d
    cp -avr /config/slapd.d /default/slapd.d
EOF

EXPOSE 389
EXPOSE 636

VOLUME ["/config", "/data", "/ssl", "/socket"]

CMD ["-F", "/config/slapd.d", "-d", "256", "-h", "ldap:/// ldapi://%2Fsocket%2Fldapi/"]
ENTRYPOINT ["/entrypoint.sh"]