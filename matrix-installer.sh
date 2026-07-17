#!/usr/bin/env bash
# =====================================================================
#  Matrix 全功能一键安装脚本(通用版 v1.6)
#
#  v1.6 新增:开启内核自带的 BBR 拥塞控制(fq + bbr),TCP 传输(网页/App、媒体文件收发、
#    跨境弱网)更顺;UDP 语音视频通话不受影响。容器型 VPS 内核只读时自动跳过、不影响安装。
#  v1.5 新增:①磁盘守卫+媒体清理(容器日志轮转 10MB×3、远端缓存媒体按 REMOTE_MEDIA_DAYS
#    天自动清、菜单第 7 项/`cleanup` 子命令手动清理、每日 cron 磁盘偏高自动回收 Docker 冗余;
#    本地文件默认永久保留,仅显式 LOCAL_MEDIA_DAYS 才按期删)。②消息留存/自动销毁(安装
#    向导第 4 项,默认永久;选 N 天则超期消息自动清除)。③安装/报告文字加彩色高亮(标题、
#    推荐、密码、后台地址、端口等),非终端/NO_COLOR 时自动关闭。
#
#  v1.4 修复(实机验证):管理后台进用户列表报 Failed to fetch / Load failed,
#    浏览器控制台明确为 "blocked by CORS policy: No 'Access-Control-Allow-Origin'"。
#    根因:面板跨域调 matrix.<域名>/_synapse/admin,而 Synapse 自身不发 CORS 头。
#    正解:在 matrix.<域名> 上给 /_synapse/* 补 CORS 头 + 放行 OPTIONS 预检(见下方
#    Caddyfile)。这样【自建后台】和【官方 admin.etke.cc】两种方式都能用。
#    admin API 仍强制校验管理员 token(无 token 一律 401),公网可达但打不动。
#  v1.3(旧尝试,保留 admin 域名同源代理作为备选,不影响 v1.4):
#    admin.<域名> 上 config.json 加 wellKnownDiscovery:false + 自指 well-known。
#
#  License: PolyForm Noncommercial 1.0.0 —— 个人/非商业使用免费;
#  ★除作者外禁止任何商业用途★,商业授权请联系作者(GitHub 提 Issue)。
#  ★特别声明:禁止在淘宝、闲鱼(咸鱼)、拼多多、京东、抖音/快手小店、微店、
#    转转等一切电商及二手平台售卖本脚本;禁止收费代装、代部署、捆绑倒卖
#    等类似牟利行为 —— 发现即举报并依许可证追责。★
#  Required Notice: Copyright (c) 2026 VeilXofficial
#  https://github.com/VeilXofficial/veilx_matrix_ocs (全文见仓库 LICENSE)
#
#  【本脚本为适应复杂商业环境、保护商业机密而开发】
#  客户资料、报价合同、内部讨论、语音视频会议 —— 全部只存在于
#  你自己的服务器上,端到端加密,默认全封闭配置,外部无法触达。
#  面向不懂网络技术的使用者:每个选择都有大白话说明,回车即最安全默认。
#
#  在任意域名 + 任意 Ubuntu 22/24 / Debian 11+ 服务器上部署:
#    聊天/群聊 + 图片视频文件互传 + 一对一及群组语音视频通话(E2EE)
#  组件: Caddy(自动HTTPS) + Synapse + PostgreSQL + LiveKit + lk-jwt-service
#  客户端: Element X / Element Web / 任意 Matrix 客户端
#
#  用法(先把脚本下载到服务器,再以 root 执行):
#    sudo bash matrix-installer.sh           # 标准用法:向导会询问域名
#    sudo bash matrix-installer.sh mychat.org  # 高级用法:直接带域名参数
#    sudo bash matrix-installer.sh adduser   # 部署完后:添加团队成员
#    sudo bash matrix-installer.sh config    # 部署完后:修改配置(注册/通话/联邦)
#    sudo bash matrix-installer.sh uninstall # 彻底卸载(双重确认,先提示备份)
#  部署完成后,直接重跑本脚本 = 打开中文管理菜单(状态/加人/改配置/备份/升级/重启/卸载)
#
#  前提: 4 条 DNS A 记录已指向本服务器公网 IP:
#    你的域名.com  matrix.你的域名.com  livekit.你的域名.com  matrix-rtc.你的域名.com
#
#  可选环境变量:
#    INSTALL_DIR=/opt/matrix   安装目录(默认)
#    ACME_EMAIL=you@x.com      证书通知邮箱(默认 admin@域名)
#    SKIP_DNS_CHECK=1          跳过 DNS 预检(走 CDN/代理时用,一般别用)
#    REG_MODE=closed|token|open  注册方式(默认 closed=仅管理员建号)
#    ENABLE_CALLS=1|0          语音视频通话(默认 1=开启)
#    ENABLE_FEDERATION=1|0     联邦互通(默认 0=关闭,纯私密)
#
#  脚本可安全重复运行:已完成的部署只做重启;半途失败的部署会自动续装
#  (密钥自动复用,不会因重跑而错乱)。
# =====================================================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/matrix}"
MARKER="由 matrix-installer.sh 生成"

# ---- 终端配色(仅在真正的终端启用;输出被重定向到文件/日志、或设了 NO_COLOR 时自动关闭)----
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  E=$'\033'
  C_RESET="${E}[0m"; C_B="${E}[1m"; C_DIM="${E}[2m"; C_U="${E}[4m"
  C_CYAN="${E}[1;36m"; C_GREEN="${E}[1;32m"; C_YELLOW="${E}[1;33m"
  C_RED="${E}[1;31m";  C_BLUE="${E}[1;34m";  C_MAGENTA="${E}[1;35m"
else
  C_RESET=""; C_B=""; C_DIM=""; C_U=""
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_MAGENTA=""
fi

bold() { printf '\n%s==> %s%s\n' "$C_B$C_CYAN" "$1" "$C_RESET"; }
warn() { printf '%s[!] %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
die()  { printf '%s[✗] %s%s\n' "$C_RED" "$1" "$C_RESET"; exit 1; }
ok()   { printf '%s✓ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }

# 交互辅助: 能真正打开 /dev/tty 才算有终端(curl|bash 时 stdin 是管道,
# 但 SSH 会话的 /dev/tty 仍连着键盘;纯自动化/cron 则两者都没有)
has_tty() { [ -t 0 ] || { [ -e /dev/tty ] && (exec </dev/tty) 2>/dev/null; }; }
env_saved() { grep -E "^$1=" "$INSTALL_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2- || true; }
press_enter() {
  if [ -t 0 ]; then read -rp "$1" REPLY || true
  elif [ -e /dev/tty ]; then read -rp "$1" REPLY < /dev/tty 2>/dev/null || true
  fi
}

# ---- 管理菜单用的两个功能:状态一览 / 一键备份 ----
menu_status() {
  cd "$INSTALL_DIR"
  local d; d="$(env_saved MATRIX_DOMAIN)"
  echo ""
  echo "── 当前配置 ──"
  echo "  域名: ${d:-未知}   注册: $(env_saved REG_MODE)   通话: $([ "$(env_saved ENABLE_CALLS)" = "0" ] && echo 关 || echo 开)   联邦: $([ "$(env_saved ENABLE_FEDERATION)" = "1" ] && echo 开 || echo 关)"
  echo "── 容器状态 ──"
  docker compose ps 2>/dev/null || true
  echo "── 资源占用 ──"
  local diskpct diskfree datasz mediasz
  diskpct="$(df . 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')"; diskpct="${diskpct:-0}"
  diskfree="$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  datasz="$(du -sh data 2>/dev/null | cut -f1)"
  mediasz="$(du -sh data/synapse/media_store 2>/dev/null | cut -f1)"
  if [ "$diskpct" -ge 90 ] 2>/dev/null; then
    printf '  数据: %s   媒体: %s   磁盘剩余: %s   %s磁盘已用 %s%%,偏高,建议菜单选 7 清理%s\n' \
      "${datasz:-?}" "${mediasz:-0}" "${diskfree:-?}" "$C_RED" "$diskpct" "$C_RESET"
  else
    printf '  数据: %s   媒体: %s   磁盘剩余: %s   %s磁盘已用 %s%%%s\n' \
      "${datasz:-?}" "${mediasz:-0}" "${diskfree:-?}" "$C_GREEN" "$diskpct" "$C_RESET"
  fi
  free -h 2>/dev/null | awk 'NR<=2{print "  "$0}' || true
  echo "── 在线检查 ──"
  if curl -4 -fsS --max-time 8 "https://matrix.${d}/_matrix/client/versions" >/dev/null 2>&1; then
    ok "https://matrix.${d} 正常(证书有效,服务在线)"
  else
    warn "matrix.${d} 当前无法访问 —— 排查: docker compose logs --tail 30 caddy"
  fi
  echo "  账号凭据: $INSTALL_DIR/CREDENTIALS.txt"
}

menu_backup() {
  cd "$INSTALL_DIR"
  local ts f; ts="$(date +%F-%H%M%S)"; f="$INSTALL_DIR/matrix-backup-$ts.tar.gz"
  umask 077   # 备份含全部密钥,生成的中间文件与压缩包仅 root 可读
  echo "==> 导出数据库…"
  if ! docker compose exec -T postgres pg_dump -U synapse synapse 2>/dev/null | gzip > "db-backup-$ts.sql.gz"; then
    warn "数据库导出失败(服务未运行?),将只备份密钥与配置"
  fi
  echo "==> 打包密钥+配置+数据库(聊天媒体文件较大不包含,在 data/synapse/media_store)…"
  tar czf "$f" .env CREDENTIALS.txt "db-backup-$ts.sql.gz" \
      data/synapse/*.signing.key data/synapse/homeserver.yaml 2>/dev/null || true
  chmod 600 "$f" 2>/dev/null || true
  rm -f "db-backup-$ts.sql.gz"
  if [ -s "$f" ]; then
    ok "备份完成: $f($(du -h "$f" | cut -f1))"
    echo "  下载到自己电脑(在你电脑的终端执行):"
    echo "    scp root@服务器IP:$f ~/Desktop/"
  else
    warn "备份失败"
  fi
}

# ---- 磁盘守卫 / 媒体清理 ----
# 安全清理:只回收 Docker 冗余镜像与构建缓存,永远不删你自己用户上传的文件。
menu_cleanup() {
  cd "$INSTALL_DIR"
  local before after freed rdays
  rdays="$(env_saved REMOTE_MEDIA_DAYS)"; rdays="${rdays:-14}"
  echo ""
  echo "── 磁盘 / 媒体 用量 ──"
  printf '  安装目录合计: %s    磁盘剩余: %s\n' "$(du -sh . 2>/dev/null | cut -f1)" "$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  printf '  ├ 数据库:   %s\n' "$(du -sh data/postgres 2>/dev/null | cut -f1)"
  printf '  └ 媒体文件: %s\n' "$(du -sh data/synapse/media_store 2>/dev/null | cut -f1)"
  echo ""
  echo "开始安全清理(仅回收 Docker 冗余镜像与构建缓存,不动你任何用户的文件)…"
  before="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  docker image prune -f   >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
  after="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  if [ -n "$before" ] && [ -n "$after" ] && [ "$after" -gt "$before" ] 2>/dev/null; then
    freed=$(( (after - before) / 1024 ))
    ok "清理完成,释放约 ${freed} MB(磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。"
  else
    ok "清理完成(暂无可回收冗余,磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。"
  fi
  echo ""
  echo "关于媒体:"
  echo "  · 远端缓存媒体:Synapse 已按 ${rdays} 天自动清理,无需手动。"
  echo "  · 本地文件(你自己用户上传的):默认【永久保留】,清理绝不碰它们。"
  printf '    如确需按期删除本地旧文件(%s会永久删除,慎用%s),执行:\n' "$C_RED" "$C_RESET"
  echo "      LOCAL_MEDIA_DAYS=180 sudo -E bash $INSTALL_DIR/matrix-installer.sh config"
}

# cron 每日调用:磁盘偏高(≥80%)时自动回收 Docker 冗余并记日志。永不删用户文件、无需交互。
disk_guard() {
  cd "$INSTALL_DIR" 2>/dev/null || return 0
  local pct log; log="$INSTALL_DIR/diskguard.log"
  pct="$(df . 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')"; pct="${pct:-0}"
  [ "$pct" -ge 80 ] 2>/dev/null || return 0
  {
    echo "[$(date '+%F %T')] 磁盘已用 ${pct}% ≥ 80%,自动回收 Docker 冗余…"
    docker image prune -f   2>&1 | tail -n1
    docker builder prune -f 2>&1 | tail -n1
    df -h . | awk 'NR==2{print "  回收后:剩余 "$4",已用 "$5}'
  } >> "$log" 2>&1
  tail -n 200 "$log" > "$log.tmp" 2>/dev/null && mv -f "$log.tmp" "$log" 2>/dev/null || true
}

# 非 root 时自动提权(有脚本文件用 sudo 重跑;curl|bash 无文件则提示)
if [ "$(id -u)" -ne 0 ]; then
  if [ -f "${0:-}" ] && command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  fi
fi
command -v apt-get >/dev/null 2>&1 \
  || die "本脚本仅支持 Ubuntu / Debian 系统。买服务器时请选 Ubuntu 22.04 或 24.04 镜像"

# 提前解析脚本自身绝对路径(必须在任何 cd 之前,供后续自拷贝)
SELF_SRC=""
if [ -f "${0:-}" ]; then
  SELF_SRC="$(cd "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"
fi

# ---------------------------------------------------------------------
# 子命令: diskguard —— 磁盘守卫(cron 每日调用,免交互;磁盘偏高才清 Docker 冗余)
# ---------------------------------------------------------------------
if [ "${1:-}" = "diskguard" ]; then
  disk_guard
  exit 0
fi

# ---------------------------------------------------------------------
# 子命令: cleanup —— 手动清理磁盘 / 查看媒体用量(安全,不删用户文件)
# ---------------------------------------------------------------------
if [ "${1:-}" = "cleanup" ]; then
  [ -d "$INSTALL_DIR" ] || die "找不到 $INSTALL_DIR,先完成部署"
  menu_cleanup
  exit 0
fi

# ---------------------------------------------------------------------
# 子命令: adduser —— 交互式添加成员
# ---------------------------------------------------------------------
if [ "${1:-}" = "adduser" ]; then
  [ -t 0 ] || die "adduser 需要交互终端,请直接在 SSH 里执行: bash matrix-installer.sh adduser"
  [ "$(id -u)" -eq 0 ] || die "adduser 需要 root: sudo bash matrix-installer.sh adduser"
  cd "$INSTALL_DIR" 2>/dev/null || die "找不到 $INSTALL_DIR,先完成部署"
  docker compose ps --status running -q synapse 2>/dev/null | grep -q . \
    || die "Synapse 未运行。先执行: cd $INSTALL_DIR && docker compose up -d"
  echo "提示: 问到 'Make admin' 时,普通成员直接回车;要管理员权限则输入 yes"
  exec docker compose exec synapse register_new_matrix_user \
    -c /data/homeserver.yaml http://localhost:8008
fi

# ---------------------------------------------------------------------
# 子命令: uninstall —— 彻底卸载(危险操作,双重确认)
# ---------------------------------------------------------------------
if [ "${1:-}" = "uninstall" ]; then
  [ -t 0 ] || die "uninstall 必须在交互终端里执行(防误删)"
  [ -d "$INSTALL_DIR" ] || die "没有找到安装目录 $INSTALL_DIR,无需卸载"
  # 安全护栏:只允许删除"确实是本脚本部署的目录",且绝不碰危险路径
  INSTALL_DIR="$(readlink -f -- "$INSTALL_DIR" 2>/dev/null || echo "$INSTALL_DIR")"
  case "$INSTALL_DIR" in
    ""|/|/root|/home|/usr|/etc|/var|/bin|/boot|/lib*|/opt|/srv|/sys|/proc|/dev)
      die "拒绝删除危险路径 [$INSTALL_DIR]。uninstall 只删除脚本创建的独立安装目录" ;;
  esac
  grep -q "$MARKER" "$INSTALL_DIR/data/synapse/homeserver.yaml" 2>/dev/null \
    || die "[$INSTALL_DIR] 不像是本脚本部署的目录(缺少标识),拒绝删除。"
  UN_DOMAIN="$(grep -E '^MATRIX_DOMAIN=' "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- || true)"

  cat <<EOF

┌──────────────────────────────────────────────────────────┐
│  ⚠️  彻底卸载 Matrix 服务器${UN_DOMAIN:+($UN_DOMAIN)}
└──────────────────────────────────────────────────────────┘
将会永久删除(无法恢复!):
  · 全部聊天记录、图片视频文件
  · 全部用户账号与密钥
  · 数据库、证书、所有配置($INSTALL_DIR 整个目录)
保留不动:Docker 本体、系统防火墙规则、swap。

强烈建议先备份!备份命令(先按 Ctrl+C 退出卸载再执行):
  cd $INSTALL_DIR && docker compose exec -T postgres pg_dump -U synapse synapse | gzip > db-backup.sql.gz
  tar czf ~/matrix-backup.tar.gz -C $INSTALL_DIR .env CREDENTIALS.txt db-backup.sql.gz data/synapse

EOF
  read -rp "第 1 次确认:真的要卸载吗?输入 yes 继续: " R1 || exit 1
  [ "$R1" = "yes" ] || { echo "已取消,什么都没动。"; exit 0; }
  if [ -n "$UN_DOMAIN" ]; then
    read -rp "第 2 次确认:请输入你的域名【$UN_DOMAIN】以确认删除: " R2 || exit 1
    [ "$R2" = "$UN_DOMAIN" ] || { echo "域名不匹配,已取消,什么都没动。"; exit 0; }
  else
    read -rp "第 2 次确认:请输入大写 DELETE 以确认删除: " R2 || exit 1
    [ "$R2" = "DELETE" ] || { echo "输入不匹配,已取消,什么都没动。"; exit 0; }
  fi

  echo "==> 停止并移除容器…"
  ( cd "$INSTALL_DIR" && docker compose down --remove-orphans ) 2>/dev/null || true
  echo "==> 删除全部数据与配置…"
  rm -rf "$INSTALL_DIR"
  echo ""
  echo "✅ 卸载完成。$INSTALL_DIR 已删除,容器已移除。"
  echo "   如需连 Docker 镜像也清掉: docker image prune -a"
  echo "   如需重新安装:重新运行本脚本即可。"
  exit 0
fi

# ---------------------------------------------------------------------
# 子命令: config —— 修改已部署实例的配置(注册方式/通话/联邦)
# 走与安装相同的生成流程,但重新询问三个选项(回车=保持当前值)
# ---------------------------------------------------------------------
RECONFIG=0
if [ "${1:-}" = "config" ]; then
  RECONFIG=1
  set --   # 清空参数,域名从已有配置读取
fi

# ---------------------------------------------------------------------
# 0. 参数与基础环境
# ---------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "需要 root 权限。请用: sudo bash matrix-installer.sh 域名  (网站管道方式: curl -fsSL 网址 | sudo bash -s -- 域名)"

# 已完成的部署:有终端 → 打开管理菜单;无终端(自动化)→ 只做重启
if [ "$RECONFIG" -eq 0 ] && [ -f "$INSTALL_DIR/CREDENTIALS.txt" ] \
   && grep -q "$MARKER" "$INSTALL_DIR/data/synapse/homeserver.yaml" 2>/dev/null; then
  cd "$INSTALL_DIR"
  SELF_BIN="$INSTALL_DIR/matrix-installer.sh"
  if [ ! -f "$SELF_BIN" ] && [ -f "${0:-}" ]; then cp -f "$0" "$SELF_BIN" 2>/dev/null || true; fi

  if has_tty; then
    MENU_DOMAIN="$(env_saved MATRIX_DOMAIN)"
    while :; do
      cat <<EOF

┌──────────────────────────────────────────────┐
│  Matrix 管理菜单   ${MENU_DOMAIN:-}
└──────────────────────────────────────────────┘
  1) 查看运行状态
  2) 添加团队成员
  3) 修改配置(注册 / 通话 / 联邦 / 留存)
  4) 立即备份(数据库 + 密钥 + 配置)
  5) 升级到最新版本
  6) 重启所有服务
  7) 清理磁盘 / 媒体
  8) 彻底卸载
  0) 退出
EOF
      MCHOICE=""
      if [ -t 0 ]; then read -rp "请选择 [0-8]: " MCHOICE || exit 0
      else read -rp "请选择 [0-8]: " MCHOICE < /dev/tty 2>/dev/null || exit 0; fi
      case "$MCHOICE" in
        1) menu_status ;;
        2) if [ -f "$SELF_BIN" ]; then bash "$SELF_BIN" adduser || true
           else warn "缺少脚本副本,手动执行: docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008"; fi ;;
        3) if [ -f "$SELF_BIN" ]; then INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config || true
           else warn "缺少脚本副本,无法进入改配置"; fi ;;
        4) menu_backup ;;
        5) echo "==> 拉取最新镜像并升级…"
           { docker compose pull -q && docker compose up -d --remove-orphans && ok "升级完成"; } \
             || warn "升级失败,查看: docker compose logs --tail 30" ;;
        6) { docker compose up -d && docker compose restart; } >/dev/null 2>&1 \
             && ok "已重启全部服务" || warn "重启失败,查看: docker compose ps" ;;
        7) menu_cleanup ;;
        8) if [ -f "$SELF_BIN" ]; then INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" uninstall || true
           else warn "缺少脚本副本,无法卸载"; fi
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        0|q|Q) echo "再见。"; exit 0 ;;
        *) warn "无效选择,请输入 0-8" ;;
      esac
      press_enter "
按回车返回菜单… "
    done
  fi

  # 无终端(自动化/定时任务):保持原行为,只重启
  warn "检测到已完成的部署($INSTALL_DIR),只做重启,不改任何配置/密钥。"
  docker compose up -d
  RUNNING="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ' || true)"
  RUNNING="${RUNNING:-0}"
  EXPECTED=5
  grep -q '^ENABLE_CALLS=0' "$INSTALL_DIR/.env" 2>/dev/null && EXPECTED=3
  if [ "$RUNNING" -ge "$EXPECTED" ]; then
    echo "✓ $EXPECTED 个服务全部运行中。账号信息见 $INSTALL_DIR/CREDENTIALS.txt"
  else
    warn "只有 $RUNNING/$EXPECTED 个服务在运行,排查:"
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
if [ "$RECONFIG" -eq 1 ]; then
  DOMAIN="$(normalize_domain "$(env_saved MATRIX_DOMAIN)")"
  [ -n "$DOMAIN" ] || die "未找到已部署的配置($INSTALL_DIR/.env)。config 只能在完成安装的服务器上使用"
  echo "修改配置: $DOMAIN(密钥/账号/聊天数据全部保持不变)"
fi
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
ADMIN_HOST="admin.$DOMAIN"     # 自托管管理后台(Ketesa=admin.etke.cc 同款)
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
# 安装选项(回车 = 推荐默认;重跑时自动沿用上次选择;可用环境变量预设)
# ---------------------------------------------------------------------
env_saved() { grep -E "^$1=" "$INSTALL_DIR/.env" 2>/dev/null | head -1 | cut -d= -f2- || true; }
ask_opt() {  # $1=提示 $2=默认值 → 结果放入 REPLY
  REPLY=""
  if [ -t 0 ]; then read -rp "$1" REPLY || true
  elif [ -e /dev/tty ]; then read -rp "$1" REPLY < /dev/tty 2>/dev/null || true
  fi
  [ -n "$REPLY" ] || REPLY="$2"
}

# 记录哪些选项是用户用环境变量显式指定的(config 模式免交互的依据)
EXPLICIT_OPTS=0
[ -n "${REG_MODE:-}${ENABLE_CALLS:-}${ENABLE_FEDERATION:-}${MSG_RETENTION_DAYS:-}${LOCAL_MEDIA_DAYS:-}" ] && EXPLICIT_OPTS=1

REG_MODE="${REG_MODE:-$(env_saved REG_MODE)}"
ENABLE_CALLS="${ENABLE_CALLS:-$(env_saved ENABLE_CALLS)}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-$(env_saved ENABLE_FEDERATION)}"
MSG_RETENTION_DAYS="${MSG_RETENTION_DAYS:-$(env_saved MSG_RETENTION_DAYS)}"
# 媒体保留天数(磁盘守卫):远端缓存默认 14 天自动清;本地文件默认空=永久保留
REMOTE_MEDIA_DAYS="${REMOTE_MEDIA_DAYS:-$(env_saved REMOTE_MEDIA_DAYS)}"; REMOTE_MEDIA_DAYS="${REMOTE_MEDIA_DAYS:-14}"
LOCAL_MEDIA_DAYS="${LOCAL_MEDIA_DAYS:-$(env_saved LOCAL_MEDIA_DAYS)}"

# 各选项的"回车默认值"(全新安装=推荐值;config 模式=当前值)
DEF_REG="1"; DEF_CALLS="Y"; DEF_FED="N"; DEF_RET="0"
if [ "$RECONFIG" -eq 1 ] && [ "$EXPLICIT_OPTS" -eq 0 ]; then
  has_tty || die "config 需要交互终端;或用环境变量静默修改,如: ENABLE_CALLS=0 sudo -E bash matrix-installer.sh config"
  case "$REG_MODE" in token) DEF_REG=2 ;; open) DEF_REG=3 ;; *) DEF_REG=1 ;; esac
  [ "$ENABLE_CALLS" = "0" ] && DEF_CALLS="n" || DEF_CALLS="Y"
  [ "$ENABLE_FEDERATION" = "1" ] && DEF_FED="y" || DEF_FED="N"
  case "$MSG_RETENTION_DAYS" in ''|0) DEF_RET="0" ;; *) DEF_RET="$MSG_RETENTION_DAYS" ;; esac
  echo ""
  echo "当前配置: 注册[$REG_MODE] · 通话[$([ "$ENABLE_CALLS" = "1" ] && echo 开启 || echo 关闭)] · 联邦[$([ "$ENABLE_FEDERATION" = "1" ] && echo 开启 || echo 关闭)] · 留存[$({ [ -n "$MSG_RETENTION_DAYS" ] && [ "$MSG_RETENTION_DAYS" != 0 ]; } && echo "${MSG_RETENTION_DAYS}天" || echo 永久)]"
  echo "下面重新选择,直接回车 = 保持当前值。"
  REG_MODE=""; ENABLE_CALLS=""; ENABLE_FEDERATION=""; MSG_RETENTION_DAYS=""
fi

if has_tty && { [ -z "$REG_MODE" ] || [ -z "$ENABLE_CALLS" ] || [ -z "$ENABLE_FEDERATION" ] || [ -z "$MSG_RETENTION_DAYS" ]; }; then
  cat <<EOF

${C_B}${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 安装选项:共 4 个,每个都有大白话说明。
 看不懂或拿不准 → 直接按回车,用推荐值(已是商业保密最安全组合)。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

  if [ -z "$REG_MODE" ]; then
    printf '\n%s【选项 1/4】注册方式%s —— 决定"谁有资格在你的服务器上开账号"\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'

  [1] 关闭注册(推荐)
      作用: 服务器不存在"注册"入口,账号只能由管理员亲手创建。
      好处: 外人连门都摸不到,员工离职即删号,商业环境最安全。
      风险: 无。代价只是新成员要找管理员开号(一条命令的事)。

  [2] 邀请码注册
      作用: 你生成邀请码发给谁,谁才能自己注册。
      好处: 成员多时不用逐个建号,发码即可。
      风险: 邀请码一旦外泄,拿到码的陌生人就能进来 —— 记得发完即作废。

  [3] 完全开放注册
      作用: 互联网上任何人都可以注册你的服务器。
      好处: 仅当你想运营一个对公众开放的社区时才有意义。
      风险: 极高!垃圾账号灌爆、内容失控、服务器资源被白嫖,
            商业用途绝对不要选这个。
EOF
    ask_opt "→ 你的选择 [1/2/3,直接回车=$DEF_REG]: " "$DEF_REG"
    case "$REPLY" in
      2) REG_MODE=token ;;
      3) REG_MODE=open; warn "已选择开放注册 —— 请务必知晓上述风险!" ;;
      *) REG_MODE=closed ;;
    esac
  fi

  if [ -z "$ENABLE_CALLS" ]; then
    printf '\n%s【选项 2/4】语音/视频通话%s —— 要不要安装"打电话/开会"的组件\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'

  [Y] 开启(推荐)
      作用: 支持一对一通话和多人视频会议,画面声音端到端加密,
            媒体流只经过你自己的服务器,不经任何第三方。
      好处: 团队开会不再用腾讯会议/Zoom 之类的外部平台,会议内容不外流。
      风险: 无安全风险。代价是多占约 300MB 内存,防火墙多开 2 个端口。

  [n] 关闭
      作用: 只保留文字聊天和文件互传。
      好处: 服务器内存吃紧(1GB)时更稳;需要的域名解析也少 2 条。
      风险: 无,以后想要了重装一次即可开启。
EOF
    ask_opt "→ 你的选择 [Y/n,直接回车=$DEF_CALLS]: " "$DEF_CALLS"
    case "$REPLY" in n|N) ENABLE_CALLS=0 ;; *) ENABLE_CALLS=1 ;; esac
  fi

  if [ -z "$ENABLE_FEDERATION" ]; then
    printf '\n%s【选项 3/4】联邦互通%s —— 你的服务器要不要与"外部 Matrix 世界"相连\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'

  说明: Matrix 是个像"邮箱"一样的开放网络,全世界有成千上万台
        Matrix 服务器(如 matrix.org)。"联邦"就是与它们互联互通。

  [N] 关闭,完全封闭(推荐)
      作用: 你的服务器成为一座孤岛,只有你建的账号之间能聊天。
      好处: 外部任何服务器、任何陌生人都无法向你的成员发消息,
            没有骚扰、没有钓鱼、攻击面最小 —— 保护商业机密的首选。
      风险: 无。代价是成员不能和其他 Matrix 服务器上的朋友聊天。

  [y] 开启
      作用: 你的成员可以和 matrix.org 等任意服务器的用户互加互聊。
      好处: 融入全球开放网络,跨公司协作方便。
      风险: 对外暴露面变大;成员可能收到陌生人消息/钓鱼;
            你的服务器名对外部可见。商业保密场景不建议。
EOF
    ask_opt "→ 你的选择 [y/N,直接回车=$DEF_FED]: " "$DEF_FED"
    case "$REPLY" in y|Y) ENABLE_FEDERATION=1 ;; *) ENABLE_FEDERATION=0 ;; esac
  fi

  if [ -z "$MSG_RETENTION_DAYS" ]; then
    printf '\n%s【选项 4/4】消息留存 / 自动销毁%s —— 服务器上的聊天记录保留多久\n' "$C_B$C_CYAN" "$C_RESET"
    cat <<'EOF'

  [0] 永久保留(推荐,回车即选)
      作用: 所有聊天记录一直留在服务器,永不自动删除。
      好处: 律师/商务留档、事后追溯、合规取证都靠它。
      风险: 无。代价是长期占磁盘(可随时到管理菜单第 7 项清理冗余)。

  [输天数] 只留 N 天,超期自动销毁
      作用: 超过 N 天的消息由服务器定期自动清除(阅后即焚式)。
      好处: 数据最小化 —— 泄露或被查时,可暴露的历史更少。
      风险: 到期消息不可恢复!(已同步到成员手机的旧消息,本地可能仍在)
            例:输 90 = 只留 90 天;输 30 = 只留一个月。
EOF
    ask_opt "→ 你的选择 [0=永久,或直接输天数,回车=$DEF_RET]: " "$DEF_RET"
    MSG_RETENTION_DAYS="$REPLY"
  fi
fi
REG_MODE="${REG_MODE:-closed}"
ENABLE_CALLS="${ENABLE_CALLS:-1}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-0}"
# 严格归一为单字符 0/1(任何其他值一律视为关闭),防止异常值/换行注入进 .env
case "$ENABLE_CALLS" in 1) : ;; *) ENABLE_CALLS=0 ;; esac
case "$ENABLE_FEDERATION" in 1) : ;; *) ENABLE_FEDERATION=0 ;; esac
case "$REG_MODE" in closed|token|open) : ;; *) die "REG_MODE 只能是 closed/token/open,收到: $REG_MODE" ;; esac
# 留存/媒体天数:只接受非负整数;非法或空一律回落安全默认(留存 0=永久;本地媒体空=永久)
MSG_RETENTION_DAYS="${MSG_RETENTION_DAYS:-0}"
case "$MSG_RETENTION_DAYS" in ''|*[!0-9]*) MSG_RETENTION_DAYS=0 ;; esac
case "$REMOTE_MEDIA_DAYS" in ''|*[!0-9]*) REMOTE_MEDIA_DAYS=14 ;; esac
case "${LOCAL_MEDIA_DAYS:-}" in *[!0-9]*) LOCAL_MEDIA_DAYS="" ;; esac

# 由选项派生的清单(DNS 记录 / 端口 / 服务数)
if [ "$ENABLE_CALLS" = "1" ]; then
  REQUIRED_HOSTS="$DOMAIN $M_HOST $LK_HOST $RTC_HOST"
  DNS_LINES="      $DOMAIN
      $M_HOST
      $ADMIN_HOST   (管理后台;不加也能装,但后台要它)
      $LK_HOST
      $RTC_HOST"
  PORT_LINE="80/tcp   443/tcp   443/udp   7881/tcp   7882/udp"
  SVC_COUNT=5
else
  REQUIRED_HOSTS="$DOMAIN $M_HOST"
  DNS_LINES="      $DOMAIN
      $M_HOST
      $ADMIN_HOST   (管理后台;不加也能装,但后台要它)"
  PORT_LINE="80/tcp   443/tcp   443/udp"
  SVC_COUNT=3
fi
echo ""
printf '  %s✔ 配置: 注册[%s] · 通话[%s] · 联邦[%s] · 留存[%s]%s\n' "$C_GREEN" \
  "$REG_MODE" \
  "$([ "$ENABLE_CALLS" = "1" ] && echo 开启 || echo 关闭)" \
  "$([ "$ENABLE_FEDERATION" = "1" ] && echo 开启 || echo 关闭)" \
  "$([ "$MSG_RETENTION_DAYS" != 0 ] && echo "${MSG_RETENTION_DAYS}天自动销毁" || echo 永久)" \
  "$C_RESET"

# ---------------------------------------------------------------------
# 向导: 开工前把必须手动做的两件事讲清楚
# ---------------------------------------------------------------------
if has_tty && [ "$RECONFIG" -eq 0 ]; then
  cat <<EOF

${C_CYAN}┌──────────────────────────────────────────────────────────┐
│  Matrix 一键安装向导 · 为商业保密而生                    │
│  聊天/文件/会议全部只存在你自己的服务器,外人无法触达    │
└──────────────────────────────────────────────────────────┘${C_RESET}
接下来全自动完成(约 5-10 分钟):装 Docker → 启动服务 →
自动申请 HTTPS 证书 → 生成全部密码 → 创建管理员 → 给你登录信息。

只有两件事必须你在【网页后台】手动做(脚本替代不了):

 ${C_B}${C_YELLOW}① 域名商后台 → 添加下列 A 记录,全部指向 ${PUBLIC_IP:-本服务器IP}:${C_RESET}
${C_GREEN}$DNS_LINES${C_RESET}

 ${C_B}${C_YELLOW}② 服务器商控制台 → 安全组/防火墙 放行这些端口:${C_RESET}
      ${C_GREEN}$PORT_LINE${C_RESET}
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
  for h in $REQUIRED_HOSTS; do
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
bold "3/9 内存 / Swap / BBR"
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

# ---- BBR 拥塞控制(内核自带,开关即用;对 TCP 有效:网页/App、媒体文件收发、跨境弱网更顺;
#      UDP 语音视频通话不受影响)。容器型 VPS 内核只读时会失败——只警告,绝不影响安装。----
if modprobe tcp_bbr 2>/dev/null \
   || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
  cat > /etc/sysctl.d/99-matrix-bbr.conf <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  { sysctl -p /etc/sysctl.d/99-matrix-bbr.conf || sysctl --system; } >/dev/null 2>&1 || true
  CC_NOW="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
  if [ "$CC_NOW" = "bbr" ]; then
    echo "已启用 BBR 拥塞控制(TCP 传输更顺;重启后依然生效)。"
  else
    warn "BBR 配置已写入但当前生效的是 ${CC_NOW}(容器型 VPS 常见,内核由宿主机管);重启后若仍非 bbr,说明该 VPS 不放开,忽略即可。"
  fi
else
  warn "当前内核不支持 BBR(少见,多为容器型 VPS),已跳过,不影响安装。"
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
    ufw allow 443/udp >/dev/null
    if [ "$ENABLE_CALLS" = "1" ]; then
      ufw allow 7881/tcp >/dev/null; ufw allow 7882/udp >/dev/null
    else
      ufw delete allow 7881/tcp >/dev/null 2>&1 || true
      ufw delete allow 7882/udp >/dev/null 2>&1 || true
    fi
    ufw --force enable >/dev/null
    echo "已放行: SSH(${SSH_PORT}) + ${PORT_LINE}"
  else
    warn "ufw 在当前环境不可用(容器/内核限制),请自行放行端口。"
  fi
else
  warn "ufw 不可用,请自行放行端口。"
fi
if [ "$ENABLE_CALLS" = "1" ]; then
  warn "云服务商控制台的『安全组』也要放行: ${PORT_LINE} —— 漏开 7882/udp = 通话无声音画面!"
else
  warn "云服务商控制台的『安全组』也要放行: ${PORT_LINE}"
  if [ "$RECONFIG" -eq 1 ]; then
    warn "已关闭通话:云安全组里的 7881/tcp、7882/udp 可以去删掉(系统防火墙已自动回收)。"
  fi
fi

# ---------------------------------------------------------------------
# 5. 安装目录与部署状态检测(幂等/断点续装)
# ---------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" || die "无法创建 $INSTALL_DIR"
cd "$INSTALL_DIR" || die "无法进入 $INSTALL_DIR"
INSTALL_DIR="$PWD"

# 把脚本自身留一份在安装目录,以后 adduser/重装直接在这里执行。
# curl|bash 管道模式下没有文件实体,则用 MATRIX_INSTALLER_URL(建站时可设)回源下载。
SELF_DST="$INSTALL_DIR/matrix-installer.sh"
if [ -n "$SELF_SRC" ] && [ "$SELF_SRC" != "$SELF_DST" ]; then
  cp -f "$SELF_SRC" "$SELF_DST" 2>/dev/null || true
elif [ ! -f "$SELF_DST" ] && [ -n "${MATRIX_INSTALLER_URL:-}" ]; then
  curl -fsSL "$MATRIX_INSTALLER_URL" -o "$SELF_DST" 2>/dev/null || true
fi
[ -f "$SELF_DST" ] && HAVE_LOCAL_SCRIPT=1 || HAVE_LOCAL_SCRIPT=0

# 磁盘守卫定时任务:每天 04:30 检查磁盘,偏高(≥80%)才自动回收 Docker 冗余(见 diskguard 子命令)
if [ "$HAVE_LOCAL_SCRIPT" = "1" ] && [ -d /etc/cron.d ]; then
  printf '30 4 * * * root INSTALL_DIR=%s bash %s diskguard >/dev/null 2>&1\n' "$INSTALL_DIR" "$SELF_DST" \
    > /etc/cron.d/matrix-diskguard 2>/dev/null && chmod 644 /etc/cron.d/matrix-diskguard 2>/dev/null || true
fi

OUR_CFG=0
if [ -f data/synapse/homeserver.yaml ] && grep -q "$MARKER" data/synapse/homeserver.yaml 2>/dev/null; then
  OUR_CFG=1
fi

if [ "$RECONFIG" -eq 0 ] && [ "$OUR_CFG" -eq 1 ] && [ -f CREDENTIALS.txt ]; then
  warn "检测到已完成的部署,只做重启,不改任何配置/密钥。"
  docker compose up -d
  RUNNING="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ' || true)"
  RUNNING="${RUNNING:-0}"
  if [ "$RUNNING" -ge "$SVC_COUNT" ]; then
    echo "✓ $SVC_COUNT 个服务全部运行中。账号信息见 $INSTALL_DIR/CREDENTIALS.txt"
  else
    warn "只有 $RUNNING/$SVC_COUNT 个服务在运行,排查:"
    echo "  cd $INSTALL_DIR && docker compose ps"
    echo "  cd $INSTALL_DIR && docker compose logs --tail 50"
  fi
  exit 0
fi
if [ "$OUR_CFG" -eq 1 ] && [ ! -f CREDENTIALS.txt ]; then
  warn "检测到未完成的部署,自动续装(复用已有密钥)。"
fi

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
# 之后生成的所有文件默认权限 0600(仅 root 可读),密钥不再世界可读
umask 077
[ -f .env ] && cp -a .env ".env.bak-$(date +%F-%H%M%S)" 2>/dev/null || true  # 重写前留底,防用户自定义行丢失
env_get() { grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- || true; }
PG_PASS="$(env_get POSTGRES_PASSWORD)";   [ -n "$PG_PASS" ]   || PG_PASS="$(openssl rand -hex 24)"
LK_KEY="$(env_get LIVEKIT_API_KEY)";      [ -n "$LK_KEY" ]    || LK_KEY="API$(openssl rand -hex 6)"
LK_SECRET="$(env_get LIVEKIT_API_SECRET)"; [ -n "$LK_SECRET" ] || LK_SECRET="$(openssl rand -hex 32)"
REG_SECRET="$(env_get REG_SECRET)";       [ -n "$REG_SECRET" ] || REG_SECRET="$(openssl rand -hex 32)"
MACAROON="$(env_get MACAROON)";           [ -n "$MACAROON" ]   || MACAROON="$(openssl rand -hex 32)"
FORM_SECRET="$(env_get FORM_SECRET)";     [ -n "$FORM_SECRET" ] || FORM_SECRET="$(openssl rand -hex 32)"

# 管理后台网页门禁密码(Basic Auth 第一道锁);密码稳定持久,重跑不变
PANEL_PASS="$(env_get PANEL_PASS)";       [ -n "$PANEL_PASS" ] || PANEL_PASS="$(openssl rand -base64 15 | tr -dc 'A-Za-z0-9' | cut -c1-14)"
# 用 caddy 自带工具算 bcrypt 哈希;失败(如镜像拉不动)则不启用面板,绝不写坏 Caddyfile
PANEL_HASH="$(docker run --rm caddy:2 caddy hash-password --plaintext "$PANEL_PASS" 2>/dev/null || true)"
PANEL_ENABLED=0; case "$PANEL_HASH" in \$2*) PANEL_ENABLED=1 ;; *) PANEL_HASH="" ;; esac
[ "$PANEL_ENABLED" = "1" ] && SVC_COUNT=$((SVC_COUNT + 1))

cat > .env <<EOF
# ===== Matrix 一键部署机密文件(勿泄露,勿删除) $(date +%F) =====
MATRIX_DOMAIN=$DOMAIN
POSTGRES_PASSWORD=$PG_PASS
LIVEKIT_API_KEY=$LK_KEY
LIVEKIT_API_SECRET=$LK_SECRET
REG_SECRET=$REG_SECRET
MACAROON=$MACAROON
FORM_SECRET=$FORM_SECRET
PANEL_PASS=$PANEL_PASS
REG_MODE=$REG_MODE
ENABLE_CALLS=$ENABLE_CALLS
ENABLE_FEDERATION=$ENABLE_FEDERATION
MSG_RETENTION_DAYS=$MSG_RETENTION_DAYS
REMOTE_MEDIA_DAYS=$REMOTE_MEDIA_DAYS
LOCAL_MEDIA_DAYS=$LOCAL_MEDIA_DAYS
SYNAPSE_MEM=$SYNAPSE_MEM
POSTGRES_MEM=$POSTGRES_MEM
LIVEKIT_MEM=$LIVEKIT_MEM
EOF
chmod 600 .env

# ---- docker-compose.yml(通用模板,实例参数全走 .env) ----
cat > docker-compose.yml <<'EOF'
name: matrix

# 日志轮转:限制每个容器 json 日志最多 10MB×3 份,防止日志默默撑爆磁盘(磁盘守卫)
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
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
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    volumes:
      - ./data/synapse:/data
    mem_limit: ${SYNAPSE_MEM}
    networks: [internal]

EOF

# 通话相关服务(可选)
if [ "$ENABLE_CALLS" = "1" ]; then
cat >> docker-compose.yml <<'EOF'
  lk-jwt-service:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    restart: unless-stopped
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
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
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
    command: ["--config", "/etc/livekit.yaml"]
    volumes:
      - ./livekit/livekit.yaml:/etc/livekit.yaml:ro
    ports:
      - "7881:7881/tcp"
      - "7882:7882/udp"
    mem_limit: ${LIVEKIT_MEM}
    networks: [internal]

EOF
fi

cat >> docker-compose.yml <<'EOF'
  caddy:
    image: caddy:2
    restart: unless-stopped
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
    depends_on: [synapse]
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
EOF

# 管理后台容器(Ketesa,admin.etke.cc 同款,自托管)。仅静态站,极省内存。
if [ "$PANEL_ENABLED" = "1" ]; then
cat >> docker-compose.yml <<'EOF'

  ketesa:
    image: ghcr.io/etkecc/ketesa:latest
    restart: unless-stopped
    logging: *default-logging
    security_opt: ["no-new-privileges:true"]
    volumes:
      - ./data/ketesa/config.json:/var/public/config.json:ro
    mem_limit: 64m
    networks: [internal]
EOF
fi

cat >> docker-compose.yml <<'EOF'

networks:
  internal:
    driver: bridge
EOF

# ---- Caddyfile ----
# well-known/client 内容按“是否开通话”组装(rtc_foci 只在开通话时下发)
if [ "$ENABLE_CALLS" = "1" ]; then
  CLIENT_WK="{\"m.homeserver\":{\"base_url\":\"https://$M_HOST\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://$RTC_HOST\"}]}"
else
  CLIENT_WK="{\"m.homeserver\":{\"base_url\":\"https://$M_HOST\"}}"
fi

# Ketesa 面板配置:把 homeserver 锁定成面板自己的域名(同源),用户登录连地址都不用填
if [ "$PANEL_ENABLED" = "1" ]; then
  mkdir -p data/ketesa
  # restrictBaseUrl: 锁死到本域名(同源);wellKnownDiscovery=false: 关键!
  # 否则 Ketesa 登录后会按 Synapse 的 well-known 把 admin API 请求"规范化"到
  # matrix.$DOMAIN,而那里 /_synapse/admin/* 被 404 且无 CORS → 前端报 Failed to fetch。
  # 关掉规范化后,所有请求都留在 admin.$DOMAIN,经本域名 /_synapse/* 代理直连 Synapse。
  cat > data/ketesa/config.json <<EOF
{
  "restrictBaseUrl": "https://$ADMIN_HOST",
  "wellKnownDiscovery": false
}
EOF
fi

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
		respond \`$CLIENT_WK\` 200
	}
	handle {
		respond "$DOMAIN — Matrix server" 200
	}
}

$M_HOST {
	# /_synapse/*(含 admin API)跨域放行:浏览器管理后台(自建 admin.$DOMAIN 或官方
	# admin.etke.cc)都要跨域调用它,而 Synapse 自身【不发】CORS 头 → 浏览器必然报
	# "No 'Access-Control-Allow-Origin' header / blocked by CORS policy"。这里给它补上,
	# 并对 OPTIONS 预检直接 204 放行。/_matrix 不在这里加(Synapse 自己会发,重复会冲突)。
	# 安全不变:admin API 每个端点都强制校验管理员 token,无 token 一律 401,拿不到任何数据。
	handle /_synapse/* {
		@options method OPTIONS
		handle @options {
			header Access-Control-Allow-Origin "*"
			header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
			header Access-Control-Allow-Headers "Authorization, Content-Type"
			header Access-Control-Max-Age "600"
			respond 204
		}
		handle {
			reverse_proxy synapse:8008 {
				header_down Access-Control-Allow-Origin "*"
				header_down Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
				header_down Access-Control-Allow-Headers "Authorization, Content-Type"
			}
		}
	}
	handle {
		reverse_proxy synapse:8008
	}
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

# 管理后台域:面板 UI 套 Basic Auth 门禁,API 走 Matrix token(两者都用 Authorization 头,
# 不能同时套 basic_auth 否则 Bearer/Basic 打架——所以 basic_auth 只盖面板静态页,不盖 /_matrix、/_synapse)。
# 面板、API 同源(都在本域名)是理想路径;但即便 config.json 没加载、面板退回跨域调
# matrix.$DOMAIN,v1.4 已在主域名给 /_synapse/* 补了 CORS,照样能通(双保险)。
# 若你只想用官方 admin.etke.cc,这个自建 admin.$DOMAIN 块可有可无——CORS 那道才是关键。
# __PANEL_HASH__ 占位随后 sed 替换成 bcrypt 哈希(哈希含 $,不能直接进 heredoc)。
if [ "$PANEL_ENABLED" = "1" ]; then
cat >> Caddyfile <<EOF

$ADMIN_HOST {
	# 让面板的服务发现停在本域名(同源)。Ketesa 登录后默认会按 well-known 把 admin API
	# "规范化"到 matrix.$DOMAIN,而那里 /_synapse/admin/* 被 404 且 Synapse 不发 CORS
	# → 前端必然 Failed to fetch / Load failed。这里把 base_url 指回本域名,配合
	# config.json 的 wellKnownDiscovery:false,双保险钉死同源,admin API 走下面的代理直连。
	handle /.well-known/matrix/client {
		header Content-Type application/json
		header Access-Control-Allow-Origin *
		respond \`{"m.homeserver":{"base_url":"https://$ADMIN_HOST"}}\` 200
	}
	# config.json 不含机密,单独放行(不套 Basic Auth):确保浏览器一定能加载到
	# restrictBaseUrl/wellKnownDiscovery。它一旦加载失败,面板会退回"用用户名域名猜服务器"
	# 的老路,又被带去 matrix.$DOMAIN 撞 404 —— 这是整套同源方案最关键的一环,务必放行。
	handle /config.json {
		reverse_proxy ketesa:8080
	}
	handle /_matrix/* {
		reverse_proxy synapse:8008
	}
	handle /_synapse/* {
		reverse_proxy synapse:8008
	}
	handle {
		basic_auth {
			admin __PANEL_HASH__
		}
		reverse_proxy ketesa:8080
	}
}
EOF
  sed -i "s|__PANEL_HASH__|$PANEL_HASH|" Caddyfile
fi

# ---- livekit.yaml(仅开通话时生成;webhook 走容器内网,不绕公网) ----
if [ "$ENABLE_CALLS" = "1" ]; then
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
chmod 600 livekit/livekit.yaml
else
  rm -f livekit/livekit.yaml 2>/dev/null || true
fi

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

# 监听资源按选项决定:联邦开→federation;仅通话→openid(通话授权必需);全关→client
if [ "$ENABLE_FEDERATION" = "1" ]; then
  SYN_RESOURCES="client, federation"
elif [ "$ENABLE_CALLS" = "1" ]; then
  SYN_RESOURCES="client, openid"
else
  SYN_RESOURCES="client"
fi

# 重写前备份已有的 homeserver.yaml(保留用户可能的手动改动)
[ -f data/synapse/homeserver.yaml ] && cp -a data/synapse/homeserver.yaml "data/synapse/homeserver.yaml.bak-$(date +%F-%H%M%S)" 2>/dev/null || true

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
      - names: [$SYN_RESOURCES]
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

allow_public_rooms_over_federation: false
EOF

# ---- 通话(Element Call / MatrixRTC)所需开关 ----
if [ "$ENABLE_CALLS" = "1" ]; then
cat >> data/synapse/homeserver.yaml <<EOF

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
EOF
fi

# ---- 注册方式 ----
case "$REG_MODE" in
  token)
    cat >> data/synapse/homeserver.yaml <<EOF

enable_registration: true
registration_requires_token: true
EOF
    ;;
  open)
    cat >> data/synapse/homeserver.yaml <<EOF

enable_registration: true
enable_registration_without_verification: true
# 开放注册的基础滥用防线:限制单 IP 注册速率
rc_registration:
  per_second: 0.05
  burst_count: 3
EOF
    ;;
  *)
    cat >> data/synapse/homeserver.yaml <<EOF

enable_registration: false
EOF
    ;;
esac

# ---- 联邦 ----
if [ "$ENABLE_FEDERATION" != "1" ]; then
cat >> data/synapse/homeserver.yaml <<EOF

# 联邦关闭:不与任何外部服务器互通
federation_domain_whitelist: []
EOF
fi

# ---- 媒体保留(磁盘守卫)----
# 远端缓存媒体:超期由 Synapse 自动清理(安全)。本地文件:默认不写=永久保留,
# 只有显式设了 LOCAL_MEDIA_DAYS 才按期删除你自己用户上传的旧文件(慎用)。
cat >> data/synapse/homeserver.yaml <<EOF

media_retention:
  remote_media_lifetime: ${REMOTE_MEDIA_DAYS}d
EOF
if [ -n "${LOCAL_MEDIA_DAYS:-}" ]; then
cat >> data/synapse/homeserver.yaml <<EOF
  local_media_lifetime: ${LOCAL_MEDIA_DAYS}d
EOF
fi

# ---- 消息留存 / 自动销毁(0=永久保留,不写此段)----
if [ "$MSG_RETENTION_DAYS" != "0" ]; then
cat >> data/synapse/homeserver.yaml <<EOF

# 超过 max_lifetime 的消息由后台任务每天清除一次
retention:
  enabled: true
  default_policy:
    min_lifetime: 1d
    max_lifetime: ${MSG_RETENTION_DAYS}d
  allowed_lifetime_min: 1d
  allowed_lifetime_max: ${MSG_RETENTION_DAYS}d
  purge_jobs:
    - interval: 1d
EOF
fi

chown -R 991:991 data/synapse
# homeserver.yaml / 签名密钥含明文密钥,强制 0600(不依赖 umask,防重跑时 umask 已变)
chmod 600 data/synapse/homeserver.yaml 2>/dev/null || true
chmod 600 data/synapse/*.signing.key 2>/dev/null || true

# ---------------------------------------------------------------------
# 8. 启动 + 证书验收
# ---------------------------------------------------------------------
bold "7/9 启动所有服务(首次拉镜像需几分钟)"
if [ "$RECONFIG" -eq 0 ]; then docker compose pull -q || true; fi
docker compose up -d --remove-orphans
if [ "$RECONFIG" -eq 1 ]; then
  docker compose restart synapse caddy >/dev/null 2>&1 || true
  echo "已按新配置重启核心服务。"
fi

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

RUNNING_NOW="$(docker compose ps --status running -q 2>/dev/null | wc -l | tr -d ' ' || true)"
RUNNING_NOW="${RUNNING_NOW:-0}"
if [ "$RUNNING_NOW" -lt "$SVC_COUNT" ]; then
  warn "当前 $RUNNING_NOW/$SVC_COUNT 个服务在运行,排查: cd $INSTALL_DIR && docker compose ps && docker compose logs --tail 50"
fi

CERT_OK=0
echo "等待 HTTPS 证书签发(首次约 10-60 秒)…"
for i in $(seq 1 36); do
  if curl -4 -fsS --max-time 5 "https://$M_HOST/_matrix/client/versions" >/dev/null 2>&1; then
    if [ "$ENABLE_CALLS" = "1" ]; then
      if curl -4 -fsS --max-time 5 "https://$RTC_HOST/healthz" >/dev/null 2>&1 \
         && curl -4 -fsS -o /dev/null --max-time 5 "https://$LK_HOST" >/dev/null 2>&1; then
        CERT_OK=1
      fi
    else
      CERT_OK=1
    fi
    if [ "$CERT_OK" -eq 1 ]; then echo "✓ HTTPS 已生效(全部域名)"; break; fi
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
bold "9/9 管理员账号"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
ADMIN_OK=0
ADMIN_INFO="   账号:    ${C_B}$ADMIN_USER${C_RESET}
   密码:    ${C_B}${C_GREEN}$ADMIN_PASS${C_RESET}"
if [ -f CREDENTIALS.txt ]; then
  # 已有管理员(config/续跑场景):不动账号,不覆盖凭据
  ADMIN_OK=1
  ADMIN_INFO="   账号密码不变(见 $INSTALL_DIR/CREDENTIALS.txt)"
  echo "已有管理员账号,跳过创建。"
elif [ "$READY" -eq 1 ]; then
  # 密码经 stdin 喂入(省略 -p),避免明文出现在进程列表 argv 里
  if printf '%s\n%s\n' "$ADMIN_PASS" "$ADMIN_PASS" | docker compose exec -T synapse register_new_matrix_user \
       -c /data/homeserver.yaml -u "$ADMIN_USER" -a \
       http://localhost:8008 >/dev/null 2>>install-error.log; then
    ADMIN_OK=1
    rm -f install-error.log 2>/dev/null || true
  fi
fi

if [ "$ADMIN_OK" -eq 1 ] && [ ! -f CREDENTIALS.txt ]; then
  cat > CREDENTIALS.txt <<EOF
==== Matrix 部署凭据  $DOMAIN  $(date '+%F %T') ====
安装目录:      $INSTALL_DIR
管理员账号:    $ADMIN_USER   (完整ID: @$ADMIN_USER:$DOMAIN)
管理员密码:    $ADMIN_PASS
客户端登录:    Element X 里服务器填 $DOMAIN
$([ "$PANEL_ENABLED" = "1" ] && printf '管理后台:      https://%s\n网页门禁密码:  admin / %s   (打开后浏览器先弹的密码框)\n后台登录:      再用管理员 admin / %s 登录' "$ADMIN_HOST" "$PANEL_PASS" "$ADMIN_PASS")
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

CALL_CHECK_LINE=""
[ "$ENABLE_CALLS" = "1" ] && CALL_CHECK_LINE="   curl -s https://$RTC_HOST/healthz -o /dev/null -w '%{http_code}\\n'   # 通话授权,应输出 200"

# 管理后台展示块:自托管 Ketesa(admin.etke.cc 同款),零终端管理
PANEL_BLOCK=""
if [ "$PANEL_ENABLED" = "1" ]; then
  PANEL_BLOCK=" 网页管理后台(admin.etke.cc 同款,自托管在你服务器上):
   打开 ${C_BLUE}https://$ADMIN_HOST${C_RESET}
   ① 浏览器先弹密码框 → 输 admin / ${C_B}${C_GREEN}$PANEL_PASS${C_RESET}
   ② 再用管理员 admin / ${C_B}${C_GREEN}$ADMIN_PASS${C_RESET} 登录 → 管理用户/房间/媒体/注册令牌
   ⚠️ 需给 $ADMIN_HOST 加一条 DNS A 记录指向本服务器(没加则后台暂时打不开,加好后 Caddy 自动签证书)
"
fi

# 管理后台的面板地址(有自托管面板就用它,否则回退到本地命令行提示)
PANEL_URL="$([ "$PANEL_ENABLED" = "1" ] && echo "https://$ADMIN_HOST" || echo "(命令行 adduser)")"

TOKEN_HINT=""
if [ "$REG_MODE" = "token" ]; then
  TOKEN_HINT=" 生成注册邀请码(成员自助注册用):
   打开 $PANEL_URL 用 admin 登录 → Registration tokens → 创建
   成员注册时填邀请码即可(可用浏览器打开 https://app.element.io 注册)
"
fi

DONE_TITLE="🎉 部署完成!"
if [ "$RECONFIG" -eq 1 ]; then DONE_TITLE="🎉 配置修改完成!"; fi

if [ "$ADMIN_OK" -eq 1 ] && [ "$CERT_OK" -eq 1 ]; then
  cat <<EOF

${C_GREEN}========================================================${C_RESET}
 ${C_B}${C_GREEN}$DONE_TITLE${C_RESET}  ${C_B}$DOMAIN${C_RESET}
 (配置: 注册[$REG_MODE] · 通话[$([ "$ENABLE_CALLS" = "1" ] && echo 开 || echo 关)] · 联邦[$([ "$ENABLE_FEDERATION" = "1" ] && echo 开 || echo 关)] · 留存[$([ "$MSG_RETENTION_DAYS" != 0 ] && echo "${MSG_RETENTION_DAYS}天自动销毁" || echo 永久)])

 手机装 Element X,登录:
   服务器:  ${C_B}$DOMAIN${C_RESET}
$ADMIN_INFO
 (凭据存于 $INSTALL_DIR/CREDENTIALS.txt)

$PANEL_BLOCK
 添加团队成员:
   后台(推荐,零终端): ${C_BLUE}$PANEL_URL${C_RESET} → Users → 新建
   或命令行: $ADDUSER_HINT
$TOKEN_HINT
 自检:
   curl -s https://$DOMAIN/.well-known/matrix/client
$CALL_CHECK_LINE
   cd $INSTALL_DIR && docker compose ps    # $SVC_COUNT 个容器都应 running
   浏览器: https://federationtester.matrix.org/#$DOMAIN

 ${C_YELLOW}⚠️ 云安全组记得放行: $PORT_LINE${C_RESET}
${C_GREEN}========================================================${C_RESET}
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
