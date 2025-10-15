FROM alpine:latest

ENV MAX_SAMBA_USERS=5

COPY entrypoint.sh /entrypoint.sh

RUN apk update && \
    chmod +x /entrypoint.sh && \
    apk add --no-cache samba samba-common-tools && \
    for i in $(seq 1 $MAX_SAMBA_USERS); do \
        adduser -S -D -H -s /sbin/nologin samba$i; \
    done

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-F","--debug-stdout","--no-process-group"]
