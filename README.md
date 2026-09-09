# Xray Docker Image

[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/SuperNG6/docker-xray/Auto%20Build%20Image.yml?branch=main&logo=github&label=Auto%20Build)](https://github.com/SuperNG6/docker-xray/actions/workflows/Auto%20Build%20Image.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/superng6/xray?logo=docker&label=Docker%20Hub%20Pulls)](https://hub.docker.com/r/superng6/xray)
[![GitHub Stars](https://img.shields.io/github/stars/SuperNG6/docker-xray?logo=github&label=Stars)](https://github.com/SuperNG6/docker-xray)

一个基于 [XTLS/Xray-core](https://github.com/XTLS/Xray-core) 官方源码自动构建的多平台 Docker 镜像。

官方文档: [https://xtls.github.io](https://xtls.github.io/)

---

## 镜像仓库地址

镜像同时推送到 Docker Hub 和 GitHub Container Registry (GHCR)。

- **Docker Hub:**

  ```console
  docker pull superng6/xray
  ```

- **GHCR.io:**

  ```console
  docker pull ghcr.io/superng6/xray
  ```

---

## 标签 (Tags)

本仓库根据上游官方 Release 自动构建并维护以下标签：

* **`latest`** & `version tag` (如 `v26.1.23`)
[XTLS/Xray-core 的最新稳定版 (Stable Release)](https://github.com/XTLS/Xray-core/releases)，包含所有正式功能，推荐生产环境使用。

* **`dev`** & `version tag`（如 `v26.9.9`）
[XTLS/Xray-core 的最新预发布版 (Pre-release)](https://github.com/XTLS/Xray-core/releases)。通过上游 Release 的 `prerelease` 标记识别，版本号不一定包含 `beta` 或 `rc`。

```console
docker pull superng6/xray:dev
docker pull ghcr.io/superng6/xray:dev
```

在 Docker Compose 中，将 `image` 改为 `superng6/xray:dev` 或 `ghcr.io/superng6/xray:dev` 即可使用预发布通道。`latest` 始终跟踪稳定版。

---

## 编译优化与特性

### 极致性能优化

本镜像在编译时应用了激进的性能优化参数：

* **GC Flags**: `-gcflags "all=-l=4"` (激进内联优化，提升吞吐量)
* **LD Flags**: `-s -w` (去除调试符号，减小体积)
* **Trimpath**: 移除构建路径信息，保证构建产物纯净

### 支持的架构

通过 GitHub Actions 自动构建，支持以下架构：

* `linux/amd64` (**v1/v2/v3 自动优化选择**)
* `linux/arm64` (arm64/v8)
* `linux/arm/v7`
* `linux/ppc64le`
* `linux/s390x`

> **Note:**
> 多架构支持，为 `amd64` 平台同时提供了 `v1` (通用), `v2` (SSE4.2+), `v3` (AVX2+) 三种优化构建。
> 当执行 `docker pull` 或运行容器时，Docker 客户端会自动根据你的宿主机 CPU 支持的指令集级别，拉取并运行性能最优的那个镜像变体，无需任何手动配置。
> **性能优势：**
> * **x86-64-v2**: 相比 v1，增加了 SSE3, SSE4, POPCNT 等指令集支持。适用于大多数现代 CPU。
> * **x86-64-v3**: 相比 v2，进一步增加了 **AVX2**, BMI2, FMA, MOVBE 等指令集支持。适用于 Haswell (2013) 及更新架构。
> 
> 

---

## Dockerfile 设计说明

* 使用多阶段构建，第一阶段基于 `golang:1.27` 进行编译。
* 运行阶段基于 `gcr.io/distroless/static-debian12:latest`，极简镜像，安全无 Shell。
* 采用 `confdir` 模式启动，支持多配置文件合并。

---

## 配置文件和数据卷

* **配置文件目录**: `/usr/local/etc/xray/`
* 默认启动命令为 `run -confdir /usr/local/etc/xray/`。
* 你可以将多个 `.json` 文件放入该目录，Xray 会自动合并读取。


* **Geo资源目录**: `/usr/local/share/xray/`
* 镜像内已预置了 [Loyalsoldier](https://github.com/Loyalsoldier/v2ray-rules-dat) 版本的 `geoip.dat` 和 `geosite.dat`。
* 如需自定义，可挂载覆盖此目录。



---

## 使用示例

以下示例展示如何在支持 TUN 设备的模式下运行 Xray。

### Docker Compose (推荐)

假设你的配置文件放在当前目录的 `config` 文件夹中。

**Docker Hub 镜像示例：**

```yaml
services:
  xray:
    image: superng6/xray:latest
    container_name: xray
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/usr/local/etc/xray  # 挂载配置目录
      # - ./assets:/usr/local/share/xray # (可选) 挂载自定义 Geo 文件
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun

```

**GHCR 镜像示例：**

```yaml
services:
  xray:
    image: ghcr.io/superng6/xray:latest
    container_name: xray
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/usr/local/etc/xray
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun

```

### Docker CLI

**Docker Hub：**

```bash
docker run -d \
  --name xray \
  --network host \
  --restart unless-stopped \
  -v $(pwd)/config:/usr/local/etc/xray \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  superng6/xray:latest

```

---

## 自动化构建

所有镜像通过 GitHub Actions 自动构建，保证镜像纯净且及时更新。
* **Auto Build Docker Image**：每天 UTC 18:30（北京时间次日 02:30）检查上游，也可手动触发。稳定版与预发布版分别检测，只有版本变化时才构建对应通道。
* **Manual Build Docker Image**：手动触发或修改 `Dockerfile` 时，重建两个通道。可填写 `stable_version` / `pre_version` 指定上游 tag；留空时读取对应版本文件，没有记录的通道会跳过。手动指定版本不会修改自动检测记录。
* 两个通道均构建上述全部架构，并发布到 Docker Hub 和 GHCR；稳定版发布 `latest` 与版本标签，预发布版发布 `dev` 与版本标签。
* `ReleaseTag` / `PreReleaseTag` 分别记录成功发布的版本，只有对应通道的镜像发布并检查成功后才更新。失败的构建会在下次自动检查时重试。`PreReleaseTag` 初始为空，首次运行自动工作流时会检测并构建预发布版。
* 使用现有 `DOCKERHUB_USERNAME`、`DOCKERHUB_TOKEN` secrets 和自动提供的 `GITHUB_TOKEN`。自动工作流需要能写入版本记录文件，GHCR 发布需要 `packages: write`（工作流已声明）。

构建状态查看：[GitHub Actions](https://github.com/SuperNG6/docker-xray/actions)

---

## License

**Mozilla Public License Version 2.0**

The core code of Project X is licensed under MPL 2.0.

```
