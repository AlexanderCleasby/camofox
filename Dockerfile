# Builds CamoFox browser server with VNC support.
# Downloads Camoufox at build time — suitable for GitHub Actions / CI.
# Source: https://github.com/jo-inc/camofox-browser

FROM node:20-slim

ARG CAMOUFOX_VERSION=135.0.1
ARG CAMOUFOX_RELEASE=beta.24
ARG TARGETARCH
ARG UPSTREAM_REF=main

RUN apt-get update && apt-get install -y \
    git \
    ca-certificates \
    curl \
    unzip \
    python3-minimal \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libasound2 \
    libx11-xcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    libegl1-mesa \
    libgl1-mesa-dri \
    libgbm1 \
    xvfb \
    fonts-liberation \
    fonts-noto-color-emoji \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${UPSTREAM_REF} \
    https://github.com/jo-inc/camofox-browser /app

WORKDIR /app

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) CAMOUFOX_ARCH="x86_64"; YTDLP_SUFFIX="" ;; \
      arm64) CAMOUFOX_ARCH="arm64";   YTDLP_SUFFIX="_aarch64" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    mkdir -p /root/.cache/camoufox; \
    curl -fSL "https://github.com/daijro/camoufox/releases/download/v${CAMOUFOX_VERSION}-${CAMOUFOX_RELEASE}/camoufox-${CAMOUFOX_VERSION}-${CAMOUFOX_RELEASE}-lin.${CAMOUFOX_ARCH}.zip" \
      -o /tmp/camoufox.zip; \
    (unzip -q /tmp/camoufox.zip -d /root/.cache/camoufox || true); \
    chmod -R 755 /root/.cache/camoufox; \
    echo "{\"version\":\"${CAMOUFOX_VERSION}\",\"release\":\"${CAMOUFOX_RELEASE}\"}" > /root/.cache/camoufox/version.json; \
    test -f /root/.cache/camoufox/camoufox-bin && echo "Camoufox installed successfully"; \
    rm /tmp/camoufox.zip; \
    curl -fSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux${YTDLP_SUFFIX}" \
      -o /usr/local/bin/yt-dlp; \
    chmod 755 /usr/local/bin/yt-dlp

RUN PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci --production

# Installs VNC stack (x11vnc, novnc, python3-websockify) declared in plugins/vnc/apt.txt
RUN sh scripts/install-plugin-deps.sh

ENV NODE_ENV=production
ENV CAMOFOX_PORT=9377

EXPOSE 9377
EXPOSE 6080

CMD ["sh", "-c", "node --max-old-space-size=${MAX_OLD_SPACE_SIZE:-128} server.js"]
