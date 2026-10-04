# syntax=docker/dockerfile:1.7
# Tip: pin both base images by digest (image:tag@sha256:...) for reproducible, tamper-evident builds.
FROM gradle:9.0.0-jdk21-alpine AS builder

WORKDIR /app

COPY build.gradle.kts gradle.properties settings.gradle.kts ./
COPY gradle/libs.versions.toml gradle/

RUN gradle --no-daemon shadowJar

COPY src ./src
RUN gradle --no-daemon shadowJar

FROM eclipse-temurin:21-jre-alpine

# pinned so a new upstream release can't silently change behaviour (or ship a compromised build) on rebuild
ARG STREAMLINK_VERSION=8.6.1

WORKDIR /app

RUN apk upgrade --no-cache && \
    apk add --no-cache ffmpeg python3 && \
    apk add --no-cache --virtual .pip py3-pip && \
    pip3 install --no-cache-dir --break-system-packages --root-user-action=ignore "streamlink==${STREAMLINK_VERSION}" && \
    apk del .pip

# streamlink config lives outside the bot user's home and is root-owned, so the bot can't alter it:
#  - no-plugin-sideloading: never load extra Python plugins from a data directory
#  - twitch-supported-codecs=h264: H.264 is what Telegram reliably previews and plays inline (HEVC/AV1 often show black)
ENV XDG_CONFIG_HOME=/etc \
    XDG_CACHE_HOME=/tmp/.cache
RUN mkdir -p /etc/streamlink && \
    printf '%s\n' 'no-plugin-sideloading' 'twitch-supported-codecs=h264' > /etc/streamlink/config && \
    chmod 0644 /etc/streamlink/config

# ffmpeg shim: makes clip MP4s start on a decodable keyframe so Telegram renders a preview instead of a black square.
# /usr/local/bin precedes /usr/bin in PATH; the real binary stays at /usr/bin/ffmpeg. Owned by root, not writable by the bot.
COPY --chmod=0755 docker/ffmpeg-clip-wrapper.sh /usr/local/bin/ffmpeg

RUN adduser -u 10001 -D -s /sbin/nologin twitchbot

# root-owned (COPY ignores USER), so the running bot can't overwrite its own jar
COPY --from=builder /app/build/libs/*-all.jar twitchviewer-bot.jar

USER twitchbot

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD test $(( $(date +%s) - $(stat -c %Y /tmp/health 2>/dev/null || echo 0) )) -lt 90

ENTRYPOINT ["java", "-XX:+ExitOnOutOfMemoryError", "-jar", "twitchviewer-bot.jar"]
