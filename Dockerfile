FROM alpine:latest

ENV MAX_SAMBA_USERS=5

RUN apk update && \
    apk add --no-cache samba samba-common-tools && \
    for i in $(seq 1 $MAX_SAMBA_USERS); do \
        adduser -S -D -H -s /sbin/nologin samba$i; \
    done

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-D"]
