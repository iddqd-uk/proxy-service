# syntax=docker/dockerfile:1.2

FROM alpine:latest as builder

# create a directory for the future root filesystem
WORKDIR /tmp/rootfs

# prepare the root filesystem
RUN set -x \
    && mkdir -p ./etc ./home/caddy \
    && echo 'caddy:x:10001:10001::/home/caddy:/sbin/nologin' > ./etc/passwd \
    && echo 'caddy:x:10001:' > ./etc/group \
    && chown -R 10001:10001 ./home/caddy

# copy the caddy config file
COPY ./caddy.json ./etc/caddy.json

# copy the frontend sources
COPY --chown=10001:10001 ./src ./web

# use empty filesystem for the result image
FROM scratch as runtime

LABEL \
    # Docs: <https://github.com/opencontainers/image-spec/blob/master/annotations.md>
    org.opencontainers.image.title="proxy-index" \
    org.opencontainers.image.description="index for the proxy service" \
    org.opencontainers.image.url="https://github.com/iddqd-uk/proxy-service" \
    org.opencontainers.image.source="https://github.com/iddqd-uk/proxy-service" \
    org.opencontainers.image.vendor="tarampampam"

# install curl (https://github.com/tarampampam/curl-docker)
COPY --from=tarampampam/curl:7.83.1 --chown=0:0 /bin/curl /bin/curl

# install caddy file server (image page: <https://hub.docker.com/_/caddy>)
COPY --from=caddy:2.5.2-alpine --chown=0:0 /usr/bin/caddy /bin/caddy

# import the root filesystem
COPY --from=builder /tmp/rootfs /

# use an unprivileged user
USER 10001:10001

# Docs: <https://docs.docker.com/engine/reference/builder/#healthcheck>
HEALTHCHECK --interval=15s --timeout=2s --retries=2 --start-period=2s CMD [ \
    "curl", "--fail", "--user-agent", "internal/healthcheck", "http://127.0.0.1:8080/health/live" \
]

ENTRYPOINT ["/bin/caddy"]

CMD ["run", "-config", "/etc/caddy.json"]
