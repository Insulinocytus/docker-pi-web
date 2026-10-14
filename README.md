# docker-pi-web

把 [pi-web](https://github.com/agegr/pi-web) 和 [pi coding agent](https://github.com/earendil-works/pi) 打包成一个 Docker 镜像，一条命令就能在服务器上部署一个浏览器访问的云端 agent。

- 一个容器服务一个用户，Agent 数据、工作区、git/ssh 配置都放在同一个 volume 里，重建容器不丢
- 镜像内的 `pi` 命令就是 pi-web 内置的那份 pi，两者版本始终一致
- 每天自动跟进 pi-web 的 npm 新版本，每周自动重建拿基础镜像安全补丁，发布前过冒烟测试
- 支持 `linux/amd64` 和 `linux/arm64`

## 快速开始

需要 Docker 和 Docker Compose。下载 [`compose.yaml`](compose.yaml)，然后：

```bash
PI_WEB_PASSWORD='一个足够长的随机密码' docker compose up -d
```

浏览器打开 `http://<服务器地址>:30141`，用该密码登录，在 **Models** 面板里登录模型提供商或填入 API key 即可开始使用。

> [!WARNING]
> 镜像只提供 HTTP，密码会明文传输。暴露到公网之前务必按下文配置 HTTPS，或者只在 VPN 内访问。

不想用 compose 也可以直接运行：

```bash
docker run -d --name pi-web --restart unless-stopped \
  -p 30141:30141 \
  -e PI_WEB_PASSWORD='一个足够长的随机密码' \
  -v pi-web-home:/home/pi \
  ghcr.io/insulinocytus/docker-pi-web:latest
```

## 环境变量

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `PI_WEB_PASSWORD` | 登录密码，API 客户端可用 Basic Auth（用户名 `pi`）。**必填**，未设置时容器拒绝启动 | 无 |
| `PI_WEB_INSECURE_NO_PASSWORD` | 设为 `1` 时允许不设密码启动。只在完全可信的网络里使用 | 未设置 |
| `PI_WEB_ALLOWED_HOSTS` | 通过域名访问时必须把域名加进来（逗号分隔），否则返回 403。用 IP 访问不需要 | 空 |
| `TZ` | 时区，影响终端时间、git 提交时间和默认工作区按日期分的目录 | `UTC` |
| `PORT` | 容器内监听端口 | `30141` |
| `PI_WEB_IDLE_TIMEOUT_MS` | 空闲会话多久后从内存卸载，`0` 为不卸载 | `600000` |

镜像已默认设置 `PI_WEB_SKIP_VERSION_CHECK=1`、`PI_SKIP_VERSION_CHECK=1`（升级靠拉新镜像，不在容器里原地更新）和 `PI_TELEMETRY=0`。其余 pi-web 支持的变量见 [pi-web 文档](https://github.com/agegr/pi-web#configuration)。

## 配置 HTTPS

把端口改为只监听本机，让反向代理或隧道负责 HTTPS：

```yaml
    ports:
      - "127.0.0.1:30141:30141"
```

**Caddy**（自动申请证书）：

```caddyfile
agent.example.com {
	reverse_proxy 127.0.0.1:30141
}
```

```bash
PI_WEB_PASSWORD='...' PI_WEB_ALLOWED_HOSTS=agent.example.com docker compose up -d
```

**Cloudflare Tunnel / Tailscale 等隧道**：把隧道指向 `http://localhost:30141`，同样把对外的域名加进 `PI_WEB_ALLOWED_HOSTS`。

无论用哪种代理，都要转发原始 `Host` 头和 `X-Forwarded-Proto`，并支持 WebSocket（网页终端需要）。

## 升级

```bash
docker compose pull && docker compose up -d
```

| 标签 | 含义 |
| --- | --- |
| `latest` | 最新的 pi-web 版本 |
| `<pi-web 版本>`，如 `0.12.1` | 该版本的 pi-web |

> [!NOTE]
> 两种标签都会被覆盖：镜像本身有改动或每周例行重建时会重新推送同一个标签。想完全锁定，请用 digest（`ghcr.io/insulinocytus/docker-pi-web@sha256:...`）。

## 镜像里有什么

- 基础镜像 `node:24-trixie-slim`
- pi-web 装在 `/opt/pi-web`，`pi` 和 `pi-web` 命令在 `PATH` 里
- 工具：`bash`、`git`、`curl`、`ripgrep`、`fd`、`openssh-client`、`python3`、`sudo`
- 以用户 `pi`（UID/GID 1000）运行，home 为 `/home/pi`；新会话默认工作区是 `~/pi-cwd/<日期>`，也可以在界面里填其他目录
- 只有 `/home/pi` 会持久化：放在其他目录的项目、agent 用 `sudo apt-get install` 装的工具，重建容器后都会丢失

## 安全须知

> [!CAUTION]
> 能登录的人就能在容器里以 root 权限执行任意命令。

- **agent 有免密 sudo。** 隔离边界是容器本身，不是容器内的用户权限，原因见 [ADR-0001](docs/adr/0001-agent-has-passwordless-sudo.md)。不要挂载宿主机的 Docker socket 或敏感目录。
- **密码防暴力破解是全局退避**（最长 60 秒）。有人持续猜密码时，你自己也会被一起挡在外面。暴露到公网时建议放在 VPN 后面，或在反向代理上做限流。
- **用 bind mount 代替具名 volume 时**，宿主机目录的属主要改成 `1000:1000`，否则容器内无法写入。

## 本地构建与测试

```bash
docker build -t docker-pi-web:dev .                       # 默认装 npm 上最新的 pi-web
docker build --build-arg PI_WEB_VERSION=0.12.1 -t docker-pi-web:dev .
bash test/smoke.sh docker-pi-web:dev                       # 冒烟测试，CI 发布前也跑它
```
