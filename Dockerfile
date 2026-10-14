FROM node:24-trixie-slim

ARG PI_WEB_VERSION=latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash sudo tini git curl ca-certificates ripgrep fd-find openssh-client python3 tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/bin/fdfind /usr/local/bin/fd \
 # 基础镜像的 node 用户占了 UID 1000，直接改名为 pi
 && groupmod -n pi node \
 && usermod -l pi -d /home/pi -m -s /bin/bash node \
 && echo 'pi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/pi \
 && chmod 0440 /etc/sudoers.d/pi \
 && install -d -o pi -g pi /opt/pi-web \
 && ln -s /opt/pi-web/node_modules/.bin/pi-web /opt/pi-web/node_modules/.bin/pi /usr/local/bin/

COPY --chmod=0755 pi-web-entrypoint /usr/local/bin/pi-web-entrypoint

USER pi
WORKDIR /home/pi

# 安装目录必须归 pi 所有：pi-web 每次启动要改写 .next 里的 preview secret，否则留下认证绕过
RUN npm install --prefix /opt/pi-web --omit=dev --cache /tmp/npm-cache "@agegr/pi-web@${PI_WEB_VERSION}" \
 && rm -rf /tmp/npm-cache \
 # pi 命令必须是 pi-web 内置的那份，保证版本一致
 && readlink -f /usr/local/bin/pi | grep -q '/node_modules/@earendil-works/pi-coding-agent/'

ENV SHELL=/bin/bash \
    PI_WEB_SKIP_VERSION_CHECK=1 \
    PI_SKIP_VERSION_CHECK=1 \
    PI_TELEMETRY=0

EXPOSE 30141
HEALTHCHECK CMD curl -fsS -o /dev/null "http://127.0.0.1:${PORT:-30141}/login" || exit 1
ENTRYPOINT ["tini", "--", "pi-web-entrypoint"]
