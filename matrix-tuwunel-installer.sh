#!/usr/bin/env bash
# =====================================================================
#  Matrix 轻量一键安装脚本 · tuwunel 版(通用版 t1.7)
#  t1.7: 新增【自托管 Web 管理后台 Ketesa】(synapse-admin 官方支持的成熟面板):
#        tuwunel v1.8.1+ 已实现 Synapse 管理 API,面板放 admin.你的域名,可图形化
#        管理用户/房间/媒体/邀请码。tuwunel 全局自带 CORS(源码确认),故 Caddy 不再需
#        要加 CORS(加了反而冲突)。Ketesa 亦为非 root(sws 用户/8080),已同样处理端口与权限。
#  t1.6: 修复网页客户端 502(第二处根因)—— element-web 以非 root nginx 运行,
#        而配置文件因 umask 077 是 600(仅 root 可读),容器读不了 /app/config.json 而崩溃重启;
#        改为 chmod 644(此文件是公开的客户端配置,无机密)。
#  t1.5: 修复网页客户端 502 —— 新版 element-web 是非 root nginx,绑不了 80 端口;
#        改为监听 8080(ELEMENT_WEB_PORT=8080)、Caddy 转发到 element-web:8080。
#  t1.4: 新增【自更新】:老部署想拿新功能,`sudo tuwunel update` 一条命令从 GitHub 拉最新脚本
#        并自动应用(数据/账号不动);或重跑一键安装命令也会刷新本地脚本+全局命令。
#  t1.3: 新增可选【自托管 Element Web 网页客户端】(默认开):成员打开 https://你的域名
#        就能直接注册/登录/聊天,不用去 element.io、不用装 App;锁定到你的服务器、可白标。
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
#    · 【成熟 Web 管理后台】:tuwunel v1.8.1+ 已实现 Synapse 管理 API,本脚本可选装
#      Ketesa(synapse-admin 官方支持的成熟图形面板),图形化管理用户/邀请码/房间/媒体。
#  代价(务必知晓):tuwunel 的 Synapse 管理 API 较新(2026-07 起),覆盖约 69/100 端点
#    (核心用户/房间/媒体/邀请码全通;举报/限速等边角页面不可用);CLI 与管理员房间命令永久兜底。
#
#  组件: Caddy(自动HTTPS) + tuwunel  (+ 可选 Element Web 网页客户端 / Ketesa 管理后台 / LiveKit 通话)
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
#      sudo tuwunel update        # 从 GitHub 拉最新脚本并应用新功能(数据不动)
#      sudo tuwunel enable-admin  # 【老服务器补装 Web 管理后台 Ketesa】(只开后台,不动其它)
#      sudo tuwunel config        # 改配置    sudo tuwunel uninstall  # 卸载
#   (curl|bash 管道模式想让菜单/adduser 可用,设 TUWUNEL_INSTALLER_URL=<上面URL> 让它自取副本)
#
#  前提: DNS A 记录已指向本服务器公网 IP:
#    你的域名.com   matrix.你的域名.com   (开后台再加 admin. ;开通话再加 livekit.  matrix-rtc.)
#
#  可选环境变量:
#    INSTALL_DIR=/opt/tuwunel   安装目录(默认)
#    ACME_EMAIL=you@x.com       证书通知邮箱(默认 admin@域名)
#    SKIP_DNS_CHECK=1           跳过 DNS 预检
#    REG_MODE=token|open        注册方式(默认 token=需令牌)
#    ENABLE_FEDERATION=1|0      联邦(默认 0=关闭,纯私密孤岛)
#    ENABLE_CALLS=1|0           语音视频通话(默认 0=关闭)
#    ENABLE_ADMIN=1|0           Web 管理后台 Ketesa(默认 1=开;放 admin.域名,需加 DNS)
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
# 自更新用的脚本原始地址(可用 TUWUNEL_UPDATE_URL 覆盖为你的 fork 或加速镜像)
REPO_RAW="${TUWUNEL_UPDATE_URL:-https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh}"

# (重新)安装全局命令 `tuwunel` 指向已装好的脚本副本
install_launcher() {
  [ -f "$1" ] && [ -d /usr/local/bin ] || return 0
  printf '#!/usr/bin/env bash\nexec bash %s "$@"\n' "$1" > /usr/local/bin/tuwunel 2>/dev/null \
    && chmod +x /usr/local/bin/tuwunel 2>/dev/null || true
}

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
  echo "  域名: ${d:-未知}   注册: $(env_saved REG_MODE)   联邦: $([ "$(env_saved ENABLE_FEDERATION)" = "1" ] && echo 开 || echo 关)   通话: $([ "$(env_saved ENABLE_CALLS)" = "1" ] && echo 开 || echo 关)   网页: $([ "$(env_saved ENABLE_WEB)" = "1" ] && echo 开 || echo 关)   后台: $([ "$(env_saved ENABLE_ADMIN)" = "1" ] && echo 开 || echo 关)   大文件: $(human "$(env_saved MAX_UPLOAD_BYTES)")"
  [ "$(env_saved ENABLE_WEB)" = "1" ] && echo "  网页客户端: https://${d}(成员浏览器直接注册/登录)"
  [ "$(env_saved ENABLE_ADMIN)" = "1" ] && echo "  管理后台:  https://admin.${d}(管理员账号密码登录,图形化管理)"
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

# 子命令: update —— 从 GitHub 拉最新脚本,替换本地副本+全局命令,再自动应用新功能(不动数据)
if [ "${1:-}" = "update" ]; then
  [ -d "$INSTALL_DIR" ] || die "找不到 $INSTALL_DIR,先完成部署"
  SELF_DST="$INSTALL_DIR/tuwunel-installer.sh"; tmp="$(mktemp)"
  bold "更新脚本:从 $REPO_RAW 拉取最新…"
  if ! curl -fsSL "$REPO_RAW" -o "$tmp" 2>/dev/null; then
    rm -f "$tmp"; die "下载失败(网络/被墙?)。国内可: TUWUNEL_UPDATE_URL=<加速镜像地址> sudo -E tuwunel update"
  fi
  # 安全校验:必须是本脚本(含标识)且语法正确,才替换
  if grep -q "$MARKER" "$tmp" && bash -n "$tmp" 2>/dev/null; then
    cp -f "$tmp" "$SELF_DST" 2>/dev/null && chmod +x "$SELF_DST" 2>/dev/null || true
    install_launcher "$SELF_DST"; rm -f "$tmp"
    NEWV="$(grep -m1 '通用版 t' "$SELF_DST" | grep -oE 't[0-9]+\.[0-9]+' || echo 未知)"
    ok "脚本已更新到 $NEWV。"
    echo "==> 应用新配置(会问你几个选项,数据/账号一律不动)…"
    exec bash "$SELF_DST" config
  else
    rm -f "$tmp"; die "下载到的文件校验不通过(可能是错误页/被镜像篡改),已放弃,未改动任何东西。"
  fi
fi

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
# 子命令: enable-admin / disable-admin —— 给已部署的老服务器单独开/关 Web 管理后台
# (只改后台一项,不动注册/联邦/大文件等,也不问向导;需先加好 admin.域名 的 DNS)
if [ "${1:-}" = "enable-admin" ];  then ENABLE_ADMIN=1; RECONFIG=1; set --; fi
if [ "${1:-}" = "disable-admin" ]; then ENABLE_ADMIN=0; RECONFIG=1; set --; fi

# ---------------------------------------------------------------------
# 0. 基础 / 已部署检测 → 管理菜单
# ---------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "需要 root: sudo bash tuwunel-installer.sh 域名"

if [ "$RECONFIG" -eq 0 ] && [ -f "$INSTALL_DIR/CREDENTIALS.txt" ] \
   && grep -q "$MARKER" "$INSTALL_DIR/tuwunel.toml" 2>/dev/null; then
  cd "$INSTALL_DIR"; SELF_BIN="$INSTALL_DIR/tuwunel-installer.sh"
  # 重跑安装命令时,把本地脚本副本刷新成当前这份(这样老部署重跑一键命令即可拿到新版),并刷新全局命令
  if [ -f "${0:-}" ] && [ "$(readlink -f -- "${0:-}" 2>/dev/null)" != "$(readlink -f -- "$SELF_BIN" 2>/dev/null)" ]; then
    cp -f "$0" "$SELF_BIN" 2>/dev/null || true
  fi
  install_launcher "$SELF_BIN"
  if has_tty; then
    MENU_DOMAIN="$(env_saved MATRIX_DOMAIN)"
    while :; do
      cat <<EOF

┌──────────────────────────────────────────────┐
│  tuwunel 管理菜单   ${MENU_DOMAIN:-}
└──────────────────────────────────────────────┘
  1) 查看运行状态
  2) 添加团队成员(一条命令建号并设密码)
  3) 修改配置(注册 / 联邦 / 通话 / 网页 / 后台 / 大文件)
  4) $([ "$(env_saved ENABLE_ADMIN)" = "1" ] && echo "关闭 Web 管理后台(Ketesa)" || echo "开启 Web 管理后台(Ketesa,老服务器补装)")
  5) 立即备份(配置 + 数据库 + 媒体)
  6) 升级服务镜像(docker 拉最新)
  7) 清理磁盘
  8) 重启所有服务
  9) 更新脚本 + 应用新功能(从 GitHub 拉最新,数据不动)
 10) 彻底卸载
  0) 退出
EOF
      MCHOICE=""
      if [ -t 0 ]; then read -rp "请选择 [0-10]: " MCHOICE || exit 0
      else read -rp "请选择 [0-10]: " MCHOICE < /dev/tty 2>/dev/null || exit 0; fi
      case "$MCHOICE" in
        1) menu_status ;;
        2) [ -f "$SELF_BIN" ] && bash "$SELF_BIN" adduser || warn "缺少脚本副本" ;;
        3) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config || warn "缺少脚本副本" ;;
        4) if [ "$(env_saved ENABLE_ADMIN)" = "1" ]; then
             [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" disable-admin || warn "缺少脚本副本"
           else
             echo "开启后需要 admin.${MENU_DOMAIN} 已解析到本机(否则会卡在 DNS 检查)。"
             [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" enable-admin || warn "缺少脚本副本"
           fi ;;
        5) menu_backup ;;
        6) echo "==> 拉取最新镜像并升级…"
           { docker compose pull -q && docker compose up -d --remove-orphans && ok "升级完成"; } || warn "升级失败: docker compose logs --tail 30" ;;
        7) menu_cleanup ;;
        8) { docker compose up -d && docker compose restart; } >/dev/null 2>&1 && ok "已重启" || warn "重启失败: docker compose ps" ;;
        9) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" update || warn "缺少脚本副本"
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        10) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" uninstall || warn "缺少脚本副本"
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        0|q|Q) echo "再见。"; exit 0 ;;
        *) warn "无效选择,请输入 0-10" ;;
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
M_HOST="matrix.$DOMAIN"; LK_HOST="livekit.$DOMAIN"; RTC_HOST="matrix-rtc.$DOMAIN"; A_HOST="admin.$DOMAIN"
apt-get update -qq >/dev/null 2>&1 || true
command -v curl >/dev/null 2>&1 || apt-get install -y -qq curl || die "curl 安装失败"
command -v openssl >/dev/null 2>&1 || apt-get install -y -qq openssl || die "openssl 安装失败"
PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
bold "目标: $DOMAIN  →  服务器 ${PUBLIC_IP:-未知}  →  目录 $INSTALL_DIR  (引擎: tuwunel/Rust)"

# ---------------------------------------------------------------------
# 选项(回车=推荐默认;重跑沿用;环境变量可预设)
# ---------------------------------------------------------------------
EXPLICIT=0; [ -n "${REG_MODE:-}${ENABLE_FEDERATION:-}${ENABLE_CALLS:-}${ENABLE_WEB:-}${ENABLE_ADMIN:-}${MAX_UPLOAD:-}" ] && EXPLICIT=1
REG_MODE="${REG_MODE:-$(env_saved REG_MODE)}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-$(env_saved ENABLE_FEDERATION)}"
ENABLE_CALLS="${ENABLE_CALLS:-$(env_saved ENABLE_CALLS)}"
ENABLE_WEB="${ENABLE_WEB:-$(env_saved ENABLE_WEB)}"   # 自托管 Element Web 网页客户端(你的域名注册/登录)
ENABLE_ADMIN="${ENABLE_ADMIN:-$(env_saved ENABLE_ADMIN)}"   # 自托管 Ketesa Web 管理后台(admin.你的域名)
MAX_UPLOAD="${MAX_UPLOAD:-}"
SAVED_BYTES="$(env_saved MAX_UPLOAD_BYTES)"

DEF_REG=1; DEF_FED=N; DEF_CALL=n; DEF_WEB=Y; DEF_ADMIN=Y
if [ "$RECONFIG" -eq 1 ] && [ "$EXPLICIT" -eq 0 ]; then
  has_tty || die "config 需交互终端;或用环境变量: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config"
  case "$REG_MODE" in open) DEF_REG=2;; *) DEF_REG=1;; esac
  [ "$ENABLE_FEDERATION" = "1" ] && DEF_FED=y || DEF_FED=N
  [ "$ENABLE_CALLS" = "1" ] && DEF_CALL=Y || DEF_CALL=n
  [ "$ENABLE_WEB" = "0" ] && DEF_WEB=n || DEF_WEB=Y
  [ "$ENABLE_ADMIN" = "0" ] && DEF_ADMIN=n || DEF_ADMIN=Y
  echo ""; echo "当前: 注册[$REG_MODE] · 联邦[$([ "$ENABLE_FEDERATION" = "1" ] && echo 开 || echo 关)] · 通话[$([ "$ENABLE_CALLS" = "1" ] && echo 开 || echo 关)] · 网页客户端[$([ "$ENABLE_WEB" = "1" ] && echo 开 || echo 关)] · 管理后台[$([ "$ENABLE_ADMIN" = "1" ] && echo 开 || echo 关)] · 大文件[$(human "${SAVED_BYTES:-4294967296}")]"
  echo "直接回车 = 保持当前值。"
  REG_MODE=""; ENABLE_FEDERATION=""; ENABLE_CALLS=""; ENABLE_WEB=""; ENABLE_ADMIN=""
fi

if has_tty && { [ -z "$REG_MODE" ] || [ -z "$ENABLE_FEDERATION" ] || [ -z "$ENABLE_CALLS" ] || [ -z "$ENABLE_WEB" ] || [ -z "$ENABLE_ADMIN" ]; }; then
  printf '\n%s安装选项:看不懂就直接回车用推荐值(已是私密最安全组合)。%s\n' "$C_B$C_CYAN" "$C_RESET"

  if [ -z "$REG_MODE" ]; then
    printf '\n%s【选项 1/6】谁能注册账号%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [1] 需注册令牌(推荐)—— 只有拿到你发的令牌的人才能注册;首个注册者=管理员。
  [2] 完全开放 —— 任何人都能注册(风险极高,商用勿选)。
EOF
    ask_opt "→ [1/2,回车=$DEF_REG]: " "$DEF_REG"
    case "$REPLY" in 2) REG_MODE=open; warn "已选开放注册,风险自负!";; *) REG_MODE=token;; esac
  fi

  if [ -z "$ENABLE_FEDERATION" ]; then
    printf '\n%s【选项 2/6】联邦互通(与外部 Matrix 世界相连)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [N] 关闭(推荐)—— 孤岛,外人无法向你的成员发消息,攻击面最小,商密首选。
  [y] 开启 —— 可与 matrix.org 等互通,暴露面变大。
EOF
    ask_opt "→ [y/N,回车=$DEF_FED]: " "$DEF_FED"
    case "$REPLY" in y|Y) ENABLE_FEDERATION=1;; *) ENABLE_FEDERATION=0;; esac
  fi

  if [ -z "$ENABLE_CALLS" ]; then
    printf '\n%s【选项 3/6】语音/视频通话(Element Call)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [n] 关闭(推荐先关)—— tuwunel 原生支持,但通话链路较新;先跑稳聊天+大文件。
  [Y] 开启 —— 额外装 LiveKit + lk-jwt,需再加 livekit. / matrix-rtc. 两条 DNS 和 7881/7882 端口。
EOF
    ask_opt "→ [y/N,回车=$DEF_CALL]: " "$DEF_CALL"
    case "$REPLY" in y|Y) ENABLE_CALLS=1;; *) ENABLE_CALLS=0;; esac
  fi

  if [ -z "$ENABLE_WEB" ]; then
    printf '\n%s【选项 4/6】自家域名网页客户端(Element Web)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [Y] 开启(推荐)—— 在【你自己的域名】放一个网页版 Element:成员打开
       https://你的域名 就能【直接注册、登录、聊天】,不用去 element.io、不用装 App。
       锁定到你的服务器、可白标;放根域名不需再加 DNS。多占约 30MB 内存。
  [n] 关闭 —— 成员只能用 Element X App 或 app.element.io 登录你的服务器。
EOF
    ask_opt "→ [Y/n,回车=$DEF_WEB]: " "$DEF_WEB"
    case "$REPLY" in n|N) ENABLE_WEB=0;; *) ENABLE_WEB=1;; esac
  fi

  if [ -z "$ENABLE_ADMIN" ]; then
    printf '\n%s【选项 5/6】Web 管理后台(Ketesa 图形面板)%s\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'
  [Y] 开启(推荐)—— 在【admin.你的域名】放一个成熟的图形管理面板(Ketesa,
       tuwunel 官方支持):浏览器里【图形化】管理用户、发/吊销邀请码、看房间/媒体、
       停用账号、改密码,不用敲命令。需再加一条 admin. 的 DNS。多占约 20MB 内存。
  [n] 关闭 —— 只用命令行(sudo tuwunel 菜单 / 管理员房间命令)管理。
EOF
    ask_opt "→ [Y/n,回车=$DEF_ADMIN]: " "$DEF_ADMIN"
    case "$REPLY" in n|N) ENABLE_ADMIN=0;; *) ENABLE_ADMIN=1;; esac
  fi

  if [ -z "$MAX_UPLOAD" ]; then
    printf '\n%s【选项 6/6】单文件上限(发大文件/大图/长视频)%s\n' "$C_B$C_CYAN" "$C_RESET"
    echo "  设多大都行(如 4G / 10G);越大越占磁盘。回车=4G。"
    ask_opt "→ 单文件上限 [回车=$(human "${SAVED_BYTES:-4294967296}")]: " "${SAVED_BYTES:+$(human "$SAVED_BYTES")}"
    [ -z "$REPLY" ] && REPLY="4G"; MAX_UPLOAD="$REPLY"
  fi
fi
REG_MODE="${REG_MODE:-token}"; ENABLE_FEDERATION="${ENABLE_FEDERATION:-0}"; ENABLE_CALLS="${ENABLE_CALLS:-0}"; ENABLE_WEB="${ENABLE_WEB:-1}"; ENABLE_ADMIN="${ENABLE_ADMIN:-1}"
case "$ENABLE_FEDERATION" in 1) :;; *) ENABLE_FEDERATION=0;; esac
case "$ENABLE_CALLS" in 1) :;; *) ENABLE_CALLS=0;; esac
case "$ENABLE_WEB" in 0) :;; *) ENABLE_WEB=1;; esac
case "$ENABLE_ADMIN" in 0) :;; *) ENABLE_ADMIN=1;; esac
case "$REG_MODE" in token|open) :;; *) REG_MODE=token;; esac
if [ -n "$MAX_UPLOAD" ]; then MAX_UPLOAD_BYTES="$(to_bytes "$MAX_UPLOAD")"
elif [ -n "$SAVED_BYTES" ]; then MAX_UPLOAD_BYTES="$SAVED_BYTES"
else MAX_UPLOAD_BYTES=4294967296; fi

REQUIRED_HOSTS="$DOMAIN $M_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp"
[ "$ENABLE_ADMIN" = "1" ] && REQUIRED_HOSTS="$REQUIRED_HOSTS $A_HOST"
if [ "$ENABLE_CALLS" = "1" ]; then REQUIRED_HOSTS="$REQUIRED_HOSTS $LK_HOST $RTC_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp 7881/tcp 7882/udp"; fi
echo ""
printf '  %s✔ 配置: 注册[%s] · 联邦[%s] · 通话[%s] · 网页客户端[%s] · 管理后台[%s] · 大文件上限[%s]%s\n' "$C_GREEN" \
  "$REG_MODE" "$([ "$ENABLE_FEDERATION" = 1 ] && echo 开 || echo 关)" "$([ "$ENABLE_CALLS" = 1 ] && echo 开 || echo 关)" "$([ "$ENABLE_WEB" = 1 ] && echo 开 || echo 关)" "$([ "$ENABLE_ADMIN" = 1 ] && echo 开 || echo 关)" "$(human "$MAX_UPLOAD_BYTES")" "$C_RESET"

# ---- 向导:必须手动做的事 ----
if has_tty && [ "$RECONFIG" -eq 0 ]; then
  DNS_LINES="      $DOMAIN
      $M_HOST"
  [ "$ENABLE_ADMIN" = "1" ] && DNS_LINES="$DNS_LINES
      $A_HOST"
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
ENABLE_WEB=$ENABLE_WEB
ENABLE_ADMIN=$ENABLE_ADMIN
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

# 自托管网页客户端 Element Web(你的域名注册/登录)
if [ "$ENABLE_WEB" = "1" ]; then
cat >> docker-compose.yml <<'EOF'

  element-web:
    image: vectorim/element-web:latest
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    environment:
      ELEMENT_WEB_PORT: "8080"   # 新版镜像是非 root nginx,绑不了 80;改用 8080(Caddy 转发到这)
    volumes:
      - ./element-config.json:/app/config.json:ro
    mem_limit: 96m
    networks: [internal]
EOF
fi

# 自托管 Web 管理后台 Ketesa(synapse-admin,tuwunel 官方支持;放 admin.你的域名)
if [ "$ENABLE_ADMIN" = "1" ]; then
cat >> docker-compose.yml <<'EOF'

  ketesa:
    image: ghcr.io/etkecc/ketesa:latest
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    environment:
      SERVER_HOST: "0.0.0.0"    # 非 root SWS,绑所有 IPv4 让 Caddy 连得到(默认可能只监听 IPv6)
    volumes:
      - ./ketesa-config.json:/var/public/config.json:ro
    mem_limit: 64m
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

# ---- Element Web 配置(锁定到本服务器)+ 根域名要不要挂网页客户端 ----
if [ "$ENABLE_WEB" = "1" ]; then
  cat > element-config.json <<EOF
{
  "default_server_config": {
    "m.homeserver": { "base_url": "https://$M_HOST", "server_name": "$DOMAIN" }
  },
  "disable_custom_urls": true,
  "disable_guests": true,
  "brand": "$DOMAIN",
  "default_country_code": "CN",
  "show_labs_settings": false
}
EOF
  chmod 644 element-config.json   # 关键!element-web 以非 root nginx 运行,须可读;此文件无机密(公开的客户端配置)
  ROOT_HANDLE="reverse_proxy element-web:8080"
else
  rm -f element-config.json 2>/dev/null || true
  ROOT_HANDLE="respond \"$DOMAIN — Matrix (tuwunel)\" 200"
fi

# ---- Ketesa 管理后台配置(锁定到本服务器,隐藏服务器输入框)----
if [ "$ENABLE_ADMIN" = "1" ]; then
  # restrictBaseUrl 为单个字符串 = 移除并锁死"服务器地址"输入框,用户只能连你这台。
  # wellKnownDiscovery=false = 直连 matrix.域名(它同时提供 /_matrix 与 /_synapse/admin),不依赖 well-known 可达性。
  cat > ketesa-config.json <<EOF
{"restrictBaseUrl":"https://$M_HOST","wellKnownDiscovery":false}
EOF
  chmod 644 ketesa-config.json   # 关键!Ketesa 以非 root(sws)运行,须可读;此文件无机密(仅指向你的服务器地址)
else
  rm -f ketesa-config.json 2>/dev/null || true
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
		$ROOT_HANDLE
	}
}

$M_HOST {
	reverse_proxy tuwunel:8008
}
EOF
# 管理后台 Ketesa(admin.域名 → ketesa:8080)。跨域由 tuwunel 全局 CorsLayer 处理,Caddy 不加 CORS。
if [ "$ENABLE_ADMIN" = "1" ]; then
cat >> Caddyfile <<EOF

$A_HOST {
	reverse_proxy ketesa:8080
}
EOF
fi
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

[ "$ENABLE_WEB" = "1" ] && WEB_URL="https://$DOMAIN" || WEB_URL=""
[ "$ENABLE_ADMIN" = "1" ] && ADMIN_URL="https://$A_HOST" || ADMIN_URL=""

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
$([ -n "$WEB_URL" ] && echo "网页注册/登录: $WEB_URL   (你的域名,浏览器直接注册,不用 element.io)")
客户端登录:  也可用 Element X App / app.element.io,服务器填 $DOMAIN
管理员账号:  $ADMIN_USER   (完整ID: @$ADMIN_USER:$DOMAIN)
管理员密码:  $ADMIN_PASS
$([ -n "$ADMIN_URL" ] && echo "Web 管理后台:  $ADMIN_URL   (用上面的管理员账号密码登录;图形化管理用户/邀请码/房间)")
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
 (注册[$REG_MODE] · 联邦[$([ "$ENABLE_FEDERATION" = 1 ] && echo 开 || echo 关)] · 通话[$([ "$ENABLE_CALLS" = 1 ] && echo 开 || echo 关)] · 网页客户端[$([ "$ENABLE_WEB" = 1 ] && echo 开 || echo 关)] · 管理后台[$([ "$ENABLE_ADMIN" = 1 ] && echo 开 || echo 关)] · 大文件[$(human "$MAX_UPLOAD_BYTES")] · 引擎 tuwunel/Rust,免Postgres)

 ${C_B}${C_YELLOW}成员注册 / 登录${C_RESET}$([ -n "$WEB_URL" ] && printf '\n   网页版(推荐):浏览器打开 %s%s%s 直接注册登录 —— 你自己的域名,不用去 element.io、不用装 App(手机浏览器也能用)。' "$C_B$C_GREEN" "$WEB_URL" "$C_RESET")
   也可用 Element X App / app.element.io:服务器填 ${C_B}$DOMAIN${C_RESET}
$([ "$REG_MODE" = "token" ] && echo "   (需注册令牌:令牌在 CREDENTIALS.txt;或直接 sudo tuwunel adduser 建好账号发给成员)")

 ${C_B}${C_YELLOW}管理员(已自动创建,不用你手动注册)${C_RESET}
$ADMIN_INFO
   (凭据存于 $INSTALL_DIR/CREDENTIALS.txt)
$([ -n "$ADMIN_URL" ] && printf '\n %s%sWeb 管理后台(图形化,推荐)%s\n   浏览器打开 %s%s%s,用上面的管理员账号密码登录。\n   可【图形化】管理成员、发/吊销邀请码、看房间与媒体、停用账号、改密码——不用敲命令。\n   (面板锁定到你的服务器;成熟面板 Ketesa,tuwunel 官方支持)' "$C_B" "$C_YELLOW" "$C_RESET" "$C_B$C_GREEN" "$ADMIN_URL" "$C_RESET")

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
$([ -n "$ADMIN_URL" ] && printf ' %s提示:管理后台 Ketesa 依赖 tuwunel v1.8.1+ 的 Synapse 管理 API(较新);若面板登录报错,先 docker compose pull tuwunel 拉最新版。核心功能(用户/邀请码/房间/媒体)可用,举报/限速等边角页面不可用属正常。%s' "$C_DIM" "$C_RESET")
${C_GREEN}========================================================${C_RESET}
EOF
