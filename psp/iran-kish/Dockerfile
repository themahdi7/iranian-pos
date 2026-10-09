FROM iranian-pos-wine:latest

ENV PCPOS_PORT=9500

WORKDIR /app/WebDll
COPY psp/iran-kish/vendor/ /app/WebDll/
COPY psp/iran-kish/docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    && test -f /app/WebDll/Kiccc.PCPOS.Service.exe \
    || (echo "Missing vendor files. See psp/iran-kish/vendor/README.md" >&2 && exit 1)

EXPOSE 9500
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD python3 -c "import socket;s=socket.socket();s.settimeout(2);s.connect(('127.0.0.1',9500))"

ENTRYPOINT ["/entrypoint.sh"]
