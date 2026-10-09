FROM iranian-pos-wine:latest

ENV SSP_SIGNALR_PORT=8080 \
    SSP_API_PORT=8090 \
    SSP_POS_IP=192.168.1.100 \
    SSP_HOST_URL=http://127.0.0.1:8080

WORKDIR /app
COPY psp/sep/vendor/ /app/Install/
COPY psp/sep/docker/entrypoint.sh /entrypoint.sh
COPY psp/sep/docker/api_bridge.py /app/api_bridge.py

RUN chmod +x /entrypoint.sh \
    && test -f /app/Install/SSP1126SignalRWindowsService.exe \
    || (echo "Missing vendor files. See psp/sep/vendor/README.md" >&2 && exit 1)

EXPOSE 8080 8090
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${SSP_API_PORT}/health" >/dev/null

ENTRYPOINT ["/entrypoint.sh"]
