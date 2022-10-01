FROM alpine:3.16 AS builder
ENV VER="2.6.3"
LABEL maintainer="Jacob Lemus Peschel <root@tlacuache.us>"
RUN     apk update --no-cache && apk add -U --no-cache \
                automake autoconf groff file gawk tar gcc g++ ca-certificates \
                libtool libsodium-dev linux-headers fortify-headers libltdl \
                m4 make musl-dev pcre-dev perl sqlite-dev util-linux-dev libuuid

ARG     CPPFLAGS="-D_FORTIFY_SOURCE=2"
ARG     CFLAGS="-pipe -march=x86-64-v2 -O2 -fstack-protector-strong -fstack-clash-protection -fpic -ftree-vectorize"
ARG     CXXFLAGS="${CFLAGS}"
ARG     LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -Wl,-S -Wl,-O2 -Wl,--enable-new-dtags"

ARG     PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

WORKDIR /tmp/openssl
RUN     wget https://www.openssl.org/source/openssl-3.0.5.tar.gz &&\
        mkdir -pv src && tar xf *tar* -C src --strip-components=1 &&\
        cd src &&\
        perl ./Configure \
                linux-x86_64 \
                --prefix=/usr/local \
                --libdir=/usr/local/lib \
                --openssldir=/usr/local/etc/ssl \
                shared \
                no-weak-ssl-ciphers \
                enable-ec_nistp_64_gcc_128 \
                -Wa,--noexecstack \
                enable-ktls \
                no-err &&\
        make -j$(nproc) && make -j$(nproc) install_sw && make -j$(nproc) install_ssldirs &&\
        rm -rfv /usr/local/etc/ssl/certs &&\
        cp -avr /etc/ssl/cert.pem /usr/local/etc/ssl/ &&\
        cp -avr /etc/ssl/certs/ /usr/local/etc/ssl/
WORKDIR /tmp/openldap
RUN     wget https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.3.tgz &&\
        mkdir -pv src && tar -xzf *tgz -C src/ --strip-components=1 &&\
        cd src &&\
                ./configure \
                        --build=$CBUILD \
                        --host=$CHOST \
                        --prefix=/usr/local \
                        --libexecdir=/usr/local/lib \
                        --sysconfdir=/usr/local/etc \
                        --localstatedir=/run/openldap \
                        --enable-cleartext \
                        --enable-slapd \
                        --enable-crypt \
                        --enable-modules \
                        --enable-dynamic \
                        --enable-versioning=yes \
                        --enable-dnssrv \
                        --enable-ldap \
                        --enable-mdb \
                        --enable-meta \
                        --enable-asyncmeta \
                        --enable-null \
                        --enable-passwd \
                        --enable-relay \
                        --enable-slapi \
                        --enable-sock \
                        --disable-sql \
                        --enable-local \
                        --enable-overlays=yes \
                        --with-tls=openssl \
                        --without-cyrus-sasl \
                        --enable-rlookups \
                        --with-mp \
                        --enable-debug \
                        --enable-dynacl \
                        --enable-aci \
                        --enable-argon2 \
                        --without-systemd \
                        --enable-rlookups \
                        --disable-syslog \
                        --with-argon2=libsodium \
                        --enable-wt &&\
                make -j`nproc` && make install


FROM alpine:3.16 as final

ENV PUID="500"
ENV PGID="500"


COPY --from=builder /usr/local /usr/local
COPY entrypoint.sh /entrypoint.sh
COPY slapd.conf /default/slapd.conf

RUN     apk update --no-cache && \
        apk add -U --no-cache libltdl libsodium shadow libuuid && \
        chmod a+x /entrypoint.sh &&\
        addgroup -S -g 500 openldap &&\
        adduser -S -H -h /data -u 500 -G openldap -D -s /sbin/nologin openldap &&\
        mkdir -pv /data /config/slapd.d /ssl /socket /default /run/openldap && chown -R openldap:openldap /data /config /ssl /socket &&\
        slaptest -f /default/slapd.conf -F /config/slapd.d &&\
        cp -avr /config/slapd.d /default/slapd.d

EXPOSE 389
EXPOSE 636

VOLUME ["/config", "/data", "/ssl", "/socket"]

CMD ["-F", "/config/slapd.d", "-d", "256", "-h", "ldap:/// ldapi://%2Fsocket%2Fldapi/"]
ENTRYPOINT ["/entrypoint.sh"]