# Build Busybox
FROM alpine:3.24 AS build-busybox

# renovate: datasource=custom.busybox depName=busybox
ENV BUSYBOX_VERSION="1.38.0"

RUN apk add gcc musl-dev make perl
RUN wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 \
  && tar xf busybox-${BUSYBOX_VERSION}.tar.bz2 \
  && mv /busybox-${BUSYBOX_VERSION} /busybox

WORKDIR /busybox
COPY .config ./

RUN make && make install
RUN adduser -D static

# Download catatonit
# renovate: datasource=github-releases depName=openSUSE/catatonit
ENV CATATONIT_VERSION="v0.2.1"
ADD --chmod=+x https://github.com/openSUSE/catatonit/releases/download/${CATATONIT_VERSION}/catatonit.x86_64 /catatonit

# Compile scratch image
FROM scratch AS compile

COPY --from=build-busybox /etc/passwd /etc/passwd
COPY --from=build-busybox /busybox/_install/bin/busybox /
COPY --from=build-busybox /catatonit /

# The "static" user created above (uid 1000), numeric so Kubernetes'
# runAsNonRoot can verify it.
USER 1000:1000
WORKDIR /www

ENTRYPOINT ["/catatonit", "--"]
CMD ["/busybox", "httpd", "-f", "-p", "8080"]
