FROM golang:alpine as builder

RUN apk --no-cache add mercurial git \
    && go get github.com/sirupsen/logrus \
    && go get github.com/morph027/textsecure/ \
    && cd src/github.com/morph027/textsecure/cmd/textsecure \
    && go build \
    && mv /go/src/github.com/morph027/textsecure/cmd/textsecure /output \
    && rm -f /output/main.go

FROM alpine:latest

WORKDIR /signal

COPY --from=builder /output /signal

COPY start.py /signal/start.py

COPY entrypoint.sh /

RUN apk --no-cache add \
      sudo \
    && addgroup signal \
    && adduser -G signal -h /signal -s /bin/sh -D signal \
    && echo "%signal ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/signal \
    && chmod 400 /etc/sudoers.d/signal \
    && apk --no-cache add \
      tini \
      py-pip \
      ca-certificates \
      build-base \
    && sudo -u signal -H pip install --user \
      flask \
      gunicorn \
      pyyaml \
    && rm -rf .cache \
    && apk del build-base

USER signal

ENTRYPOINT ["/sbin/tini", "-g", "--"]

CMD ["/entrypoint.sh"]

EXPOSE 5000
