# syntax=docker/dockerfile:1.7

FROM alpine:3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

LABEL org.opencontainers.image.title="Reece.AI network toolbox" \
      org.opencontainers.image.description="Diagnostic client for Reece.AI enterprise networking labs" \
      org.opencontainers.image.source="https://gitlab.int.reece.ai/ryanreece/learn-enterprise-networking-for-systems-engineers" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Reece.AI"

RUN apk add --no-cache \
      bash=5.3.9-r1 \
      bind-tools=9.20.29-r0 \
      ca-certificates=20260909-r0 \
      curl=8.22.0-r0 \
      iproute2=7.0.0-r0 \
      iputils=20250605-r2 \
      netcat-openbsd=1.234.1-r0 \
      openssl=3.5.8-r0 \
      tcpdump=4.99.6-r1 \
      traceroute=2.1.6-r0

CMD ["sleep", "infinity"]
