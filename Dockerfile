FROM --platform=$BUILDPLATFORM mirror.gcr.io/library/golang:1.26.5 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION

WORKDIR /src

# 安装 git 和 wget (wget 用于下 geo 文件)
RUN apt update -qq && apt install -y -qq --no-install-recommends git build-essential wget ca-certificates

# 1. 拉取源码
RUN git clone --depth 1 --branch ${VERSION} https://github.com/XTLS/Xray-core.git .

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=$TARGETARCH

# 2. 编译 (AMD64 细分优化逻辑)
#    Xray 特有: -gcflags "all=-l=4"
#    通用优化: -trimpath, -s -w
RUN if [ "$TARGETARCH" = "amd64" ] && [ "$TARGETVARIANT" = "v3" ]; then \
        export GOAMD64=v3; \
    elif [ "$TARGETARCH" = "amd64" ] && [ "$TARGETVARIANT" = "v2" ]; then \
        export GOAMD64=v2; \
    fi && \
    go build -v -trimpath -buildvcs=false \
    -gcflags "all=-l=4" \
    -tags "with_gvisor" \
    -ldflags "-X 'github.com/xtls/xray-core/core.version=${VERSION}' \
              -s -w -buildid= -checklinkname=0" \
    -o /src/xray \
    ./main

# 3. 准备资源文件 (Builder 阶段)
WORKDIR /src/assets
RUN wget -q -O geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat && \
    wget -q -O geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

# 4. 准备默认配置结构
WORKDIR /src/config
RUN mkdir -p /src/config && \
    echo '{ "log": { "error": "/var/log/xray/error.log", "loglevel": "warning", "access": "none", "dnsLog": false } }' > 00_log.json && \
    echo '{}' > 01_api.json && \
    echo '{}' > 02_dns.json && \
    echo '{}' > 03_routing.json && \
    echo '{}' > 04_inbounds.json && \
    echo '{}' > 05_outbounds.json && \
    echo '{}' > 06_policy.json && \
    echo '{}' > 07_transport.json && \
    echo '{}' > 08_stats.json && \
    echo '{}' > 09_reverse.json

FROM gcr.io/distroless/static-debian12:latest

# 复制二进制
COPY --from=builder --chown=0:0 --chmod=755 /src/xray /usr/bin/xray

# 复制资源文件到 Xray 默认查找目录
COPY --from=builder --chown=0:0 --chmod=644 /src/assets/*.dat /usr/local/share/xray/

# 复制配置文件
COPY --from=builder --chown=0:0 --chmod=644 /src/config/*.json /usr/local/etc/xray/

# 设置 Volume
VOLUME /usr/local/etc/xray
VOLUME /var/log/xray

ENV TZ=Asia/Shanghai

ENTRYPOINT ["/usr/bin/xray"]
CMD ["run", "-confdir", "/usr/local/etc/xray/"]
