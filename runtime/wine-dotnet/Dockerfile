# Shared Wine + Wine Mono runtime for Iranian PC-POS Windows services.
# PSP images should FROM this, then copy their official vendor files.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    WINEARCH=win64 \
    WINEPREFIX=/wine \
    WINEDEBUG=-all \
    DISPLAY=:99 \
    WINEDLLOVERRIDES=winemenubuilder.exe=d

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        gnupg \
        xz-utils \
        xvfb \
        python3 \
        procps \
        curl \
        iproute2 \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key \
    && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
    && apt-get update \
    && apt-get install -y --install-recommends winehq-stable \
    && rm -rf /var/lib/apt/lists/*

# Keep in sync with winehq-stable (Wine 11.x currently wants Mono 10.4.1).
RUN mkdir -p /usr/share/wine/mono \
    && wget -q -O /tmp/wine-mono.tar.xz \
        https://dl.winehq.org/wine/wine-mono/10.4.1/wine-mono-10.4.1-x86.tar.xz \
    && tar -xJf /tmp/wine-mono.tar.xz -C /usr/share/wine/mono \
    && rm /tmp/wine-mono.tar.xz
