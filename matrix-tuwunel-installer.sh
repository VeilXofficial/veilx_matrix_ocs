#!/usr/bin/env bash
# =====================================================================
#  Matrix 轻量一键安装脚本 · tuwunel 版(通用版 t1.2)
#  t1.2: 装完注册全局命令 `sudo tuwunel`(开菜单/加人不用记路径、不用带域名);
#        支持 GitHub 一条命令安装(bash <(curl ...));命令行不带域名时向导交互询问。
#  t1.1: 装完【自动建好管理员并打印账号密码】;adduser 一条命令建号并设密码
#        (走 Matrix 注册接口+令牌,不碰 --execute/DB 锁)—— CLI 便利已与 Synapse 版持平。
#
#  为什么是 tuwunel(不是 Synapse / Dendrite):
#    · Rust 单二进制、内置 RocksDB —— 【免装 PostgreSQL】,内存 ~64–256MB
#      量级(Synapse 是 1–4GB),真·省资源,中型公司也扛得住 500 人。
#    · conduwuit 的官方继任者,由全职团队维护,已被瑞士政府用于面向公民的
#      生产部署;单进程无需 worker。
#    · 【发大文件/大图/长视频】:max_request_size 用字节整数,可设到几 GB。
#      (注:Matrix 协议无分片续传,做不到"完全像 Telegram";E2EE 房大文件
#       需客户端整体加密,超大文件较吃客户端内存 —— 这是协议限制,非本脚本。)
#    · 原生支持 Element Call(通话,可选,默认关)。
#  代价(务必知晓):tuwunel 较年轻,【没有 Synapse 那种成熟网页后台(Ketesa)】。
#    本脚本已把建管理员/加成员做成一条命令(CLI 便利与 Synapse 版持平),但"零终端
#    网页点鼠标管理"这一项 tuwunel 生态给不了成熟货 —— 要 Ketesa 那种后台请用 Synapse 版。
#
#  组件: Caddy(自动HTTPS) + tuwunel  (+ 可选 LiveKit + lk-jwt-service 通话)
#  客户端: Element X / Element Web / 任意 Matrix 客户端
#
#  用法:
#   ▶ 一条命令安装(GitHub 托管,把 URL 换成你仓库的原始地址):
#      bash <(curl -fsSL https://raw.githubusercontent.com/你/仓库/main/tuwunel-installer.sh)
#     (以 root 或前面加 sudo;向导会【交互询问域名】,命令行不用带域名)
#   ▶ 或先下载再跑:
#      curl -fsSL <上面URL> -o tuwunel-installer.sh && sudo bash tuwunel-installer.sh
#   ▶ 直接带域名(懒得等向导): sudo bash tuwunel-installer.sh mychat.org
#
#   装完后会注册一个全局命令,以后就这么用(不用记路径、不用再带域名):
#      sudo tuwunel            # 打开中文管理菜单
#      sudo tuwunel adduser    # 加成员(一条命令建号并设密码)
#      sudo tuwunel config     # 改配置    sudo tuwunel uninstall  # 卸载
#   (curl|bash 管道模式想让菜单/adduser 可用,设 TUWUNEL_INSTALLER_URL=<上面URL> 让它自取副本)
#
#  前提: DNS A 记录已指向本服务器公网 IP:
#    你的域名.com   matrix.你的域名.com   (开通话再加 livekit.  matrix-rtc.)
#
#  可选环境变量:
#    INSTALL_DIR=/opt/tuwunel   安装目录(默认)
#    ACME_EMAIL=you@x.com       证书通知邮箱(默认 admin@域名)
#    SKIP_DNS_CHECK=1           跳过 DNS 预检
#    REG_MODE=token|open        注册方式(默认 token=需令牌)
#    ENABLE_FEDERATION=1|0      联邦(默认 0=关闭,纯私密孤岛)
#    ENABLE_CALLS=1|0           语音视频通话(默认 0=关闭)
#    MAX_UPLOAD=4G              单文件上限(默认 4G;支持 K/M/G,内部转字节)
#
#  ★ server_name(你的域名)一旦部署【不可更改】,改了必须清库重来 —— tuwunel 硬限制。
#  脚本可安全重复运行:已完成的部署只做重启;半途失败会自动续装。
#  Required Notice: Copyright (c) 2026 VeilXofficial
# =====================================================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
MARKER="由 tuwunel-installer.sh 生成"
TUWUNEL_IMAGE="ghcr.io/matrix-construct/tuwunel:latest"

# ---- 终端配色(仅真终端启用;重定向/NO_COLOR 时自动关闭)----
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  E=$'\033'
  C_RESET="${E}[0m"; C_B="${E}[1m"; C_DIM="${E}[2m"
  C_CYAN="${E}[1;36m"; C_GREEN="${E}[1;32m"; C_YELLOW="${E}[1;33m"
  C_RED="${E}[1;31m";  C_BLUE="${E}[1;34m"
else
  C_RESET=""; C_B=""; C_DIM=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""
fi
bold() { printf '\n%s==> %s%s\n' "$C_B$C_CYAN" "$1" "$C_RESET"; }
warn() { printf '%s[!] %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
die()  { printf '%s[✗] %s%s\n' "$C_RED" "$1" "$C_RESET"; exit 1; }
ok()   { printf '%s✓ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }

has_tty() { [ -t 0 ] || { [ -e /dev/tty ] && (exec </dev/tty) 2>/dev/null; }; }
env_saved() { grep -E "^$1=" "$INSTALL_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2- || true; }
press_enter() {
  if [ -t 0 ]; then read -rp "$1" REPLY || true
  elif [ -e /dev/tty ]; then read -rp "$1" REPLY < /dev/tty 2>/dev/null || true
  fi
}
ask_opt() { REPLY=""
  if [ -t 0 ]; then read -rp "$1" REPLY || true
  elif [ -e /dev/tty ]; then read -rp "$1" REPLY < /dev/tty 2>/dev/null || true; fi
  [ -n "$REPLY" ] || REPLY="$2"
}

# ---- 把 4G / 500M / 800MB 之类转成字节整数(tuwunel max_request_size 用字节)----
to_bytes() {
  local v; v="$(echo "$1" | tr 'a-z' 'A-Z' | tr -d '[:space:]')"; v="${v%B}"; v="${v%I}"  # 去掉尾部 B / iB 里的 B/I
  case "$v" in
    *G) echo $(( ${v%G} * 1024 * 1024 * 1024 )) ;;
    *M) echo $(( ${v%M} * 1024 * 1024 )) ;;
    *K) echo $(( ${v%K} * 1024 )) ;;
    ''|*[!0-9]*) echo 4294967296 ;;   # 非法 → 4 GiB
    *) echo "$v" ;;                    # 纯数字=字节
  esac
}
human() {  # 字节 → 人类可读
  local b="$1"
  if   [ "$b" -ge 1073741824 ]; then printf '%sG' "$(( b / 1073741824 ))"
  elif [ "$b" -ge 1048576 ];    then printf '%sM' "$(( b / 1048576 ))"
  else printf '%s字节' "$b"; fi
}

# ---- 通过 Matrix 注册接口 + 注册令牌建号(引擎无关,不用 --execute/不碰 DB 锁)----
# 用法: register_user <用户名> <密码> <homeserver_url> <注册令牌>
# 返回 0=成功;首个建成的账号因 grant_admin_to_first_user=true 自动成为管理员
register_user() {
  local u="$1" p="$2" hs="$3" tok="$4" r sess
  # UIAA 第一步:拿 session
  r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$u\",\"password\":\"$p\",\"inhibit_login\":true}" 2>/dev/null || true)"
  case "$r" in *'"user_id"'*) return 0 ;; esac   # 万一无需 UIAA 直接成功
  sess="$(printf '%s' "$r" | grep -o '"session"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "$sess" ] || return 1
  # 第二步:带注册令牌
  r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$u\",\"password\":\"$p\",\"inhibit_login\":true,\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$tok\",\"session\":\"$sess\"}}" 2>/dev/null || true)"
  case "$r" in
    *'"user_id"'*) return 0 ;;
    *'m.login.dummy'*)   # 部分实现在令牌后还要 dummy 阶段
      r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
            -H 'Content-Type: application/json' \
            -d "{\"username\":\"$u\",\"password\":\"$p\",\"inhibit_login\":true,\"auth\":{\"type\":\"m.login.dummy\",\"session\":\"$sess\"}}" 2>/dev/null || true)"
      case "$r" in *'"user_id"'*) return 0 ;; *) return 1 ;; esac ;;
    *) return 1 ;;
  esac
}
# 校验用户名(仅小写字母数字与 . _ - =),防注入
uname_ok(){ echo "$1" | grep -Eq '^[a-z0-9._=-]+$'; }

# ---- 磁盘守卫 / 清理(只回收 Docker 冗余,不删用户文件)----
menu_cleanup() {
  cd "$INSTALL_DIR"
  local before after
  echo ""; echo "── 磁盘 / 数据 用量 ──"
  printf '  安装目录合计: %s    磁盘剩余: %s\n' "$(du -sh . 2>/dev/null | cut -f1)" "$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  printf '  └ 数据库+媒体(RocksDB): %s\n' "$(du -sh data/tuwunel 2>/dev/null | cut -f1)"
  echo ""; echo "安全清理(仅回收 Docker 冗余镜像/缓存,不动你任何用户的文件)…"
  before="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  docker image prune -f >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
  after="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  if [ -n "$before" ] && [ -n "$after" ] && [ "$after" -gt "$before" ] 2>/dev/null; then
    ok "清理完成,释放约 $(( (after-before)/1024 )) MB(磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。"
  else ok "清理完成(暂无冗余,磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。"; fi
  echo ""
  warn "大文件放开后,聊天媒体会让 data/tuwunel 快速增长,注意磁盘余量。tuwunel 无 S3 卸载,媒体存本地盘。"
}
disk_guard() {
  cd "$INSTALL_DIR" 2>/dev/null || return 0
  local pct log; log="$INSTALL_DIR/diskguard.log"
  pct="$(df . 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')"; pct="${pct:-0}"
  [ "$pct" -ge 80 ] 2>/dev/null || return 0
  { echo "[$(date '+%F %T')] 磁盘已用 ${pct}% ≥ 80%,回收 Docker 冗余…"
    docker image prune -f 2>&1 | tail -n1
    df -h . | awk 'NR==2{print "  回收后:剩余 "$4",已用 "$5}'
  } >> "$log" 2>&1
  tail -n 200 "$log" > "$log.tmp" 2>/dev/null && mv -f "$log.tmp" "$log" 2>/dev/null || true
}

menu_status() {
  cd "$INSTALL_DIR"
  local d; d="$(env_saved MATRIX_DOMAIN)"
  echo ""; echo "── 当前配置 ──"
  echo "  域名: ${d:-未知}   注册: $(env_saved REG_MODE)   联邦: $([ "$(env_saved ENABLE_FEDERATION)" = "1" ] && echo 开 || echo 关)   通话: $([ "$(env_saved ENABLE_CALLS)" = "1" ] && echo 开 || echo 关)   大文件上限: $(human "$(env_saved MAX_UPLOAD_BYTES)")"
  echo "── 容器状态 ──"; docker compose ps 2>/dev/null || true
  echo "── 资源占用 ──"
  local pct; pct="$(df . 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')"; pct="${pct:-0}"
  printf '  数据(库+媒体): %s   磁盘剩余: %s   ' "$(du -sh data/tuwunel 2>/dev/null | cut -f1)" "$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  if [ "$pct" -ge 90 ] 2>/dev/null; then printf '%s磁盘已用 %s%%,偏高,菜单选 6 清理%s\n' "$C_RED" "$pct" "$C_RESET"
  else printf '%s磁盘已用 %s%%%s\n' "$C_GREEN" "$pct" "$C_RESET"; fi
  free -h 2>/dev/null | awk 'NR<=2{print "  "$0}' || true
  echo "── 在线检查 ──"
  if curl -4 -fsS --max-time 8 "https://matrix.${d}/_matrix/client/versions" >/dev/null 2>&1; then
    ok "https://matrix.${d} 正常(证书有效,服务在线)"
  else warn "matrix.${d} 暂不可访问 —— 排查: docker compose logs --tail 30"; fi
  echo "  凭据: $INSTALL_DIR/CREDENTIALS.txt"
}
menu_backup() {
  cd "$INSTALL_DIR"; local ts f; ts="$(date +%F-%H%M%S)"; f="$INSTALL_DIR/tuwunel-backup-$ts.tar.gz"
  umask 077
  echo "==> 停止服务以一致地备份 RocksDB(库不停止直接打包可能损坏)…"
  docker compose stop tuwunel >/dev/null 2>&1 || true
  echo "==> 打包 配置 + 数据库 + 媒体(媒体大时压缩包会很大)…"
  tar czf "$f" .env CREDENTIALS.txt tuwunel.toml data/tuwunel 2>/dev/null || true
  docker compose start tuwunel >/dev/null 2>&1 || docker compose up -d >/dev/null 2>&1 || true
  chmod 600 "$f" 2>/dev/null || true
  if [ -s "$f" ]; then ok "备份完成: $f($(du -h "$f" | cut -f1))"
    echo "  下载到本机: scp root@服务器IP:$f ~/Desktop/"
  else warn "备份失败"; fi
}

# 非 root 自动提权
if [ "$(id -u)" -ne 0 ]; then
  if [ -f "${0:-}" ] && command -v sudo >/dev/null 2>&1; then exec sudo -E bash "$0" "$@"; fi
fi
command -v apt-get >/dev/null 2>&1 || die "本脚本仅支持 Ubuntu / Debian。买服务器请选 Ubuntu 22.04/24.04"
SELF_SRC=""; [ -f "${0:-}" ] && SELF_SRC="$(cd "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"

# ---------------------------------------------------------------------
# 子命令
# ---------------------------------------------------------------------
if [ "${1:-}" = "diskguard" ]; then disk_guard; exit 0; fi
if [ "${1:-}" = "cleanup" ]; then [ -d "$INSTALL_DIR" ] || die "找不到 $INSTALL_DIR"; menu_cleanup; exit 0; fi

if [ "${1:-}" = "adduser" ]; then
  [ -d "$INSTALL_DIR" ] || die "找不到 $INSTALL_DIR,先完成部署"
  cd "$INSTALL_DIR"
  D="$(env_saved MATRIX_DOMAIN)"; TOK="$(env_saved REG_TOKEN)"; HS="https://matrix.$D"
  [ -n "$D" ] && [ -n "$TOK" ] || die "读不到域名/注册令牌,部署可能未完成"
  docker compose ps --status running -q tuwunel 2>/dev/null | grep -q . || die "tuwunel 未运行: cd $INSTALL_DIR && docker compose up -d"
  printf '\n%s== 添加团队成员(直接建好账号并设密码)==%s\n' "$C_B$C_CYAN" "$C_RESET"
  NU=""
  if [ -t 0 ]; then read -rp "新成员用户名(小写字母数字,如 lisi): " NU || exit 1
  elif [ -e /dev/tty ]; then read -rp "新成员用户名(小写字母数字,如 lisi): " NU < /dev/tty || exit 1
  else die "adduser 需交互终端: sudo bash tuwunel-installer.sh adduser"; fi
  NU="$(echo "$NU" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
  uname_ok "$NU" || die "用户名不合法(只允许小写字母数字与 . _ - =)"
  NP=""
  if [ -t 0 ]; then read -rp "密码(留空=自动生成强密码): " NP || true
  elif [ -e /dev/tty ]; then read -rp "密码(留空=自动生成强密码): " NP < /dev/tty || true; fi
  [ -n "$NP" ] || NP="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  echo "==> 正在创建 @$NU:$D …"
  if register_user "$NU" "$NP" "$HS" "$TOK"; then
    ok "成员已创建。"
    printf '   账号: %s%s%s   密码: %s%s%s\n' "$C_B" "$NU" "$C_RESET" "$C_B$C_GREEN" "$NP" "$C_RESET"
    echo "   让 TA 用 Element 登录:服务器填 $D,用上面账号密码。"
  else
    warn "创建失败。可能:该用户名已存在、令牌失效、或服务未就绪。"
    echo "   兜底方案:把 [服务器 $D + 注册令牌 $TOK] 发给成员自助注册;"
    echo "   或在管理员房间发 !admin help 查看命令。"
  fi
  exit 0
fi

if [ "${1:-}" = "uninstall" ]; then
  [ -t 0 ] || die "uninstall 必须在交互终端里执行(防误删)"
  [ -d "$INSTALL_DIR" ] || die "没找到 $INSTALL_DIR,无需卸载"
  INSTALL_DIR="$(readlink -f -- "$INSTALL_DIR" 2>/dev/null || echo "$INSTALL_DIR")"
  case "$INSTALL_DIR" in ""|/|/root|/home|/usr|/etc|/var|/bin|/boot|/lib*|/opt|/srv|/sys|/proc|/dev)
      die "拒绝删除危险路径 [$INSTALL_DIR]" ;; esac
  grep -q "$MARKER" "$INSTALL_DIR/tuwunel.toml" 2>/dev/null || die "[$INSTALL_DIR] 不像本脚本部署的目录,拒绝删除。"
  UN_DOMAIN="$(env_saved MATRIX_DOMAIN)"
  cat <<EOF

┌──────────────────────────────────────────────────────────┐
│  ⚠️  彻底卸载 tuwunel 服务器${UN_DOMAIN:+($UN_DOMAIN)}
└──────────────────────────────────────────────────────────┘
将永久删除(无法恢复!):全部聊天记录、媒体、账号、数据库、证书、配置($INSTALL_DIR)。
强烈建议先在管理菜单里"立即备份"。
EOF
  read -rp "第 1 次确认:输入 yes 继续: " R1 || exit 1
  [ "$R1" = "yes" ] || { echo "已取消。"; exit 0; }
  if [ -n "$UN_DOMAIN" ]; then read -rp "第 2 次确认:输入你的域名【$UN_DOMAIN】: " R2 || exit 1
    [ "$R2" = "$UN_DOMAIN" ] || { echo "不匹配,已取消。"; exit 0; }
  else read -rp "第 2 次确认:输入大写 DELETE: " R2 || exit 1
    [ "$R2" = "DELETE" ] || { echo "不匹配,已取消。"; exit 0; }; fi
  ( cd "$INSTALL_DIR" && docker compose down --remove-orphans ) 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  ok "卸载完成。$INSTALL_DIR 已删除。"; exit 0
fi

RECONFIG=0
if [ "${1:-}" = "config" ]; then RECONFIG=1; set --; fi

# ---------------------------------------------------------------------
# 0. 基础 / 已部署检测 → 管理菜单
# ---------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "需要 root: sudo bash tuwunel-installer.sh 域名"

if [ "$RECONFIG" -eq 0 ] && [ -f "$INSTALL_DIR/CREDENTIALS.txt" ] \
   && grep -q "$MARKER" "$INSTALL_DIR/tuwunel.toml" 2>/dev/null; then
  cd "$INSTALL_DIR"; SELF_BIN="$INSTALL_DIR/tuwunel-installer.sh"
  [ ! -f "$SELF_BIN" ] && [ -f "${0:-}" ] && cp -f "$0" "$SELF_BIN" 2>/dev/null || true
  if has_tty; then
    MENU_DOMAIN="$(env_saved MATRIX_DOMAIN)"
    while :; do
      cat <<EOF

┌──────────────────────────────────────────────┐
│  tuwunel 管理菜单   ${MENU_DOMAIN:-}
└──────────────────────────────────────────────┘
  1) 查看运行状态
  2) 添加团队成员(一条命令建号并设密码)
  3) 修改配置(注册 / 联邦 / 通话 / 大文件上限)
  4) 立即备份(配置 + 数据库 + 媒体)
  5) 升级到最新版本
  6) 清理磁盘
  7) 重启所有服务
  8) 彻底卸载
  0) 退出
EOF
      MCHOICE=""
      if [ -t 0 ]; then read -rp "请选择 [0-8]: " MCHOICE || exit 0
      else read -rp "请选择 [0-8]: " MCHOICE < /dev/tty 2>/dev/null || exit 0; fi
      case "$MCHOICE" in
        1) menu_status ;;
        2) [ -f "$SELF_BIN" ] && bash "$SELF_BIN" adduser || warn "缺少脚本副本" ;;
        3) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config || warn "缺少脚本副本" ;;
        4) menu_backup ;;
        5) echo "==> 拉取最新镜像并升级…"
           { docker compose pull -q && docker compose up -d --remove-orphans && ok "升级完成"; } || warn "升级失败: docker compose logs --tail 30" ;;
        6) menu_cleanup ;;
        7) { docker compose up -d && docker compose restart; } >/dev/null 2>&1 && ok "已重启" || warn "重启失败: docker compose ps" ;;
        8) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" uninstall || warn "缺少脚本副本"
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        0|q|Q) echo "再见。"; exit 0 ;;
        *) warn "无效选择,请输入 0-8" ;;
      esac
      press_enter "
按回车返回菜单… "
    done
  fi
  warn "检测到已完成的部署,只做重启。"; docker compose up -d; exit 0
fi

# ---- 域名 ----
normalize_domain(){ echo "$1" | tr 'A-Z' 'a-z' | sed 's|^https\?://||; s|/.*$||' | tr -d '[:space:]'; }
domain_ok(){ echo "$1" | grep -Eq '^[a-z0-9.-]+\.[a-z]{2,}$' || return 1
  case "$1" in example.com|example.org|yourdomain.*|mydomain.*|domain.com) return 1;; esac; return 0; }

DOMAIN="$(normalize_domain "${1:-}")"
if [ "$RECONFIG" -eq 1 ]; then
  DOMAIN="$(normalize_domain "$(env_saved MATRIX_DOMAIN)")"
  [ -n "$DOMAIN" ] || die "未找到已部署配置。config 只能在装好的服务器上用"
  echo "修改配置: $DOMAIN(域名不可改;数据/账号保持不变)"
fi
until domain_ok "$DOMAIN"; do
  [ -n "$DOMAIN" ] && warn "『$DOMAIN』不是可用域名(需你已购买的真实域名)。"
  if [ -t 0 ]; then read -rp "请输入你的域名(例 mychat.org): " DOMAIN || die "已取消"
  elif [ -e /dev/tty ]; then read -rp "请输入你的域名(例 mychat.org): " DOMAIN < /dev/tty 2>/dev/null || die "读取失败,请带域名参数运行"
  else die "无交互终端。请带域名参数: sudo bash tuwunel-installer.sh mychat.org"; fi
  DOMAIN="$(normalize_domain "$DOMAIN")"
done

ACME_EMAIL="${ACME_EMAIL:-admin@$DOMAIN}"
M_HOST="matrix.$DOMAIN"; LK_HOST="livekit.$DOMAIN"; RTC_HOST="matrix-rtc.$DOMAIN"
apt-get update -qq >/dev/null 2>&1 || true
command -v curl >/dev/null 2>&1 || apt-get install -y -qq curl || die "curl 安装失败"
command -v openssl >/dev/null 2>&1 || apt-get install -y -qq openssl || die "openssl 安装失败"
PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
bold "目标: $DOMAIN  →  服务器 ${PUBLIC_IP:-未知}  →  目录 $INSTALL_DIR  (引擎: tuwunel/Rust)"

# ---------------------------------------------------------------------
# 选项(回车=推荐默认;重跑沿用;环境变量可预设)
# ---------------------------------------------------------------------
EXPLICIT=0; [ -n "${REG_MODE:-}${ENABLE_FEDERATION:-}${ENABLE_CALLS:-}${MAX_UPLOAD:-}" ] && EXPLICIT=1
REG_MODE="${REG_MODE:-$(env_saved REG_MODE)}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-$(env_saved ENABLE_FEDERATION)}"
ENABLE_CALLS="${ENABLE_CALLS:-$(env_saved ENABLE_CALLS)}"
MAX_UPLOAD="${MAX_UPLOAD:-}"
SAVED_BYTES="$(env_saved MAX_UPLOAD_BYTES)"

DEF_REG=1; DEF_FED=N; DEF_CALL=n
if [ "$RECONFIG" -eq 1 ] && [ "$EXPLICIT" -eq 0 ]; then
  has_tty || die "config 需交互终端;或用环境变量: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config"
  case "$REG_MODE" in open) DEF_REG=2;; *) DEF_REG=1;; esac
  [ "$ENABLE_FEDERATION" = "1" ] && DEF_FED=y || DEF_FED=N
  [ "$ENABLE_CALLS" = "1" ] && DEF_CALL=Y || DEF_CALL=n
  echo ""; echo "当前: 注册[$REG_MODE] · 联邦[$([ "$ENABLE_FEDERATION" = "1" ] && echo 开 || echo 关)] · 通话[$([ "$ENABLE_CALLS" = "1" ] && echo 开 || echo 关)] · 大文件[$(human "${SAVED_BYTES:-4294967296}")]"
  echo "直接回车 = 保持当前值。"
  REG_MODE=""; ENABLE_FEDERATION=""; ENABLE_CALLS=""
fi

if has_tty && { [ -z "$REG_MODE" ] || [ -z "$ENABLE_FEDERATION" ] || [ -z "$ENABLE_CALLS" ]; }; then
  printf '\n%s安装选项:看不懂就直接回车用推荐值(已是私密最安全组合)。%s\n' "$C_B$C_CYAN" "$C_RESET"

  if [ -z "$REG_MODE" ]; then
    printf '\n%s【选项 1/4】谁能注册账号%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [1] 需注册令牌(推荐)—— 只有拿到你发的令牌的人才能注册;首个注册者=管理员。
  [2] 完全开放 —— 任何人都能注册(风险极高,商用勿选)。
EOF
    ask_opt "→ [1/2,回车=$DEF_REG]: " "$DEF_REG"
    case "$REPLY" in 2) REG_MODE=open; warn "已选开放注册,风险自负!";; *) REG_MODE=token;; esac
  fi

  if [ -z "$ENABLE_FEDERATION" ]; then
    printf '\n%s【选项 2/4】联邦互通(与外部 Matrix 世界相连)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [N] 关闭(推荐)—— 孤岛,外人无法向你的成员发消息,攻击面最小,商密首选。
  [y] 开启 —— 可与 matrix.org 等互通,暴露面变大。
EOF
    ask_opt "→ [y/N,回车=$DEF_FED]: " "$DEF_FED"
    case "$REPLY" in y|Y) ENABLE_FEDERATION=1;; *) ENABLE_FEDERATION=0;; esac
  fi

  if [ -z "$ENABLE_CALLS" ]; then
    printf '\n%s【选项 3/4】语音/视频通话(Element Call)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [n] 关闭(推荐先关)—— tuwunel 原生支持,但通话链路较新;先跑稳聊天+大文件。
  [Y] 开启 —— 额外装 LiveKit + lk-jwt,需再加 livekit. / matrix-rtc. 两条 DNS 和 7881/7882 端口。
EOF
    ask_opt "→ [y/N,回车=$DEF_CALL]: " "$DEF_CALL"
    case "$REPLY" in y|Y) ENABLE_CALLS=1;; *) ENABLE_CALLS=0;; esac
  fi

  if [ -z "$MAX_UPLOAD" ]; then
    printf '\n%s【选项 4/4】单文件上限(发大文件/大图/长视频)%s\n' "$C_B$C_CYAN" "$C_RESET"
    echo "  设多大都行(如 4G / 10G);越大越占磁盘。回车=4G。"
    ask_opt "→ 单文件上限 [回车=$(human "${SAVED_BYTES:-4294967296}")]: " "${SAVED_BYTES:+$(human "$SAVED_BYTES")}"
    [ -z "$REPLY" ] && REPLY="4G"; MAX_UPLOAD="$REPLY"
  fi
fi
REG_MODE="${REG_MODE:-token}"; ENABLE_FEDERATION="${ENABLE_FEDERATION:-0}"; ENABLE_CALLS="${ENABLE_CALLS:-0}"
case "$ENABLE_FEDERATION" in 1) :;; *) ENABLE_FEDERATION=0;; esac
case "$ENABLE_CALLS" in 1) :;; *) ENABLE_CALLS=0;; esac
case "$REG_MODE" in token|open) :;; *) REG_MODE=token;; esac
if [ -n "$MAX_UPLOAD" ]; then MAX_UPLOAD_BYTES="$(to_bytes "$MAX_UPLOAD")"
elif [ -n "$SAVED_BYTES" ]; then MAX_UPLOAD_BYTES="$SAVED_BYTES"
else MAX_UPLOAD_BYTES=4294967296; fi

if [ "$ENABLE_CALLS" = "1" ]; then REQUIRED_HOSTS="$DOMAIN $M_HOST $LK_HOST $RTC_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp 7881/tcp 7882/udp"
else REQUIRED_HOSTS="$DOMAIN $M_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp"; fi
echo ""
printf '  %s✔ 配置: 注册[%s] · 联邦[%s] · 通话[%s] · 大文件上限[%s]%s\n' "$C_GREEN" \
  "$REG_MODE" "$([ "$ENABLE_FEDERATION" = 1 ] && echo 开 || echo 关)" "$([ "$ENABLE_CALLS" = 1 ] && echo 开 || echo 关)" "$(human "$MAX_UPLOAD_BYTES")" "$C_RESET"

# ---- 向导:必须手动做的事 ----
if has_tty && [ "$RECONFIG" -eq 0 ]; then
  DNS_LINES="      $DOMAIN
      $M_HOST"
  [ "$ENABLE_CALLS" = "1" ] && DNS_LINES="$DNS_LINES
      $LK_HOST
      $RTC_HOST"
  cat <<EOF

${C_CYAN}┌──────────────────────────────────────────────────────────┐
│  tuwunel 轻量一键安装 · Rust 省资源 · 为大文件与保密而生   │
└──────────────────────────────────────────────────────────┘${C_RESET}
两件事必须你在【网页后台】手动做:

 ${C_B}${C_YELLOW}① 域名商 → 加下列 A 记录,全部指向 ${PUBLIC_IP:-本服务器IP}:${C_RESET}
${C_GREEN}$DNS_LINES${C_RESET}

 ${C_B}${C_YELLOW}② 服务器商 → 安全组/防火墙 放行:${C_RESET}
      ${C_GREEN}$PORT_LINE${C_RESET}
EOF
  press_enter "①② 做好了按回车开始…(没做?Ctrl+C 退出) "
fi

# ---------------------------------------------------------------------
# 1. DNS 预检
# ---------------------------------------------------------------------
dns_check(){ local bad=0 h R4
  for h in $REQUIRED_HOSTS; do
    R4="$(getent ahosts "$h" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.' | grep -Ev '^127\.' | sort -u || true)"
    if [ -z "$R4" ]; then warn "$h → 无解析"; bad=1
    elif [ -n "$PUBLIC_IP" ] && ! echo "$R4" | grep -qx "$PUBLIC_IP"; then warn "$h → $(echo "$R4"|tr '\n' ' ')(未指向本机 $PUBLIC_IP)"; bad=1
    else echo "  ✓ $h → $(echo "$R4"|head -1)"; fi
  done; return $bad; }
if [ "${SKIP_DNS_CHECK:-0}" != "1" ]; then
  bold "1/6 检查 DNS"; A=0
  until dns_check; do A=$((A+1))
    has_tty || { echo "DNS 未就绪,改好后重跑。"; exit 1; }
    [ "$A" -ge 40 ] && die "等待过久,请检查记录后重跑"
    warn "DNS 还没生效,60 秒后重测…(Ctrl+C 退出)"; sleep 60
  done; ok "DNS 就绪"
else warn "已跳过 DNS 预检"; fi

# ---------------------------------------------------------------------
# 2. Docker + 内存/Swap/BBR + 防火墙
# ---------------------------------------------------------------------
bold "2/6 安装 Docker"
command -v docker >/dev/null 2>&1 || curl -fsSL https://get.docker.com | sh
docker compose version >/dev/null 2>&1 || apt-get install -y -qq docker-compose-plugin || die "docker compose v2 不可用"

bold "3/6 系统调优(Swap / BBR)"
RAM_MB="$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo)"
if [ "${RAM_MB:-0}" -lt 2500 ] && [ -z "$(swapon --show --noheadings 2>/dev/null)" ]; then
  if { fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none 2>/dev/null; } \
     && chmod 600 /swapfile 2>/dev/null && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' > /etc/sysctl.d/99-tuwunel-swap.conf; sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    echo "内存 ${RAM_MB}MB,已加 2G swap。"
  else rm -f /swapfile; warn "无法加 swap,跳过(不影响)。"; fi
else echo "内存 ${RAM_MB:-?}MB,swap OK,跳过。"; fi
if modprobe tcp_bbr 2>/dev/null || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' > /etc/sysctl.d/99-tuwunel-bbr.conf
  { sysctl -p /etc/sysctl.d/99-tuwunel-bbr.conf || sysctl --system; } >/dev/null 2>&1 || true
  [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] && echo "已启用 BBR。" || warn "BBR 未即时生效(容器型 VPS 常见),重启后再看。"
else warn "内核不支持 BBR,跳过。"; fi
# 内存档:tuwunel 很轻
if [ "${RAM_MB:-0}" -ge 3500 ]; then TUWUNEL_MEM=2g; else TUWUNEL_MEM=1g; fi

bold "4/6 防火墙 (ufw)"
SSH_PORT="$(ss -tlnpH 2>/dev/null | awk '/sshd/{sub(/.*:/,"",$4); print $4; exit}' || true)"; SSH_PORT="${SSH_PORT:-22}"
if command -v ufw >/dev/null 2>&1 || apt-get install -y -qq ufw >/dev/null 2>&1; then
  if ufw allow "${SSH_PORT}/tcp" >/dev/null 2>&1; then
    ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw allow 443/udp >/dev/null
    if [ "$ENABLE_CALLS" = "1" ]; then ufw allow 7881/tcp >/dev/null; ufw allow 7882/udp >/dev/null
    else ufw delete allow 7881/tcp >/dev/null 2>&1 || true; ufw delete allow 7882/udp >/dev/null 2>&1 || true; fi
    ufw --force enable >/dev/null; echo "已放行: SSH(${SSH_PORT}) + $PORT_LINE"
  else warn "ufw 不可用,请自行放行端口。"; fi
else warn "ufw 不可用,请自行放行端口。"; fi
warn "云服务商『安全组』也要放行: $PORT_LINE"

# ---------------------------------------------------------------------
# 5. 目录 / 机密 / 配置文件
# ---------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" || die "无法创建 $INSTALL_DIR"; cd "$INSTALL_DIR"; INSTALL_DIR="$PWD"
SELF_DST="$INSTALL_DIR/tuwunel-installer.sh"
if [ -n "$SELF_SRC" ] && [ "$SELF_SRC" != "$SELF_DST" ]; then
  cp -f "$SELF_SRC" "$SELF_DST" 2>/dev/null || true
elif [ ! -f "$SELF_DST" ] && [ -n "${TUWUNEL_INSTALLER_URL:-}" ]; then
  # curl|bash 管道模式无文件实体:从 GitHub 原始地址回源下载一份,供以后菜单/adduser 用
  curl -fsSL "$TUWUNEL_INSTALLER_URL" -o "$SELF_DST" 2>/dev/null || true
fi
[ -f "$SELF_DST" ] && HAVE_LOCAL=1 || HAVE_LOCAL=0
# 装一个全局命令:以后开菜单/加人直接 `sudo tuwunel`,不用记路径(BBR 脚本式便利)
if [ "$HAVE_LOCAL" = "1" ] && [ -d /usr/local/bin ]; then
  printf '#!/usr/bin/env bash\nexec bash %s "$@"\n' "$SELF_DST" > /usr/local/bin/tuwunel 2>/dev/null \
    && chmod +x /usr/local/bin/tuwunel 2>/dev/null || true
fi
if [ "$HAVE_LOCAL" = "1" ] && [ -d /etc/cron.d ]; then
  printf '30 4 * * * root INSTALL_DIR=%s bash %s diskguard >/dev/null 2>&1\n' "$INSTALL_DIR" "$SELF_DST" \
    > /etc/cron.d/tuwunel-diskguard 2>/dev/null && chmod 644 /etc/cron.d/tuwunel-diskguard 2>/dev/null || true
fi

# 已完成的部署且非 config → 只重启
if [ "$RECONFIG" -eq 0 ] && [ -f tuwunel.toml ] && grep -q "$MARKER" tuwunel.toml 2>/dev/null && [ -f CREDENTIALS.txt ]; then
  warn "检测到已完成的部署,只做重启。"; docker compose up -d; exit 0
fi
# 端口占用预检
if ! docker compose ps -q caddy 2>/dev/null | grep -q .; then
  if ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Eq ':(80|443)$'; then
    die "80/443 被别的程序占用(nginx/apache?),先停掉再重跑"; fi
fi

bold "5/6 生成密钥与配置"
umask 077
[ -f .env ] && cp -a .env ".env.bak-$(date +%F-%H%M%S)" 2>/dev/null || true
env_get(){ grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- || true; }
REG_TOKEN="$(env_get REG_TOKEN)"; [ -n "$REG_TOKEN" ] || REG_TOKEN="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
[ -n "${ENABLE_CALLS_KEYS:-}" ] || true
LK_KEY="$(env_get LIVEKIT_API_KEY)"; [ -n "$LK_KEY" ] || LK_KEY="API$(openssl rand -hex 6)"
LK_SECRET="$(env_get LIVEKIT_API_SECRET)"; [ -n "$LK_SECRET" ] || LK_SECRET="$(openssl rand -hex 32)"

cat > .env <<EOF
# ===== tuwunel 一键部署机密(勿泄露/删除) $(date +%F) =====
MATRIX_DOMAIN=$DOMAIN
REG_TOKEN=$REG_TOKEN
REG_MODE=$REG_MODE
ENABLE_FEDERATION=$ENABLE_FEDERATION
ENABLE_CALLS=$ENABLE_CALLS
MAX_UPLOAD_BYTES=$MAX_UPLOAD_BYTES
TUWUNEL_MEM=$TUWUNEL_MEM
LIVEKIT_API_KEY=$LK_KEY
LIVEKIT_API_SECRET=$LK_SECRET
EOF
chmod 600 .env

# ---- tuwunel.toml ----
# 注册:token 模式 = allow_registration=true + registration_token(需令牌);open = 无令牌(需额外确认标志)
if [ "$REG_MODE" = "open" ]; then REG_LINES="allow_registration = true
yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = true"
else REG_LINES="allow_registration = true
registration_token = \"$REG_TOKEN\""; fi
if [ "$ENABLE_FEDERATION" = "1" ]; then FED_LINE="allow_federation = true"; TRUST_LINE="trusted_servers = [\"matrix.org\"]"
else FED_LINE="allow_federation = false"; TRUST_LINE="trusted_servers = []"; fi
if [ "$ENABLE_CALLS" = "1" ]; then WK_LIVEKIT="livekit_url = \"https://$RTC_HOST\""; else WK_LIVEKIT="# livekit_url = \"\"  # 通话关闭"; fi

cat > tuwunel.toml <<EOF
# ===== $MARKER($(date +%F))=====
[global]
server_name = "$DOMAIN"          # 一旦部署不可更改!改需清库
database_path = "/var/lib/tuwunel"   # RocksDB:数据库+媒体都在这
address = ["0.0.0.0"]            # Docker 下必须 0.0.0.0,让 Caddy 能连到
port = 8008
max_request_size = $MAX_UPLOAD_BYTES   # 单文件上限(字节)= $(human "$MAX_UPLOAD_BYTES")
allow_encryption = true          # 端到端加密
grant_admin_to_first_user = true # 第一个注册的人=服务器管理员
create_admin_room = true
new_user_displayname_suffix = "" # 去掉默认昵称后缀
allow_public_room_directory_over_federation = false
$FED_LINE
$TRUST_LINE
$REG_LINES

[global.well_known]
client = "https://$M_HOST"
server = "$M_HOST:443"
$WK_LIVEKIT
EOF
chmod 600 tuwunel.toml

# ---- docker-compose.yml ----
cat > docker-compose.yml <<EOF
name: tuwunel

x-logging: &log
  driver: json-file
  options: { max-size: "10m", max-file: "3" }

services:
  tuwunel:
    image: $TUWUNEL_IMAGE
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    environment:
      TUWUNEL_CONFIG: /etc/tuwunel.toml
    volumes:
      - ./tuwunel.toml:/etc/tuwunel.toml:ro
      - ./data/tuwunel:/var/lib/tuwunel
    mem_limit: \${TUWUNEL_MEM}
    networks: [internal]
EOF

if [ "$ENABLE_CALLS" = "1" ]; then
cat >> docker-compose.yml <<'EOF'

  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    environment:
      LIVEKIT_URL: "wss://livekit.${MATRIX_DOMAIN}"
      LIVEKIT_KEY: ${LIVEKIT_API_KEY}
      LIVEKIT_SECRET: ${LIVEKIT_API_SECRET}
      LIVEKIT_FULL_ACCESS_HOMESERVERS: ${MATRIX_DOMAIN}
      LIVEKIT_JWT_BIND: ":8080"
    extra_hosts:
      - "${MATRIX_DOMAIN}:host-gateway"
      - "matrix.${MATRIX_DOMAIN}:host-gateway"
    mem_limit: 64m
    networks: [internal]

  livekit:
    image: livekit/livekit-server:latest
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    command: ["--config", "/etc/livekit.yaml"]
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml:ro
    ports:
      - "7881:7881/tcp"
      - "7882:7882/udp"
    mem_limit: 256m
    networks: [internal]
EOF
fi

cat >> docker-compose.yml <<'EOF'

  caddy:
    image: caddy:2
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    depends_on: [tuwunel]
    ports: ["80:80", "443:443", "443:443/udp"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data/caddy/data:/data
      - ./data/caddy/config:/config
    mem_limit: 128m
    networks: [internal]

networks:
  internal: { driver: bridge }
EOF

# ---- well-known JSON(开通话则带 rtc_foci)----
if [ "$ENABLE_CALLS" = "1" ]; then
  CLIENT_WK="{\"m.homeserver\":{\"base_url\":\"https://$M_HOST\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://$RTC_HOST\"}]}"
else
  CLIENT_WK="{\"m.homeserver\":{\"base_url\":\"https://$M_HOST\"}}"
fi

# ---- Caddyfile ----
cat > Caddyfile <<EOF
{
	email $ACME_EMAIL
}

# 委派:server_name=$DOMAIN,实际服务在 $M_HOST
$DOMAIN {
	handle /.well-known/matrix/server {
		header Content-Type application/json
		header Access-Control-Allow-Origin *
		respond \`{"m.server":"$M_HOST:443"}\` 200
	}
	handle /.well-known/matrix/client {
		header Content-Type application/json
		header Access-Control-Allow-Origin *
		respond \`$CLIENT_WK\` 200
	}
	handle {
		respond "$DOMAIN — Matrix (tuwunel)" 200
	}
}

$M_HOST {
	reverse_proxy tuwunel:8008
}
EOF
if [ "$ENABLE_CALLS" = "1" ]; then
cat >> Caddyfile <<EOF

$LK_HOST {
	reverse_proxy livekit:7880
}
$RTC_HOST {
	reverse_proxy lk-jwt-service:8080
}
EOF
fi

# ---- livekit.yaml(仅通话)----
if [ "$ENABLE_CALLS" = "1" ]; then
cat > livekit.yaml <<EOF
port: 7880
bind_addresses: ["0.0.0.0"]
log_level: info
rtc: { tcp_port: 7881, udp_port: 7882, use_external_ip: true }
room: { auto_create: false }
keys: { $LK_KEY: $LK_SECRET }
webhook: { api_key: $LK_KEY, urls: ["http://lk-jwt-service:8080/sfu_webhook"] }
turn: { enabled: false }
EOF
chmod 600 livekit.yaml
else rm -f livekit.yaml 2>/dev/null || true; fi

mkdir -p data/tuwunel
docker compose config -q || die "compose 配置校验失败"

# ---------------------------------------------------------------------
# 6. 启动 + 验收
# ---------------------------------------------------------------------
bold "6/6 启动(首次拉镜像需几分钟)"
[ "$RECONFIG" -eq 0 ] && docker compose pull -q || true
docker compose up -d --remove-orphans
[ "$RECONFIG" -eq 1 ] && { docker compose restart tuwunel caddy >/dev/null 2>&1 || true; echo "已按新配置重启。"; }

echo "等待 tuwunel 就绪…"; READY=0
for i in $(seq 1 40); do
  if docker compose exec -T tuwunel curl -fsS --max-time 3 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1 \
     || curl -4 -fsS --max-time 3 "http://127.0.0.1" >/dev/null 2>&1; then :; fi
  if curl -4 -fsS --max-time 4 "https://$M_HOST/_matrix/client/versions" >/dev/null 2>&1; then READY=1; ok "tuwunel 在线,HTTPS 已生效。"; break; fi
  sleep 5
done
[ "$READY" -eq 1 ] || warn "还没就绪。常见:云安全组没放行 80/443,或 DNS 未全球生效;Caddy 会自动重试证书,无需重装。看日志: cd $INSTALL_DIR && docker compose logs --tail 40"

# ---- 自动创建管理员(首个账号=管理员)+ 写凭据(成功才写,作为"部署完成"标志)----
ADMIN_USER="admin"; ADMIN_PASS=""; ADMIN_OK=0
if [ -f CREDENTIALS.txt ]; then
  ADMIN_OK=1                       # config/续跑:已有账号,不重复建、不覆盖凭据
elif [ "$READY" -eq 1 ]; then
  ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  echo "==> 自动创建管理员 @$ADMIN_USER:$DOMAIN(第一个账号即服务器管理员)…"
  if register_user "$ADMIN_USER" "$ADMIN_PASS" "https://$M_HOST" "$REG_TOKEN"; then
    ADMIN_OK=1; ok "管理员已自动创建。"
  else
    warn "自动建管理员失败(服务可能刚起未完全就绪)。稍后执行: sudo bash tuwunel-installer.sh adduser 建号(首个即管理员)。"
  fi
fi

if [ "$ADMIN_OK" -eq 1 ] && [ ! -f CREDENTIALS.txt ]; then
cat > CREDENTIALS.txt <<EOF
==== tuwunel 部署凭据  $DOMAIN  $(date '+%F %T') ====
安装目录:    $INSTALL_DIR
引擎:        tuwunel (Rust, 内置 RocksDB, 免 Postgres)
客户端登录:  Element X / app.element.io,服务器填 $DOMAIN
管理员账号:  $ADMIN_USER   (完整ID: @$ADMIN_USER:$DOMAIN)
管理员密码:  $ADMIN_PASS
注册令牌:    $REG_TOKEN
加成员:      sudo bash tuwunel-installer.sh adduser  (一条命令建号并设密码)
单文件上限:  $(human "$MAX_UPLOAD_BYTES")   (改: MAX_UPLOAD=10G sudo -E bash tuwunel-installer.sh config)
★ 必须备份:  整个 data/tuwunel 目录(含数据库与全部媒体)+ tuwunel.toml + .env
EOF
chmod 600 CREDENTIALS.txt
fi

# ---- 收尾报告 ----
CALL_NOTE=""
[ "$ENABLE_CALLS" = "1" ] && CALL_NOTE="
 通话(Element Call)已开:客户端里发起群组通话即可。若不通,先 curl -s https://$RTC_HOST 看是否 200,并确认 7882/udp 放行。"

if [ "$ADMIN_OK" -eq 1 ] && [ -n "$ADMIN_PASS" ]; then
  ADMIN_INFO="   账号: ${C_B}$ADMIN_USER${C_RESET}    密码: ${C_B}${C_GREEN}$ADMIN_PASS${C_RESET}
   → 用 Element 直接登录(服务器填 $DOMAIN)即可,你就是管理员。"
elif [ "$ADMIN_OK" -eq 1 ]; then
  ADMIN_INFO="   账号密码不变(见 $INSTALL_DIR/CREDENTIALS.txt)"
else
  ADMIN_INFO="   ${C_YELLOW}还没建好${C_RESET} → 服务就绪后执行: ${C_B}sudo bash tuwunel-installer.sh adduser${C_RESET}(首个建成的即管理员)"
fi

cat <<EOF

${C_GREEN}========================================================${C_RESET}
 ${C_B}${C_GREEN}🎉 tuwunel 部署完成!${C_RESET}  ${C_B}$DOMAIN${C_RESET}
 (注册[$REG_MODE] · 联邦[$([ "$ENABLE_FEDERATION" = 1 ] && echo 开 || echo 关)] · 通话[$([ "$ENABLE_CALLS" = 1 ] && echo 开 || echo 关)] · 大文件[$(human "$MAX_UPLOAD_BYTES")] · 引擎 tuwunel/Rust,免Postgres)

 手机装 Element X,登录:
   服务器:  ${C_B}$DOMAIN${C_RESET}

 ${C_B}${C_YELLOW}管理员(已自动创建,不用你手动注册)${C_RESET}
$ADMIN_INFO
   (凭据存于 $INSTALL_DIR/CREDENTIALS.txt)

 日常管理(已装好全局命令,不用记路径、不用再带域名):
   ${C_B}sudo tuwunel${C_RESET}          打开管理菜单
   ${C_B}sudo tuwunel adduser${C_RESET}  加成员(一条命令建号并设密码)
$CALL_NOTE
 发大文件/大图/长视频: 已把上限设到 $(human "$MAX_UPLOAD_BYTES"),直接在聊天里发即可。
   注意:媒体存在 data/tuwunel(本地盘),大视频涨盘快,留意磁盘;E2EE 房超大文件较吃客户端内存。

 自检:
   curl -s https://$DOMAIN/.well-known/matrix/client
   cd $INSTALL_DIR && docker compose ps    # 容器都应 running

 ${C_YELLOW}⚠️ 云安全组放行: $PORT_LINE${C_RESET}
 ${C_DIM}提示:tuwunel 较年轻、无成熟网页后台;要最成熟稳定+Ketesa 后台请用 Synapse 版脚本。${C_RESET}
${C_GREEN}========================================================${C_RESET}
EOF
