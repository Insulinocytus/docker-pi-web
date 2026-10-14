#!/usr/bin/env bash
# 冒烟测试：smoke.sh <image>。CI 发布前的门禁，也可本地运行。
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Windows Git Bash 下别改写容器内路径

image=${1:?用法: smoke.sh <image>}
password=smoke-test-password
name=pi-web-smoke-$$
fail() { echo "FAIL: $*" >&2; docker logs "$name" >&2 || true; exit 1; }
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

echo "-- 未设置密码时拒绝启动"
if out=$(docker run --rm "$image" 2>&1); then fail "未设置 PI_WEB_PASSWORD 却启动成功"; fi
[[ "$out" == *PI_WEB_PASSWORD* ]] || fail "拒绝启动的原因不对: $out"

echo "-- 带密码启动，等待健康检查通过"
docker run -d --name "$name" -e PI_WEB_PASSWORD="$password" \
  --health-interval=2s --health-start-period=60s -p 127.0.0.1::30141 "$image" >/dev/null
for _ in $(seq 60); do
  status=$(docker inspect -f '{{.State.Health.Status}}' "$name")
  [ "$status" = healthy ] && break
  [ "$(docker inspect -f '{{.State.Running}}' "$name")" = true ] || fail "容器已退出"
  sleep 2
done
[ "$status" = healthy ] || fail "健康检查未通过: $status"
url="http://$(docker port "$name" 30141 | head -n1)"

echo "-- 未认证请求被拦截"
code=$(curl -s -o /dev/null -w '%{http_code}' "$url/api/home")
[ "$code" = 401 ] || fail "未认证 /api/home 期望 401，实际 $code"
code=$(curl -s -o /dev/null -w '%{http_code}' "$url/")
[ "$code" = 307 ] || fail "未认证 / 期望 307 跳转登录，实际 $code"

echo "-- Basic auth 可访问"
code=$(curl -s -o /dev/null -w '%{http_code}' -u "pi:$password" "$url/api/home")
[ "$code" = 200 ] || fail "认证后 /api/home 期望 200，实际 $code"

echo "-- pi 命令就是 pi-web 内置的那份 pi"
expected=$(docker exec "$name" node -p "require('/opt/pi-web/node_modules/@earendil-works/pi-coding-agent/package.json').version")
actual=$(docker exec "$name" pi --version)
[[ "$actual" == *"$expected"* ]] || fail "pi --version 输出 '$actual'，期望包含 $expected"

echo "-- 网页终端依赖的 node-pty 可用"
docker exec "$name" node -e 'require("/opt/pi-web/node_modules/node-pty").spawn("true", [], {}).onExit((e) => process.exit(e.exitCode))' \
  || fail "node-pty 无法启动 pty，网页终端会失效"

echo "-- 以 pi 用户运行，pi-web 安装目录可写（否则 preview secret 无法轮换，存在认证绕过）"
[ "$(docker exec "$name" whoami)" = pi ] || fail "运行用户不是 pi"
docker exec "$name" test -w /opt/pi-web/node_modules/@agegr/pi-web/.next || fail ".next 不可写"
docker exec "$name" sudo -n true || fail "免密 sudo 不可用"

echo "PASS"
