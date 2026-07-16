#!/usr/bin/env bash
# =====================================================================
#  Matrix 全功能一键安装脚本(通用版 v1.1)
#  在任意域名 + 任意 Ubuntu 22/24 / Debian 11+ 服务器上部署:
#    聊天/群聊 + 图片视频文件互传 + 一对一及群组语音视频通话(E2EE)
#  组件: Caddy(自动HTTPS) + Synapse + PostgreSQL + LiveKit + lk-jwt-service
#  客户端: Element X / Element Web / 任意 Matrix 客户端
#
#  用法(先把脚本下载到服务器,再以 root 执行):
#    sudo bash matrix-installer.sh           # 标准用法:向导会询问域名
#    sudo bash matrix-installer.sh mychat.org  # 高级用法:直接带域名参数
#    sudo bash matrix-installer.sh adduser   # 部署完后:添加团队成员
#
#  前提: 4 条 DNS A 记录已指向本服务器公网 IP:
#    你的域名.com  matrix.你的域名.com  livekit.你的域名.com  matrix-rtc.你的域名.com
#
#  可选环境变量:
#    INSTALL_DIR=/opt/matrix   安装目录(默认)
#    ACME_EMAIL=you@x.com      证书通知邮箱(默认 admin@域名)
#    SKIP_DNS_CHECK=1          跳过 DNS 预检(走 CDN/代理时用,一般别用)
#
#  脚本可安全重复运行:已完成的部署只做重启;半途失败的部署会自动续装
#  (密钥自动复用,不会因重跑而错乱)。
# =====================================================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/matrix}"
MARKER="由 matrix-installer.sh 生成"

bold() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$1"; }
die()  { printf '\033[1;31m[✗] %s\033[0m\n' "$1"; exit 1; }

# 交互辅助: 能真正打开 /dev/tty 才算有终端(curl|bash 时 stdin 是管道,
# 但 SSH 会话的 /dev/tty 仍连着键盘;纯自动化/cron 则两者都没有)
has_tty() { [ -t 0 ] || { [ -e /dev/tty ] && (exec </dev/tty) 2>/dev/null; }; }
press_enter() {
  if [ -t 0 ]; then read -rp "$1" REPLY || true
  elif [ -e /dev/tty ]; then read -rp "$1" REPLY < /dev/tty 2>/dev/null || true
  fi
}

# 非 root 时自动提权(有脚本文件用 sudo 重跑;curl|bash 无文件则提示)
if [ "$(id -u)" -ne 0 ]; then
  if [ -f "${0:-}" ] && command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  fi
fi
command -v apt-get >/dev/null 2>&1 \
  || die "本脚本仅支持 Ubuntu / Debian 系统。买服务器时请选 Ubuntu 22.04 或 24.04 镜像"

# ---------------------------------------------------------------------
# 子命令: adduser —— 交互式添加成员
# ---------------------------------------------------------------------
if [ "${1:-}" = "adduser" ]; then
  [ -t 0 ] || die "adduser 需要交互终端,请直接在 SSH 里执行: bash matrix-installer.sh adduser"
  cd "$INSTALL_DIR" 2>/dev/null || die "找不到 $INSTALL_DIR,先完成部署"
  docker compose ps --status running -q synapse 2>/dev/null | grep -q . \
    || die "Synapse 未运行。先执行: cd $INSTALL_DIR && docker compose up -d"
  echo "提示: 问到 'Make admin' 时,普通成员直接回车;要管理员权限则输入 yes"
  exec docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml http://localhost:8008
fi

# ---------------------------------------------------------------------
# 0. 参数与基础环境
# ---------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "需要 root 权限。请用: sudo bash matrix-installer.sh 域名  (网站管道方式: curl -fsSL 网址 | sudo bash -s -- 域名)"

# 已完成的部署直接快速重启,不再走向导(重跑体验更顺)
if [ -f "$INSTALL_DIR/CREDENTIALS.txt" ] \
   && grep -q "$MARKER" "$INSTALL_DIR/data/synapse/homeserver.yaml" 2>/dev/null; then
  cd "$INSTALL_DIR"
  warn "检测到已完成的部署($INSTALL_DIR),只做重启,不改任何配置/密钥。"
  docker compose up -d
  RUNNING="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$RUNNING" -ge 5 ]; then
    echo "✓ 5 个服务全部运行中。账号信息见 $INSTALL_DIR/CREDENTIALS.txt"
  else
    warn "只有 $RUNNING/5 个服务在运行,排查:"
    echo "  cd $INSTALL_DIR && docker compose ps"
    echo "  cd $INSTALL_DIR && docker compose logs --tail 50"
  fi
  exit 0
fi

# ---- 域名获取与校验(向导式:填错不退出,重新问,直到填对) ----
normalize_domain() {
  echo "$1" | tr 'A-Z' 'a-z' | sed 's|^https\?://||; s|/.*$||' | tr -d '[:space:]'
}
domain_ok() {
  # 只接受真实域名格式(字母数字点横线);中文、占位符、示例域名统统拦下
  echo "$1" | grep -Eq '^[a-z0-9.-]+\.[a-z]{2,}$' || return 1
  case "$1" in
    example.com|example.org|example.net|yourdomain.*|mydomain.*|domain.com) return 1 ;;
  esac
  return 0
}

DOMAIN="$(normalize_domain "${1:-}")"
until domain_ok "$DOMAIN"; do
  [ -n "$DOMAIN" ] && warn "『$DOMAIN』不是可用的域名。需要一个你已经购买的真实域名(在 阿里云/腾讯云/Namecheap 等处几十元/年)。"
  if [ -t 0 ]; then
    read -rp "请输入你的域名(直接输入,例如 mychat.org): " DOMAIN || die "已取消"
  elif [ -e /dev/tty ]; then
    read -rp "请输入你的域名(直接输入,例如 mychat.org): " DOMAIN < /dev/tty 2>/dev/null \
      || die "读取输入失败。请带域名参数运行: sudo bash matrix-installer.sh 域名"
  else
    die "没有交互终端。请带域名参数运行: sudo bash matrix-installer.sh 域名 (例: sudo bash matrix-installer.sh mychat.org)"
  fi
  DOMAIN="$(normalize_domain "$DOMAIN")"
done

ACME_EMAIL="${ACME_EMAIL:-admin@$DOMAIN}"
M_HOST="matrix.$DOMAIN"
LK_HOST="livekit.$DOMAIN"
RTC_HOST="matrix-rtc.$DOMAIN"

apt-get update -qq >/dev/null 2>&1 || true
command -v curl >/dev/null 2>&1 || apt-get install -y -qq curl || die "curl 安装失败,请手动 apt-get update 后重试"
command -v openssl >/dev/null 2>&1 || apt-get install -y -qq openssl || die "openssl 安装失败,请手动 apt-get update 后重试"

PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null \
          || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
[ -n "$PUBLIC_IP" ] || warn "探测不到公网 IP(不影响安装,LiveKit 会自行探测)"

bold "目标: $DOMAIN  →  服务器 ${PUBLIC_IP:-未知}  →  目录 $INSTALL_DIR"

# ---------------------------------------------------------------------
# 向导: 开工前把必须手动做的两件事讲清楚
# ---------------------------------------------------------------------
if has_tty; then
  cat <<EOF

┌──────────────────────────────────────────────────────────┐
│  Matrix 一键安装向导                                     │
└──────────────────────────────────────────────────────────┘
接下来全自动完成(约 5-10 分钟):装 Docker → 起 5 个服务 →
自动申请 HTTPS 证书 → 生成全部密码 → 创建管理员 → 给你登录信息。

只有两件事必须你在【网页后台】手动做(脚本替代不了):

 ① 域名商后台 → 添加 4 条 A 记录,全部指向 ${PUBLIC_IP:-本服务器IP}:
      $DOMAIN
      $M_HOST
      $LK_HOST
      $RTC_HOST

 ② 服务器商控制台 → 安全组/防火墙 放行这些端口:
      80/tcp   443/tcp   443/udp   7881/tcp   7882/udp
    (后台里找不到"安全组"设置的服务商,跳过这条即可)

EOF
  press_enter "①② 都做好了就按回车开始…(还没做?按 Ctrl+C 退出,做完再跑) "
fi

# ---------------------------------------------------------------------
# 1. DNS 预检(防止证书申请白白撞 Let's Encrypt 限流)
#    没生效不再直接退出,而是每 60 秒自动重测,等你改好为止
# ---------------------------------------------------------------------
dns_check() {  # 返回 0=全部正确
  local bad=0 h R4
  for h in "$DOMAIN" "$M_HOST" "$LK_HOST" "$RTC_HOST"; do
    # 收集全部 IPv4(排除环回),避免 AAAA/多记录误判
    R4="$(getent ahosts "$h" 2>/dev/null | awk '{print $1}' \
          | grep -E '^[0-9]+\.' | grep -Ev '^127\.' | sort -u || true)"
    if [ -z "$R4" ]; then
      warn "$h → 还没有解析记录"
      bad=1
    elif [ -n "$PUBLIC_IP" ] && ! echo "$R4" | grep -qx "$PUBLIC_IP"; then
      warn "$h → $(echo "$R4" | tr '\n' ' ')(没指向本机 $PUBLIC_IP)"
      bad=1
    else
      echo "  ✓ $h → $(echo "$R4" | head -1)"
    fi
  done
  return $bad
}

if [ "${SKIP_DNS_CHECK:-0}" != "1" ]; then
  bold "1/9 检查 DNS 解析"
  ATTEMPT=0
  until dns_check; do
    ATTEMPT=$((ATTEMPT + 1))
    if ! has_tty; then
      echo "DNS 未就绪。请把上面标 [!] 的记录在域名商后台改对,再重跑本脚本。"
      echo "(确认走了 CDN/代理可用: SKIP_DNS_CHECK=1 bash matrix-installer.sh $DOMAIN)"
      exit 1
    fi
    [ "$ATTEMPT" -ge 40 ] && die "等待约 40 分钟仍未生效,请检查记录是否填对(类型 A、主机名、IP),改好后重跑"
    warn "DNS 还没生效(添加记录后一般 1-10 分钟)。60 秒后自动重新检测…(Ctrl+C 退出)"
    sleep 60
  done
  echo "✓ DNS 全部就绪"
else
  warn "已跳过 DNS 预检"
fi

# ---------------------------------------------------------------------
# 2. Docker
# ---------------------------------------------------------------------
bold "2/9 安装 Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
else
  echo "Docker 已安装,跳过。"
fi
docker compose version >/dev/null 2>&1 \
  || apt-get install -y -qq docker-compose-plugin \
  || die "docker compose v2 不可用"

# ---------------------------------------------------------------------
# 3. 内存档位与 Swap(swap 失败不影响安装)
# ---------------------------------------------------------------------
bold "3/9 内存与 Swap"
RAM_MB="$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo)"
if [ "${RAM_MB:-0}" -lt 4000 ] && [ -z "$(swapon --show --noheadings 2>/dev/null)" ]; then
  if { fallocate -l 3G /swapfile 2>/dev/null \
       || dd if=/dev/zero of=/swapfile bs=1M count=3072 status=none 2>/dev/null; } \
     && chmod 600 /swapfile 2>/dev/null && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    echo 'vm.swappiness=10' > /etc/sysctl.d/99-matrix-swap.conf
    echo "内存 ${RAM_MB}MB,已加 3G swap。"
  else
    rm -f /swapfile
    warn "无法启用 swap(容器型 VPS 或文件系统不支持),跳过,继续安装。"
  fi
else
  echo "内存 ${RAM_MB:-?}MB,swap 状态 OK,跳过。"
fi
if [ "${RAM_MB:-0}" -ge 7500 ]; then
  SYNAPSE_MEM=3g; POSTGRES_MEM=1500m; LIVEKIT_MEM=512m; CACHE_FACTOR=1.0; EVENT_CACHE=10K
elif [ "${RAM_MB:-0}" -ge 3500 ]; then
  SYNAPSE_MEM=2g; POSTGRES_MEM=1g;    LIVEKIT_MEM=384m; CACHE_FACTOR=1.0; EVENT_CACHE=10K
else
  SYNAPSE_MEM=1g; POSTGRES_MEM=512m;  LIVEKIT_MEM=256m; CACHE_FACTOR=0.5; EVENT_CACHE=5K
fi

# ---------------------------------------------------------------------
# 4. 防火墙(失败只警告;放行真实 SSH 端口,防锁死)
# ---------------------------------------------------------------------
bold "4/9 防火墙 (ufw)"
SSH_PORT="$(ss -tlnpH 2>/dev/null | awk '/sshd/{sub(/.*:/,"",$4); print $4; exit}' || true)"
SSH_PORT="${SSH_PORT:-22}"
if command -v ufw >/dev/null 2>&1 || apt-get install -y -qq ufw >/dev/null 2>&1; then
  if ufw allow "${SSH_PORT}/tcp" >/dev/null 2>&1; then
    ufw allow 80/tcp >/dev/null;   ufw allow 443/tcp >/dev/null
    ufw allow 443/udp >/dev/null;  ufw allow 7881/tcp >/dev/null
    ufw allow 7882/udp >/dev/null
    ufw --force enable >/dev/null
    echo "已放行 SSH(${SSH_PORT})/80/443(tcp+udp)/7881(tcp)/7882(udp)。"
  else
    warn "ufw 在当前环境不可用(容器/内核限制),请自行放行端口。"
  fi
else
  warn "ufw 不可用,请自行放行端口。"
fi
warn "云服务商控制台的『安全组』也要放行: 80,443(tcp+udp),7881/tcp,7882/udp —— 漏开 7882/udp = 通话无声音画面!"

# ---------------------------------------------------------------------
# 5. 安装目录与部署状态检测(幂等/断点续装)
# ---------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR" && INSTALL_DIR="$PWD"

# 把脚本自身留一份在安装目录,以后 adduser/重装直接在这里执行。
# curl|bash 管道模式下没有文件实体,则用 MATRIX_INSTALLER_URL(建站时可设)回源下载。
SELF_DST="$INSTALL_DIR/matrix-installer.sh"
if [ -f "${0:-}" ] && [ "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" != "$SELF_DST" ]; then
  cp -f "$0" "$SELF_DST" 2>/dev/null || true
elif [ ! -f "$SELF_DST" ] && [ -n "${MATRIX_INSTALLER_URL:-}" ]; then
  curl -fsSL "$MATRIX_INSTALLER_URL" -o "$SELF_DST" 2>/dev/null || true
fi
[ -f "$SELF_DST" ] && HAVE_LOCAL_SCRIPT=1 || HAVE_LOCAL_SCRIPT=0

OUR_CFG=0
if [ -f data/synapse/homeserver.yaml ] && grep -q "$MARKER" data/synapse/homeserver.yaml 2>/dev/null; then
  OUR_CFG=1
fi

if [ "$OUR_CFG" -eq 1 ] && [ -f CREDENTIALS.txt ]; then
  warn "检测到已完成的部署,只做重启,不改任何配置/密钥。"
  docker compose up -d
  RUNNING="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$RUNNING" -ge 5 ]; then
    echo "✓ 5 个服务全部运行中。账号信息见 $INSTALL_DIR/CREDENTIALS.txt"
  else
    warn "只有 $RUNNING/5 个服务在运行,排查:"
    echo "  cd $INSTALL_DIR && docker compose ps"
    echo "  cd $INSTALL_DIR && docker compose logs --tail 50"
  fi
  exit 0
fi
[ "$OUR_CFG" -eq 1 ] && warn "检测到未完成的部署,自动续装(复用已有密钥)。"

# 80/443 占用预检(仅当占用者不是我们自己的 caddy)
if ! docker compose ps -q caddy 2>/dev/null | grep -q .; then
  if ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Eq ':(80|443)$'; then
    die "80/443 端口已被其他程序占用(nginx/apache?)。先停掉它: systemctl stop nginx apache2 2>/dev/null; systemctl disable nginx apache2 2>/dev/null,再重跑本脚本"
  fi
fi

# ---------------------------------------------------------------------
# 6. 机密(已有 .env 则复用,防止重跑后密码错乱)与配置文件
# ---------------------------------------------------------------------
bold "5/9 生成密钥与配置"
env_get() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- || true; }
PG_PASS="$(env_get POSTGRES_PASSWORD)";   [ -n "$PG_PASS" ]   || PG_PASS="$(openssl rand -hex 24)"
LK_KEY="$(env_get LIVEKIT_API_KEY)";      [ -n "$LK_KEY" ]    || LK_KEY="API$(openssl rand -hex 6)"
LK_SECRET="$(env_get LIVEKIT_API_SECRET)"; [ -n "$LK_SECRET" ] || LK_SECRET="$(openssl rand -hex 32)"
REG_SECRET="$(env_get REG_SECRET)";       [ -n "$REG_SECRET" ] || REG_SECRET="$(openssl rand -hex 32)"
MACAROON="$(env_get MACAROON)";           [ -n "$MACAROON" ]   || MACAROON="$(openssl rand -hex 32)"
FORM_SECRET="$(env_get FORM_SECRET)";     [ -n "$FORM_SECRET" ] || FORM_SECRET="$(openssl rand -hex 32)"

cat > .env <<EOF
# ===== Matrix 一键部署机密文件(勿泄露,勿删除) $(date +%F) =====
MATRIX_DOMAIN=$DOMAIN
POSTGRES_PASSWORD=$PG_PASS
LIVEKIT_API_KEY=$LK_KEY
LIVEKIT_API_SECRET=$LK_SECRET
REG_SECRET=$REG_SECRET
MACAROON=$MACAROON
FORM_SECRET=$FORM_SECRET
SYNAPSE_MEM=$SYNAPSE_MEM
POSTGRES_MEM=$POSTGRES_MEM
LIVEKIT_MEM=$LIVEKIT_MEM
EOF
chmod 600 .env

# ---- docker-compose.yml(通用模板,实例参数全走 .env) ----
cat > docker-compose.yml <<'EOF'
name: matrix

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: synapse
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: synapse
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U synapse"]
      interval: 10s
      timeout: 5s
      retries: 5
    mem_limit: ${POSTGRES_MEM}
    networks: [internal]

  synapse:
    image: matrixdotorg/synapse:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    volumes:
      - ./data/synapse:/data
    mem_limit: ${SYNAPSE_MEM}
    networks: [internal]

  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    restart: unless-stopped
    environment:
      LIVEKIT_URL: "wss://livekit.${MATRIX_DOMAIN}"
      LIVEKIT_KEY: ${LIVEKIT_API_KEY}
      LIVEKIT_SECRET: ${LIVEKIT_API_SECRET}
      LIVEKIT_FULL_ACCESS_HOMESERVERS: ${MATRIX_DOMAIN}
      LIVEKIT_JWT_BIND: ":8080"
    # 关键: 云上公网 IP 常是 NAT,容器访问不了"自己的公网域名"。
    # 把这两个域名指到宿主机网关,保证 OpenID 身份校验回环可达。
    extra_hosts:
      - "${MATRIX_DOMAIN}:host-gateway"
      - "matrix.${MATRIX_DOMAIN}:host-gateway"
    mem_limit: 64m
    networks: [internal]

  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    command: ["--config", "/etc/livekit.yaml"]
    volumes:
      - ./livekit/livekit.yaml:/etc/livekit.yaml:ro
    ports:
      - "7881:7881/tcp"
      - "7882:7882/udp"
    mem_limit: ${LIVEKIT_MEM}
    networks: [internal]

  caddy:
    image: caddy:2
    restart: unless-stopped
    depends_on: [synapse, livekit, lk-jwt-service]
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data/caddy/data:/data
      - ./data/caddy/config:/config
    mem_limit: 128m
    networks: [internal]

networks:
  internal:
    driver: bridge
EOF

# ---- Caddyfile ----
cat > Caddyfile <<EOF
{
	email $ACME_EMAIL
}

# server_name 域: well-known 服务发现(委派 + 通话后端),必须 JSON + CORS
$DOMAIN {
	handle /.well-known/matrix/server {
		header Content-Type application/json
		header Access-Control-Allow-Origin *
		respond \`{"m.server":"$M_HOST:443"}\` 200
	}
	handle /.well-known/matrix/client {
		header Content-Type application/json
		header Access-Control-Allow-Origin *
		respond \`{"m.homeserver":{"base_url":"https://$M_HOST"},"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://$RTC_HOST"}]}\` 200
	}
	handle {
		respond "$DOMAIN — Matrix server" 200
	}
}

$M_HOST {
	reverse_proxy synapse:8008
}

$LK_HOST {
	reverse_proxy livekit:7880
}

$RTC_HOST {
	reverse_proxy lk-jwt-service:8080
}
EOF

# ---- livekit.yaml(webhook 走容器内网,不绕公网) ----
mkdir -p livekit
cat > livekit/livekit.yaml <<EOF
port: 7880
bind_addresses:
  - "0.0.0.0"
log_level: info
rtc:
  tcp_port: 7881
  udp_port: 7882
  use_external_ip: true
room:
  auto_create: false
keys:
  $LK_KEY: $LK_SECRET
webhook:
  api_key: $LK_KEY
  urls:
    - http://lk-jwt-service:8080/sfu_webhook
turn:
  enabled: false
EOF

docker compose config -q || die "生成的 compose 配置校验失败"

# ---------------------------------------------------------------------
# 7. Synapse 配置
# ---------------------------------------------------------------------
bold "6/9 生成 Synapse 配置"
mkdir -p data/synapse
if [ ! -f "data/synapse/$DOMAIN.signing.key" ]; then
  docker run --rm \
    -v "$INSTALL_DIR/data/synapse:/data" \
    -e SYNAPSE_SERVER_NAME="$DOMAIN" \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate >/dev/null
fi

cat > data/synapse/homeserver.yaml <<EOF
# ===== $MARKER($(date +%F))=====
server_name: "$DOMAIN"
pid_file: /data/homeserver.pid
public_baseurl: "https://$M_HOST/"
report_stats: false

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]   # federation 含 openid,通话授权依赖,勿删
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: "$PG_PASS"
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

log_config: "/data/$DOMAIN.log.config"
media_store_path: /data/media_store
max_upload_size: "100M"

registration_shared_secret: "$REG_SECRET"
macaroon_secret_key: "$MACAROON"
form_secret: "$FORM_SECRET"
signing_key_path: "/data/$DOMAIN.signing.key"

trusted_key_servers:
  - server_name: "matrix.org"
suppress_key_server_warning: true

caches:
  global_factor: $CACHE_FACTOR
  event_cache_size: "$EVENT_CACHE"

# ---- Element Call / MatrixRTC 群组通话必需 ----
experimental_features:
  msc3266_enabled: true
  msc4222_enabled: true
max_event_delay_duration: 24h
rc_message:
  per_second: 0.5
  burst_count: 30
rc_delayed_event_mgmt:
  per_second: 1.0
  burst_count: 20

# ---- 私有团队安全默认 ----
enable_registration: false
allow_public_rooms_over_federation: false
EOF

chown -R 991:991 data/synapse

# ---------------------------------------------------------------------
# 8. 启动 + 证书验收
# ---------------------------------------------------------------------
bold "7/9 启动所有服务(首次拉镜像需几分钟)"
docker compose pull -q || true
docker compose up -d

bold "8/9 等待服务就绪"
READY=0
for i in $(seq 1 60); do
  if docker compose exec -T synapse python3 -c \
      "import urllib.request; urllib.request.urlopen('http://localhost:8008/_matrix/client/versions')" \
      >/dev/null 2>&1; then
    READY=1; echo "✓ Synapse 已就绪。"; break
  fi
  sleep 3
done
[ "$READY" -eq 1 ] || warn "Synapse 启动较慢: cd $INSTALL_DIR && docker compose logs --tail 50 synapse"

CERT_OK=0
echo "等待 HTTPS 证书签发(首次约 10-60 秒)…"
for i in $(seq 1 36); do
  if curl -4 -fsS --max-time 5 "https://$M_HOST/_matrix/client/versions" >/dev/null 2>&1; then
    CERT_OK=1; echo "✓ HTTPS 已生效: https://$M_HOST"; break
  fi
  sleep 5
done
if [ "$CERT_OK" -ne 1 ]; then
  warn "HTTPS 还没就绪。常见原因: 云安全组没放行 80/443,或 DNS 还没全球生效。"
  warn "Caddy 会自动重试签发,【无需重装、无需重跑脚本】,修好网络后等几分钟即可。"
  echo "查看证书日志: cd $INSTALL_DIR && docker compose logs caddy | grep -iE 'error|obtain|rate' | tail -20"
fi

# ---------------------------------------------------------------------
# 9. 管理员账号(成功才写 CREDENTIALS.txt,作为“部署完成”的标志)
# ---------------------------------------------------------------------
bold "9/9 创建管理员"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
ADMIN_OK=0
if [ "$READY" -eq 1 ]; then
  if docker compose exec -T synapse register_new_matrix_user \
       -c /data/homeserver.yaml -u "$ADMIN_USER" -p "$ADMIN_PASS" -a \
       http://localhost:8008 >/dev/null 2>>install-error.log; then
    ADMIN_OK=1
  fi
fi

if [ "$ADMIN_OK" -eq 1 ]; then
  cat > CREDENTIALS.txt <<EOF
==== Matrix 部署凭据  $DOMAIN  $(date '+%F %T') ====
安装目录:      $INSTALL_DIR
管理员账号:    $ADMIN_USER   (完整ID: @$ADMIN_USER:$DOMAIN)
管理员密码:    $ADMIN_PASS
客户端登录:    Element X 里服务器填 $DOMAIN
数据库密码 / LiveKit 密钥: 见同目录 .env
★ 必须备份: data/synapse/$DOMAIN.signing.key + homeserver.yaml + .env + 数据库 + media_store
EOF
  chmod 600 CREDENTIALS.txt
fi

# ---------------------------------------------------------------------
# 收尾报告(按真实结果分支,不虚报完成)
# ---------------------------------------------------------------------
# 加成员的提示:有本地脚本用 adduser 子命令,否则给等效的原始命令
if [ "${HAVE_LOCAL_SCRIPT:-0}" -eq 1 ]; then
  ADDUSER_HINT="cd $INSTALL_DIR && sudo bash matrix-installer.sh adduser"
else
  ADDUSER_HINT="cd $INSTALL_DIR && docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"
fi

if [ "$ADMIN_OK" -eq 1 ] && [ "$CERT_OK" -eq 1 ]; then
  cat <<EOF

========================================================
 🎉 部署完成!  $DOMAIN

 手机装 Element X,登录:
   服务器:  $DOMAIN
   账号:    $ADMIN_USER
   密码:    $ADMIN_PASS
 (凭据已存 $INSTALL_DIR/CREDENTIALS.txt)

 添加团队成员:
   $ADDUSER_HINT
 (或网页后台 https://admin.etke.cc,Homeserver 填 https://$M_HOST)

 自检:
   curl -s https://$DOMAIN/.well-known/matrix/client
   curl -s https://$RTC_HOST/healthz -o /dev/null -w '%{http_code}\n'
   cd $INSTALL_DIR && docker compose ps    # 5 个容器都应 running
   浏览器: https://federationtester.matrix.org/#$DOMAIN

 ⚠️ 云安全组记得放行: 80,443(tcp+udp),7881/tcp,7882/udp
========================================================
EOF
else
  cat <<EOF

========================================================
 ⚠️  部署基本就绪,但还有事项未完成:
EOF
  [ "$CERT_OK" -ne 1 ] && cat <<EOF
   • HTTPS 证书未生效 → 检查云安全组 80/443 与 DNS,之后 Caddy 自动重试,
     无需重装。看日志: cd $INSTALL_DIR && docker compose logs caddy | tail -30
EOF
  [ "$ADMIN_OK" -ne 1 ] && cat <<EOF
   • 管理员账号还没建 → 服务正常后执行:
       $ADDUSER_HINT
     (用户名填 admin,问到 'Make admin' 时输入 yes)
     报错记录: $INSTALL_DIR/install-error.log
EOF
  cat <<EOF

 修复后【重新运行本脚本】会自动续装,不会弄乱已有配置。
========================================================
EOF
fi
