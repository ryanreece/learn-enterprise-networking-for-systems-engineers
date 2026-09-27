# syntax=docker/dockerfile:1.7

FROM coredns/coredns:1.14.7@sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286 AS coredns

FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

LABEL org.opencontainers.image.title="Reece.AI Lab 01 DNS" \
      org.opencontainers.image.description="CoreDNS with data-plane configuration tools for Reece.AI Lab 01" \
      org.opencontainers.image.source="https://gitlab.int.reece.ai/ryanreece/learn-enterprise-networking-for-systems-engineers" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Reece.AI"

RUN apk add --no-cache iproute2=7.0.0-r0

COPY --from=coredns /coredns /usr/local/bin/coredns

ENTRYPOINT ["/usr/local/bin/coredns"]
CMD ["-conf", "/Corefile"]
