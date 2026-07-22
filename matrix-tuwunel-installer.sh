#!/usr/bin/env bash
# =====================================================================
#  Matrix 轻量一键安装脚本 · tuwunel 版(通用版 t1.15)
#  Matrix one-command installer · tuwunel edition (Universal t1.15)
#  t1.15:【修复:重跑本地脚本不刷新已装副本】菜单刷新副本用的是 cd 之后的相对 $0,会判存在失败而
#         跳过复制 —— 导致 `bash tuwunel.sh` 重跑后,菜单显示新功能但按下去仍调用 /opt 里的旧副本
#         (典型:选 a『改后台网址』却弹出没有 a 的旧菜单)。改用 cd 前解析好的绝对路径 $SELF_SRC。
#         已装旧版补救:`sudo tuwunel update`(联网拉最新),或 `sudo cp ~/你的.sh /opt/tuwunel/tuwunel-installer.sh`。
#  t1.14:【后台网址可自定义】管理面板子域名不再写死 admin.,可改成 console./manage. 等(ADMIN_SUB=,
#         或新装向导里选)。老服务器更新脚本后,`sudo tuwunel admin-url`(或菜单 a 项)即可改:
#         交互问新子域→提醒先加 DNS→复用 config 重生成 Caddyfile 并重启(只改这一项,数据/账号不动)。
#         改后记得去域名商加  <新子域>.你的域名  的 A 记录(旧的 admin. 记录可删)。
#  t1.13:【双语界面 / Bilingual UI】整个脚本 UI 现支持 English + 简体中文,单源实现:
#         启动时询问语言(Language / 语言: [1] English [2] 中文),或安装时加 LANG_UI=en 直接英文;
#         选择存入 .env(UI_LANG=),菜单/改配置/子命令沿用同一语言;默认(非交互/未选)仍为中文,
#         现有中文体验完全不变。安装向导、DNS/端口指引、进度、部署成功卡、CREDENTIALS.txt、管理菜单、
#         adduser/uninstall/update/备份/隐私/涂销等全部用户可见界面均已双语(内部日志与生成的配置注释保留中文)。
#  t1.12: 安装时新增【是否用了 Cloudflare/CDN】询问(或 CDN=1):选是则放宽 DNS 预检
#         (不再要求解析到本机,避免橙云代理下 DNS 指向 CDN 而卡在预检),并打印 CDN 专属
#         提醒(matrix/媒体主机须走灰云、大文件被 CDN 100MB 上限掐死、关 Bot Fight、Bypass 缓存)。
#  t1.11: 新增【可选·自动定时加密备份】(默认关):`sudo tuwunel autobackup` 开启后,cron
#         每周(或每天)自动做 AES-256 加密备份、自动轮转(留最近 N 个)、满盘自动跳过;
#         密钥存 .backup-key(仅 root),开启时醒目提示务必抄走(否则备份永久打不开)。
#  t1.10:【抗取证/机密最小化】(1) 修复关键缺口:强制新房间默认 E2EE
#        (encryption_enabled_by_default_for_room_type="all";此前不写=客户端没主动加密时消息明文入库);
#        (2) 备份改【AES-256 加密】(可选口令;此前裸 tar.gz 含明文密码是最糟暴露面);
#        (3) 新增 `sudo tuwunel forget-secrets`(菜单 s):涂销磁盘上的明文管理员密码/邀请码 + fstrim。
#  t1.9: 新增【隐私加固 / 元数据最小化】(默认开,PRIVACY=0 可关):真实客户端 IP 不入库
#        (ip_source=connect_info,tuwunel 建设备时无开关可关地记 IP,这是唯一缓解);
#        修复两个危险默认:撤回消息原文默认再留 60 天、管理房留操作流水;关在线状态/输入提示;
#        收紧资料与房间目录暴露面。新增 `sudo tuwunel privacy`(菜单 p):看【删不掉什么】、
#        查加固状态、清容器日志。配置改动带自动回滚(键不被本版接受则还原,不会把服务搞挂)。
#  t1.8: 新增【Element X 手机 App 自助注册】(默认开):开启 tuwunel 内置 OIDC(不用另装 MAS),
#        Element X 就能在一个 App 内注册+登录。注册仍走 UIAA、强制邀请码,不绕过(官方确认);
#        安全前提=本脚本不添加任何上游 IdP。老服务器补开:`sudo tuwunel enable-elementx`;
#        关闭:`disable-elementx`(关后 Element X 仅能密码登录、注册改走网页/管理员建号)。
#  t1.7: 新增【自托管 Web 管理后台 Ketesa】(synapse-admin 官方支持的成熟面板):
#        tuwunel v1.8.1+ 已实现 Synapse 管理 API,面板放 admin.你的域名,可图形化
#        管理用户/房间/媒体/邀请码。tuwunel 全局自带 CORS(源码确认),故 Caddy 不再需
#        要加 CORS(加了反而冲突)。Ketesa 亦为非 root(sws 用户/8080),已同样处理端口与权限。
#        · 老服务器补装:`sudo tuwunel enable-admin` 或菜单第 4 项(只开后台,不动其它)。
#        · "举报事件/被举报用户"两页:tuwunel 未实现该端点,Caddy 空桩返回空列表避免红报错
#          (真举报以消息形式进 admin 房间,不进这两个 API)。
#        · 上线前自动 `caddy validate`,语法错则跳过 caddy 重启,保住老配置不中断整站。
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
#      sudo tuwunel enable-admin    # 【老服务器补装 Web 管理后台 Ketesa】(只开后台,不动其它)
#      sudo tuwunel admin-url       # 【改后台网址】admin. → 别的子域(如 console. ;需先加对应 DNS)
#      sudo tuwunel enable-elementx # 【开 Element X 手机自助注册】(原生OIDC;disable-elementx 关)
#      sudo tuwunel privacy        # 隐私/元数据:看能删什么、查加固状态、清日志
#      sudo tuwunel forget-secrets  # 抗取证:涂销磁盘上的明文密码/邀请码
#      sudo tuwunel autobackup     # 可选:开启每周自动加密备份(含轮转/满盘跳过)
#      sudo tuwunel config          # 改配置    sudo tuwunel uninstall  # 卸载
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
#    ADMIN_SUB=admin            后台子域名(默认 admin;可设 console/manage 等,需加对应 DNS)
#    CDN=1|0                    服务器前是否有 Cloudflare/CDN 代理(默认 0;放宽 DNS 预检)
#    MAX_UPLOAD=4G              单文件上限(默认 4G;支持 K/M/G,内部转字节)
#
#  ★ server_name(你的域名)一旦部署【不可更改】,改了必须清库重来 —— tuwunel 硬限制。
#  脚本可安全重复运行:已完成的部署只做重启;半途失败会自动续装。
#  Required Notice: Copyright (c) 2026 VeilXofficial
# =====================================================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
# 备份【必须】默认放在安装目录之外 —— 卸载是 rm -rf $INSTALL_DIR,
# 备份若躺在里面,"先备份再卸载"这个最合理的操作序列会把备份一起删光。
DEFAULT_BACKUP_DIR="/root/tuwunel-backups"
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

# ---- 双语 UI / Bilingual UI(English + 简体中文;单源。LANG_UI=en 预设,或启动时选择)----
UI_LANG="${LANG_UI:-$(env_saved UI_LANG)}"
case "$UI_LANG" in
  en|zh) : ;;
  *) case "${LC_ALL:-}${LANG:-}" in *[Zz][Hh]*) UI_LANG=zh;; *) UI_LANG="";; esac ;;   # 未设定:locale 含 zh→中文,否则留空待询问
esac
# L "English text" "中文文本" —— 按 UI_LANG 输出;UI_LANG!=en 一律走中文(安全默认)
L(){ if [ "$UI_LANG" = "en" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

# ---- 把 4G / 4.5G / 500M / 800MB / 1T 之类转成字节整数(tuwunel max_request_size 用字节)----
# 注意:必须容忍小数。bash 的 $(( )) 不支持小数,4.5G 会抛算术语法错误,
# 在 set -e 下会让整个安装当场中止 —— 故一律走 awk 算,并对非法/<=0 回落默认 4G。
to_bytes() {
  local v n mult b
  v="$(echo "$1" | tr 'a-z' 'A-Z' | tr -d '[:space:]')"; v="${v%B}"; v="${v%I}"  # 4GB / 4GiB → 4G
  case "$v" in
    *T) n="${v%T}"; mult=1099511627776 ;;
    *G) n="${v%G}"; mult=1073741824 ;;
    *M) n="${v%M}"; mult=1048576 ;;
    *K) n="${v%K}"; mult=1024 ;;
    *)  n="$v";     mult=1 ;;          # 纯数字=字节
  esac
  # 只接受非负数字(至多一个小数点);负号、字母、多个点一律非法
  case "$n" in ''|*[!0-9.]*|*.*.*) echo 4294967296; return ;; esac
  b="$(awk -v n="$n" -v m="$mult" 'BEGIN{ printf "%.0f", n*m }' 2>/dev/null)"
  case "$b" in ''|*[!0-9]*) echo 4294967296; return ;; esac
  # 0 / 溢出到超出 bash 整数范围时也回落默认(0 会让所有上传失败)
  if [ "$b" -gt 0 ] 2>/dev/null; then echo "$b"; else echo 4294967296; fi
}
# 上限写法是否合法(供交互处重问用)。to_bytes 对非法值静默回落默认,
# 那在交互里会变成"用户以为设了 0G,其实是 4G",所以校验要独立且严格。
size_ok() {
  local v n
  v="$(echo "$1" | tr 'a-z' 'A-Z' | tr -d '[:space:]')"; v="${v%B}"; v="${v%I}"
  case "$v" in *T|*G|*M|*K) n="${v%?}" ;; *) n="$v" ;; esac
  case "$n" in ''|*[!0-9.]*|*.*.*) return 1 ;; esac
  awk -v n="$n" 'BEGIN{ exit !(n+0 > 0) }' 2>/dev/null   # 必须 > 0
}
human() {  # 字节 → 人类可读
  local b="$1"
  # 老部署的 .env 里可能没有 MAX_UPLOAD_BYTES,空值会让 [ -ge ] 抛两行英文错误刷在菜单上
  case "$b" in ''|*[!0-9]*) printf '%s' "$(L "not set" 未设置)"; return ;; esac
  # 用 %.10g 而不是整数除法:设了 4.5G 就该显示 4.5G,不能截断成 4G
  if   [ "$b" -ge 1099511627776 ]; then awk -v b="$b" 'BEGIN{printf "%.10gT", b/1099511627776}'
  elif [ "$b" -ge 1073741824 ];    then awk -v b="$b" 'BEGIN{printf "%.10gG", b/1073741824}'
  elif [ "$b" -ge 1048576 ];       then awk -v b="$b" 'BEGIN{printf "%.10gM", b/1048576}'
  else printf '%s%s' "$b" "$(L B 字节)"; fi
}

# ---- 通过 Matrix 注册接口 + 注册令牌建号(引擎无关,不用 --execute/不碰 DB 锁)----
# 用法: register_user <用户名> <密码> <homeserver_url> <注册令牌>
# 返回 0=成功;首个建成的账号因 grant_admin_to_first_user=true 自动成为管理员
# JSON 字符串转义。密码是用户手输的,含 " 或 \ 或制表符时直接拼进 JSON 会生成非法请求体,
# 服务器解析失败 → 注册失败,而报错只会说"用户名已存在/令牌失效",把人引向完全错误的方向。
json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"        # 反斜杠必须最先转,否则会把后面转出来的反斜杠再转一遍
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}
register_user() {
  local u="$1" p="$2" hs="$3" tok="$4" r sess eu ep et es
  eu="$(json_esc "$u")"; ep="$(json_esc "$p")"; et="$(json_esc "$tok")"
  # UIAA 第一步:拿 session
  r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$eu\",\"password\":\"$ep\",\"inhibit_login\":true}" 2>/dev/null || true)"
  case "$r" in *'"user_id"'*) return 0 ;; esac   # 万一无需 UIAA 直接成功
  sess="$(printf '%s' "$r" | grep -o '"session"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "$sess" ] || return 1
  es="$(json_esc "$sess")"
  # 第二步:带注册令牌
  r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$eu\",\"password\":\"$ep\",\"inhibit_login\":true,\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$et\",\"session\":\"$es\"}}" 2>/dev/null || true)"
  case "$r" in
    *'"user_id"'*) return 0 ;;
    *'m.login.dummy'*)   # 部分实现在令牌后还要 dummy 阶段
      r="$(curl -4 -sS --max-time 15 -X POST "$hs/_matrix/client/v3/register" \
            -H 'Content-Type: application/json' \
            -d "{\"username\":\"$eu\",\"password\":\"$ep\",\"inhibit_login\":true,\"auth\":{\"type\":\"m.login.dummy\",\"session\":\"$es\"}}" 2>/dev/null || true)"
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
  echo ""; echo "$(L "── Disk / data usage ──" "── 磁盘 / 数据 用量 ──")"
  printf '  %s: %s    %s: %s\n' "$(L "Install dir total" 安装目录合计)" "$(du -sh . 2>/dev/null | cut -f1)" "$(L "Disk free" 磁盘剩余)" "$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  printf '  %s: %s\n' "$(L "  └ database+media (RocksDB)" "  └ 数据库+媒体(RocksDB)")" "$(du -sh data/tuwunel 2>/dev/null | cut -f1)"
  echo ""; echo "$(L "Safe cleanup (reclaims only redundant Docker images/cache, touches no user files)…" "安全清理(仅回收 Docker 冗余镜像/缓存,不动你任何用户的文件)…")"
  before="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  docker image prune -f >/dev/null 2>&1 || true
  docker builder prune -f >/dev/null 2>&1 || true
  after="$(df -P . 2>/dev/null | awk 'NR==2{print $4}')"
  if [ -n "$before" ] && [ -n "$after" ] && [ "$after" -gt "$before" ] 2>/dev/null; then
    ok "$(L "Cleanup done, freed ~$(( (after-before)/1024 )) MB (disk free $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))." "清理完成,释放约 $(( (after-before)/1024 )) MB(磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。")"
  else ok "$(L "Cleanup done (nothing redundant, disk free $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))." "清理完成(暂无冗余,磁盘剩余 $(df -h . 2>/dev/null | awk 'NR==2{print $4}'))。")"; fi
  echo ""
  warn "$(L "With big files enabled, chat media grows data/tuwunel fast — watch disk. tuwunel has no S3 offload; media is on the local disk." "大文件放开后,聊天媒体会让 data/tuwunel 快速增长,注意磁盘余量。tuwunel 无 S3 卸载,媒体存本地盘。")"
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
  local d asub; d="$(env_saved MATRIX_DOMAIN)"; asub="$(env_saved ADMIN_SUB)"; asub="${asub:-admin}"
  echo ""; echo "$(L "── Current config ──" "── 当前配置 ──")"
  echo "  $(L Domain 域名): ${d:-$(L unknown 未知)}   $(L Reg 注册): $(env_saved REG_MODE)   $(L Federation 联邦): $([ "$(env_saved ENABLE_FEDERATION)" = "1" ] && L on 开 || L off 关)   $(L Calls 通话): $([ "$(env_saved ENABLE_CALLS)" = "1" ] && L on 开 || L off 关)   $(L Web 网页): $([ "$(env_saved ENABLE_WEB)" = "1" ] && L on 开 || L off 关)   $(L Admin 后台): $([ "$(env_saved ENABLE_ADMIN)" = "1" ] && L on 开 || L off 关)   $(L Big-files 大文件): $(human "$(env_saved MAX_UPLOAD_BYTES)")"
  [ "$(env_saved ENABLE_WEB)" = "1" ] && echo "  $(L "Web client:" "网页客户端:") https://${d}$(L "(members register/log in in a browser)" "(成员浏览器直接注册/登录)")"
  [ "$(env_saved ENABLE_ADMIN)" = "1" ] && echo "  $(L "Admin panel:" "管理后台: ") https://${asub}.${d}$(L "(admin user/password login, graphical management)" "(管理员账号密码登录,图形化管理)")"
  [ -f /etc/cron.d/tuwunel-backup ] && echo "  $(L "Auto backup:" "自动备份: ") $(L On 已开启)($(grep -oE '#.*' /etc/cron.d/tuwunel-backup 2>/dev/null))" || echo "  $(L "Auto backup:" "自动备份: ") $(L "Off (enable with sudo tuwunel autobackup)" "未开启(sudo tuwunel autobackup 可开)")"
  [ "$(env_saved USE_CDN)" = "1" ] && echo "  $(L "CDN mode:" "CDN 模式:") $(L "flagged (DNS pre-check relaxed; matrix/media must be grey-cloud)" "已标记(DNS 预检放宽;matrix/媒体须灰云)")"
  echo "  $(L "Phone signup (Element X):" "手机App注册(Element X):") $([ "$(env_saved ENABLE_ELEMENTX)" = "1" ] && L "on (native OIDC, invite token still required)" "开(原生OIDC,注册仍需邀请码)" || L "off (Element X password login only; register via web / admin)" "关(Element X 仅密码登录;注册走网页/管理员建号)")"
  echo "$(L "── Container status ──" "── 容器状态 ──")"; docker compose ps 2>/dev/null || true
  echo "$(L "── Resource usage ──" "── 资源占用 ──")"
  local pct; pct="$(df . 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')"; pct="${pct:-0}"
  printf '  %s: %s   %s: %s   ' "$(L "Data (db+media)" "数据(库+媒体)")" "$(du -sh data/tuwunel 2>/dev/null | cut -f1)" "$(L "Disk free" 磁盘剩余)" "$(df -h . 2>/dev/null | awk 'NR==2{print $4}')"
  if [ "$pct" -ge 90 ] 2>/dev/null; then printf '%s%s%s\n' "$C_RED" "$(L "Disk used $pct% — high, use menu 6 to clean" "磁盘已用 $pct%,偏高,菜单选 6 清理")" "$C_RESET"
  else printf '%s%s%s\n' "$C_GREEN" "$(L "Disk used $pct%" "磁盘已用 $pct%")" "$C_RESET"; fi
  free -h 2>/dev/null | awk 'NR<=2{print "  "$0}' || true
  echo "$(L "── Online check ──" "── 在线检查 ──")"
  if curl -4 -fsS --max-time 8 "https://matrix.${d}/_matrix/client/versions" >/dev/null 2>&1; then
    ok "$(L "https://matrix.${d} OK (valid cert, service online)" "https://matrix.${d} 正常(证书有效,服务在线)")"
  else warn "$(L "matrix.${d} not reachable yet — debug: docker compose logs --tail 30" "matrix.${d} 暂不可访问 —— 排查: docker compose logs --tail 30")"; fi
  echo "  $(L Credentials: 凭据:) $INSTALL_DIR/CREDENTIALS.txt"
}
menu_privacy() {
  cd "$INSTALL_DIR" 2>/dev/null || { warn "$(L "Deployment directory not found" "未找到部署目录")"; return; }
  printf '%s\n' "$(L '
── Privacy / metadata: first, what CANNOT be deleted (no false comfort) ──
  End-to-end encryption protects "content"; the following is structural metadata the
  server needs to run — deleting it breaks the server:
    · Room membership (who is in which room, who invited whom) — kept even if history is purged
    · Event graph & timestamps (each message id / ordering / send time)
    · Device list and the timing of E2EE key uploads
    · Account existence, creation time, display name/avatar
  Beyond the server''s reach: local copies on members'' phones/computers, the Apple/Google
  push servers relaying notifications, and your own backups (which contain what you just purged).
  ⚠️ tuwunel has no "auto-destruct messages" feature (MSC1763 not implemented) — do not promise the server auto-deletes messages.' '
── 隐私 / 元数据:先说【删不掉的】(不给你假安全感)──
  端到端加密保护的是"内容";下面这些是服务器运行必须的结构性元数据,删了就无法工作:
    · 房间成员关系(谁在哪个房间、谁邀请谁)—— 清历史也会保留状态事件
    · 事件图与时间戳(每条消息的 id/前后关系/发送时刻)
    · 设备清单与 E2EE 密钥的上传时序
    · 账号存在性、创建时间、昵称/头像
  服务器管不到的地方:成员手机/电脑上的本地副本、推送经过的苹果/谷歌服务器、
  以及你自己的备份包(备份里含有你刚清掉的数据)。
  ⚠️ tuwunel 没有"消息定时自动销毁"功能(未实现 MSC1763),别对外承诺服务器会自动销毁消息。')"
  echo ""
  echo "$(L "── Current hardening status (reads tuwunel.toml) ──" "── 当前加固状态(读 tuwunel.toml)──")"
  _pk(){ if grep -qE "^$1[[:space:]]*=" tuwunel.toml 2>/dev/null; then echo "  ✔ $2"; else echo "  ✘ $2 $(L "(not enabled)" (未启用))"; fi; }
  _pk ip_source                 "$(L "real client IP not stored (ip_source=connect_info)" "真实客户端 IP 不入库(ip_source=connect_info)")"
  _pk save_unredacted_events    "$(L "redaction is a true delete (no 60-day original kept)" "撤回即真删(不再保留 60 天原文)")"
  _pk allow_local_presence      "$(L "presence not recorded" 不记录在线状态)"
  _pk require_auth_for_profile_requests "$(L "profile requires auth" 资料需鉴权)"
  _pk admin_room_notices        "$(L "admin room keeps no action log" 管理房不留操作流水)"
  echo "$(L "  (not enabled? run: PRIVACY=1 sudo -E tuwunel config)" "  (未启用? 执行: PRIVACY=1 sudo -E tuwunel config)")"
  echo ""
  echo "$(L "── Cleanable: container logs (may hold a little IP/request trace) ──" "── 可清理的:容器日志(可能含少量 IP/请求痕迹)──")"
  local tot=0 pth
  for c in $(docker compose ps -q 2>/dev/null); do
    pth="$(docker inspect --format='{{.LogPath}}' "$c" 2>/dev/null)"
    [ -n "$pth" ] && [ -f "$pth" ] && tot=$((tot + $(stat -c%s "$pth" 2>/dev/null || echo 0)))
  done
  echo "$(L "  Current container logs total: $(( tot / 1024 )) KB" "  当前容器日志合计: $(( tot / 1024 )) KB")"
  printf "%s" "$(L "  Clear all container logs? [y/N]: " "  清空全部容器日志? [y/N]: ")"
  local R=""; if [ -t 0 ]; then read -r R || R=""; else read -r R < /dev/tty 2>/dev/null || R=""; fi
  case "$R" in
    y|Y)
      for c in $(docker compose ps -q 2>/dev/null); do
        pth="$(docker inspect --format='{{.LogPath}}' "$c" 2>/dev/null)"
        [ -n "$pth" ] && [ -f "$pth" ] && truncate -s 0 "$pth" 2>/dev/null || true
      done
      ok "$(L "Container logs cleared." "容器日志已清空。")" ;;
    *) echo "$(L "  Skipped." "  已跳过。")" ;;
  esac
  echo ""
  echo "$(L "  Note: RocksDB deletes are tombstone-based; space and residual bytes are only truly reclaimed after compaction." "  提示:RocksDB 的删除是「墓碑式」,空间与残留字节要等压缩(compaction)后才真正回收。")"
  echo "$(L "  The only reliable way to destroy data: destroy/reinstall the server disk, and handle your backups." "  彻底销毁数据的唯一可靠方式:销毁/重装服务器磁盘,并处理好备份包。")"
}

menu_forget_secrets() {
  cd "$INSTALL_DIR" 2>/dev/null || { warn "$(L "Deployment directory not found" "未找到部署目录")"; return; }
  local WIPE; WIPE="$(L 'SECURELY WIPED — see your password manager' '已安全销毁 —— 见密码管理器')"
  if [ ! -f CREDENTIALS.txt ]; then ok "$(L "CREDENTIALS.txt does not exist (maybe already wiped)." "CREDENTIALS.txt 不存在(可能已涂销)。")"; else
    if grep -qE 'WIPED|安全销毁' CREDENTIALS.txt 2>/dev/null; then ok "$(L "Credentials file already wiped — no plaintext password/token." "凭据文件已涂销过,无明文密码/令牌。")"; else
      echo "$(L "CREDENTIALS.txt holds the PLAINTEXT admin password + invite token. They are useless at runtime (the password is hashed in the DB, shown here only for you)," "CREDENTIALS.txt 里有【明文管理员密码 + 邀请码】,运行时无用(密码已哈希入库,仅显示用),")"
      echo "$(L "but they are the highest-value target for forensics after a disk image. This wipes those two lines; the file stays (as a deployment marker)." "却是磁盘镜像后被取证\"一击拿走\"的最高价值目标。此操作会把这两行涂掉,文件保留(作部署标记)。")"
      echo "$(L "Copy the admin password / invite token into your password manager FIRST!" "务必先把管理员密码/邀请码抄进密码管理器!")"
      printf "%s" "$(L "Confirm wipe? type yes: " "确认涂销? 输入 yes: ")"; local R=""; if [ -t 0 ]; then read -r R || R=""; else read -r R < /dev/tty 2>/dev/null || R=""; fi
      if [ "$R" = "yes" ]; then
        umask 077
        sed -E "s/^(Admin password:|管理员密码:).*/\\1  ($WIPE)/; s/^(Registration token:|注册令牌:).*/\\1  ($WIPE)/" CREDENTIALS.txt > CREDENTIALS.txt.new 2>/dev/null \
          && cat CREDENTIALS.txt.new > CREDENTIALS.txt && shred -u CREDENTIALS.txt.new 2>/dev/null
        chmod 600 CREDENTIALS.txt 2>/dev/null || true
        ok "$(L "Wiped the password and invite token from CREDENTIALS.txt." "已涂销 CREDENTIALS.txt 里的密码与邀请码。")"
      else echo "$(L "Cancelled." "已取消。")"; return; fi
    fi
  fi
  # 邀请码仍在 tuwunel.toml(令牌注册开着就必须在);彻底移除需改用管理员建号
  if grep -q '^registration_token' tuwunel.toml 2>/dev/null; then
    echo ""
    echo "$(L "Note: the invite token also lives in tuwunel.toml (required at runtime while token registration is on, cannot be removed)." "提示:邀请码同样存在 tuwunel.toml(令牌注册开着时运行必需,无法移除)。")"
    echo "$(L "To take the invite token off disk entirely → turn off self-registration and create accounts as admin:" "要把邀请码也从磁盘彻底拿掉 → 关闭自助注册、改由管理员建号:")"
    echo "$(L "   turn off allow_registration, then create accounts only with sudo tuwunel adduser" "   REG_MODE=admin_only 暂不支持;可执行  allow_registration 关闭后仅用 sudo tuwunel adduser 建号")"
  fi
  echo ""; echo "$(L "==> Running fstrim (hints the SSD to reclaim freed blocks; not a guaranteed wipe)…" "==> 触发 fstrim(提示 SSD 回收已释放块;非保证擦除)…")"
  fstrim -av 2>/dev/null || fstrim / 2>/dev/null || warn "$(L "fstrim unavailable (virtual disk may not support it)" "fstrim 不可用(虚拟盘可能不支持)")"
  echo "$(L "  Note: deletion on SSD/VPS is not a guaranteed physical wipe; the only reliable destruction is LUKS crypto-erase or destroying the disk." "  注:SSD/VPS 上删除不保证物理擦除;彻底销毁只能靠 LUKS 加密擦除或销毁磁盘。")"
}

# ---- 自动定时加密备份(可选;配置编进 cron 行,不污染 .env)----
backup_run() {   # 非交互,供 cron 调用;密钥读 .backup-key,目录/保留数从环境变量取
  cd "$INSTALL_DIR" 2>/dev/null || return 1
  local keyf dir keep ts f raw free log
  log="$INSTALL_DIR/backup.log"; keyf="$INSTALL_DIR/.backup-key"
  [ -f "$keyf" ] || { echo "[$(date '+%F %T')] $(L "no backup key (.backup-key), skipped." "无备份密钥(.backup-key),跳过。")" >> "$log"; return 1; }
  dir="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"; keep="${BACKUP_KEEP:-2}"
  mkdir -p "$dir" 2>/dev/null; chmod 700 "$dir" 2>/dev/null || true
  raw="$(du -sk data/tuwunel 2>/dev/null | cut -f1)"; raw="${raw:-0}"
  free="$(df -Pk "$dir" 2>/dev/null | awk 'NR==2{print $4}')"; free="${free:-0}"
  if [ "$free" -lt "$raw" ] 2>/dev/null; then
    echo "[$(date '+%F %T')] $(L "backup skipped: not enough free space (need ≈${raw}K, have ${free}K) — avoids filling the disk. Clean up / lower the keep count / use an external disk." "跳过备份:剩余空间不足(需≈${raw}K,剩${free}K),避免撑爆盘。请清理/调低保留数/改存外部盘。")" >> "$log"; return 1
  fi
  ts="$(date +%F-%H%M%S)"; f="$dir/tuwunel-backup-$ts.tar.gz.enc"
  docker compose stop tuwunel >/dev/null 2>&1 || true
  ( umask 077; tar czf - .env tuwunel.toml data/tuwunel 2>/dev/null \
      | BKPW="$(cat "$keyf")" openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass env:BKPW -out "$f" 2>/dev/null ) || true
  docker compose start tuwunel >/dev/null 2>&1 || docker compose up -d >/dev/null 2>&1 || true
  chmod 600 "$f" 2>/dev/null || true
  if [ -s "$f" ]; then
    echo "[$(date '+%F %T')] $(L "backup done:" "备份完成:") $f ($(du -h "$f" 2>/dev/null | cut -f1))" >> "$log"
    ls -1t "$dir"/tuwunel-backup-*.tar.gz.enc 2>/dev/null | tail -n +$((keep+1)) | while read -r old; do rm -f "$old"; done
  else
    rm -f "$f" 2>/dev/null; echo "[$(date '+%F %T')] $(L "backup failed (empty file)." "备份失败(空文件)。")" >> "$log"
  fi
  tail -n 200 "$log" > "$log.tmp" 2>/dev/null && mv -f "$log.tmp" "$log" 2>/dev/null || true
}

menu_autobackup() {
  cd "$INSTALL_DIR" 2>/dev/null || { warn "$(L "Deployment directory not found" "未找到部署目录")"; return; }
  local keyf cronf dir keep freq cronline self C R
  keyf="$INSTALL_DIR/.backup-key"; cronf="/etc/cron.d/tuwunel-backup"
  self="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"
  echo ""; echo "$(L "── Scheduled encrypted backup ──" "── 自动定时加密备份 ──")"
  if [ -f "$cronf" ]; then ok "$(L "Current: ON" "当前:已开启")"; grep -oE '#.*' "$cronf" 2>/dev/null | sed 's/^/     /'
  else echo "$(L "  Current: off" "  当前:未开启")"; fi
  echo "$(L "  1) Enable / reset    2) Disable    3) Back up once now    0) Back" "  1) 开启 / 重设    2) 关闭    3) 立即备份一次    0) 返回")"
  C=""; if [ -t 0 ]; then read -rp "$(L "  Select: " "  选择: ")" C || C=""; else read -rp "$(L "  Select: " "  选择: ")" C < /dev/tty 2>/dev/null || C=""; fi
  case "$C" in
    2) rm -f "$cronf" 2>/dev/null; ok "$(L "Auto backup disabled (existing backup files kept)." "已关闭自动备份(已生成的备份文件保留)。")"; return ;;
    3) [ -f "$cronf" ] || { warn "$(L "Not enabled yet — can't back up now. Choose 1 to enable first." "尚未开启,无法立即备份。先选 1 开启。")"; return; }
       echo "$(L "  Backing up (tuwunel pauses briefly)…" "  正在备份(会短暂停一下 tuwunel)…")"
       # 按引号取值,含空格的目录才能完整还原(与上面写 cron 行的引号写法配套)
       BACKUP_DIR="$(sed -n 's/.*BACKUP_DIR="\([^"]*\)".*/\1/p' "$cronf" | head -1)" \
       BACKUP_KEEP="$(sed -n 's/.*BACKUP_KEEP=\([0-9]*\).*/\1/p' "$cronf" | head -1)" backup_run
       tail -n1 "$INSTALL_DIR/backup.log" 2>/dev/null; return ;;
    1) : ;;
    *) return ;;
  esac
  printf "%s" "$(L "  Backup directory [Enter=$DEFAULT_BACKUP_DIR; can be a mounted external disk / object-store path]: " "  备份存放目录 [回车=$DEFAULT_BACKUP_DIR;可填挂载的外部盘/对象存储路径]: ")"
  if [ -t 0 ]; then read -r dir || dir=""; else read -r dir < /dev/tty 2>/dev/null || dir=""; fi
  dir="${dir:-$DEFAULT_BACKUP_DIR}"
  # 路径落在安装目录里 = 卸载时被 rm -rf 一起删掉,这里必须拦住
  case "$dir" in
    "$INSTALL_DIR"|"$INSTALL_DIR"/*)
      warn "$(L "'$dir' is inside the install dir — it would be wiped on uninstall, making the backup pointless. Using $DEFAULT_BACKUP_DIR instead." "『$dir』在安装目录里面 —— 卸载时会被一起删光,备份就白做了。已改用 $DEFAULT_BACKUP_DIR。")"
      dir="$DEFAULT_BACKUP_DIR" ;;
  esac
  printf "%s" "$(L "  Keep how many most-recent [Enter=2]: " "  保留最近几个 [回车=2]: ")"; if [ -t 0 ]; then read -r keep || keep=""; else read -r keep < /dev/tty 2>/dev/null || keep=""; fi
  echo "$keep" | grep -qE '^[0-9]+$' || keep=2
  printf "%s" "$(L "  Frequency [1=weekly (recommended) 2=daily, Enter=1]: " "  频率 [1=每周(推荐) 2=每天,回车=1]: ")"; if [ -t 0 ]; then read -r freq || freq=""; else read -r freq < /dev/tty 2>/dev/null || freq=""; fi
  case "$freq" in 2) cronline="0 4 * * *"; freq="$(L "daily 04:00" 每天04:00)";; *) cronline="0 4 * * 0"; freq="$(L "Sunday 04:00" 每周日04:00)";; esac
  mkdir -p "$dir" 2>/dev/null; chmod 700 "$dir" 2>/dev/null || true
  [ -f "$keyf" ] || { ( umask 077; openssl rand -hex 32 > "$keyf" ); chmod 600 "$keyf"; }
  # 路径必须加引号:含空格的目录(如 /mnt/my backups)会把 cron 命令行切断,
  # 结果是 cron 每次都 "command not found",自动备份一次都不会产生 —— 且用户毫无察觉。
  printf '%s root INSTALL_DIR="%s" BACKUP_DIR="%s" BACKUP_KEEP=%s bash "%s" backup-run >/dev/null 2>&1  #%s %s\n' \
    "$cronline" "$INSTALL_DIR" "$dir" "$keep" "$self" "$freq" "$(L "keep $keep, store $dir" "保留${keep}个 存 $dir")" > "$cronf"
  chmod 644 "$cronf" 2>/dev/null || true
  ok "$(L "Enabled: $freq encrypted backup → $dir (keeps last $keep, auto-skips if disk full)." "已开启:$freq 自动加密备份 → $dir(保留最近 $keep 个,满盘自动跳过)。")"
  echo ""
  printf '  %s%s%s%s\n' "$C_B" "$C_YELLOW" "$(L "⚠️ CRITICAL: below is the backup encryption key — copy it into your password manager NOW!" "⚠️ 极重要:下面是备份加密密钥,现在就抄进密码管理器!")" "$C_RESET"
  echo "  ──────────────────────────────────────────────"
  echo "    $(cat "$keyf")"
  echo "  ──────────────────────────────────────────────"
  printf '%s\n' "$(L "  · Without this key, EVERY backup is permanently unopenable. It exists only on this server —
    if the server is gone and you didn't copy it, all backups are lost. Store it elsewhere now.
  · The local backups dir disappears with the server. Copy the .enc files off regularly:
      scp root@SERVER_IP:$dir/'*.enc' ~/     (or point the dir at a mounted external disk / object store)
  · Decrypt: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:KEY -in backup.enc | tar xzf - -C targetdir" "  · 没有这把密钥,任何备份都【永久打不开】。它现在只存在这台服务器上——
    服务器要是没了、你又没抄下,备份全废。务必现在存到别处。
  · 本机 backups 目录会随服务器一起消失。请把 .enc 定期复制到别处:
      scp root@服务器IP:$dir/'*.enc' ~/     (或把目录设成挂载的外部盘/对象存储)
  · 恢复解密: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:密钥 -in 备份.enc | tar xzf - -C 目标目录")"
  echo ""
  printf "%s" "$(L "  Run one backup now to verify? [Y/n]: " "  现在立即跑一次备份验证? [Y/n]: ")"; R=""; if [ -t 0 ]; then read -r R || R=""; else read -r R < /dev/tty 2>/dev/null || R=""; fi
  case "$R" in n|N) : ;; *) echo "$(L "  Backing up (tuwunel pauses briefly)…" "  备份中(会短暂停一下 tuwunel)…")"; BACKUP_DIR="$dir" BACKUP_KEEP="$keep" backup_run; tail -n1 "$INSTALL_DIR/backup.log" 2>/dev/null ;; esac
}

menu_backup() {
  cd "$INSTALL_DIR"; local ts f pw pw2 bdir; ts="$(date +%F-%H%M%S)"
  # 存到安装目录【之外】,否则卸载时 rm -rf 会把刚做好的备份一起删掉
  bdir="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
  mkdir -p "$bdir" 2>/dev/null; chmod 700 "$bdir" 2>/dev/null || true
  f="$bdir/tuwunel-backup-$ts.tar.gz"
  umask 077
  echo "$(L "Backup contains PLAINTEXT secrets (invite token, config, the whole database, all media). Encrypting before storing/transferring is strongly recommended." "备份含【明文机密】(邀请码、配置、整个数据库、全部媒体)。强烈建议加密后再存/传。")"
  echo "$(L "Set an encryption passphrase (AES-256). Blank = no encryption (at your own risk)." "设一个加密口令(AES-256)。留空=不加密(风险自负)。")"
  printf "%s" "$(L "  Passphrase: " "  加密口令: ")"; pw=""; if [ -t 0 ]; then read -rs pw || pw=""; else read -rs pw < /dev/tty 2>/dev/null || pw=""; fi; echo
  if [ -n "$pw" ]; then
    printf "%s" "$(L "  Again: " "  再输一次: ")"; pw2=""; if [ -t 0 ]; then read -rs pw2 || pw2=""; else read -rs pw2 < /dev/tty 2>/dev/null || pw2=""; fi; echo
    [ "$pw" = "$pw2" ] || { warn "$(L "Passphrases don't match, cancelled." "两次口令不一致,已取消。")"; return; }
    f="$f.enc"
  else
    warn "$(L "Unencrypted! The backup holds the plaintext admin password/invite token — never send it anywhere untrusted." "未加密!备份里有明文管理员密码/邀请码,切勿传到不可信位置。")"
  fi
  echo "$(L "==> Stopping the service to back up RocksDB consistently (packing a live DB may corrupt it)…" "==> 停止服务以一致地备份 RocksDB(库不停止直接打包可能损坏)…")"
  docker compose stop tuwunel >/dev/null 2>&1 || true
  if [ -n "$pw" ]; then
    # 口令走环境变量(不进 argv/ps),openssl 从 stdin 读 tar 流并加密
    tar czf - .env CREDENTIALS.txt tuwunel.toml data/tuwunel 2>/dev/null \
      | BKPW="$pw" openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass env:BKPW -out "$f" 2>/dev/null || true
  else
    tar czf "$f" .env CREDENTIALS.txt tuwunel.toml data/tuwunel 2>/dev/null || true
  fi
  docker compose start tuwunel >/dev/null 2>&1 || docker compose up -d >/dev/null 2>&1 || true
  chmod 600 "$f" 2>/dev/null || true
  if [ -s "$f" ]; then ok "$(L "Backup done: $f($(du -h "$f" | cut -f1))" "备份完成: $f($(du -h "$f" | cut -f1))")"
    echo "$(L "  (outside the install dir; uninstall won't delete it)" "  (存在安装目录之外,卸载不会删掉它)")"
    if [ -n "$pw" ]; then
      echo "$(L "  ⚠️ Lose the passphrase = backup unopenable forever; store it in your password manager." "  ⚠️ 口令丢了 = 备份永久打不开,请存进密码管理器。")"
      echo "$(L "  Decrypt: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:YOURPASS -in \"$(basename "$f")\" | tar xzf - -C targetdir" "  恢复解密: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:你的口令 -in \"$(basename "$f")\" | tar xzf - -C 目标目录")"
    fi
    echo "$(L "  Download to your machine: scp root@$(env_saved PUBLIC_IP | grep . || L YOUR_SERVER_IP 你的服务器IP):$f ~/Desktop/" "  下载到本机: scp root@$(env_saved PUBLIC_IP | grep . || echo 你的服务器IP):$f ~/Desktop/")"
  else warn "$(L "Backup failed" 备份失败)"; fi
}

# 非 root 自动提权
if [ "$(id -u)" -ne 0 ]; then
  if [ -f "${0:-}" ] && command -v sudo >/dev/null 2>&1; then exec sudo -E bash "$0" "$@"; fi
fi
command -v apt-get >/dev/null 2>&1 || die "$(L "This script supports Ubuntu / Debian only. Choose Ubuntu 22.04/24.04 for your server." "本脚本仅支持 Ubuntu / Debian。买服务器请选 Ubuntu 22.04/24.04")"
SELF_SRC=""; [ -f "${0:-}" ] && SELF_SRC="$(cd "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"

# ---------------------------------------------------------------------
# 子命令
# ---------------------------------------------------------------------
if [ "${1:-}" = "diskguard" ]; then disk_guard; exit 0; fi
if [ "${1:-}" = "cleanup" ]; then [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found" "找不到 $INSTALL_DIR")"; menu_cleanup; exit 0; fi
if [ "${1:-}" = "backup-run" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; backup_run; exit 0; fi
if [ "${1:-}" = "autobackup" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; SELF_BIN="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"; menu_autobackup; exit 0; fi

# 子命令: update —— 从 GitHub 拉最新脚本,替换本地副本+全局命令,再自动应用新功能(不动数据)
if [ "${1:-}" = "update" ]; then
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — finish the deployment first" "找不到 $INSTALL_DIR,先完成部署")"
  SELF_DST="$INSTALL_DIR/tuwunel-installer.sh"; tmp="$(mktemp)"
  bold "$(L "Updating script: pulling latest from $REPO_RAW…" "更新脚本:从 $REPO_RAW 拉取最新…")"
  if ! curl -fsSL "$REPO_RAW" -o "$tmp" 2>/dev/null; then
    rm -f "$tmp"; die "$(L "Download failed (network/blocked?). Via a mirror: TUWUNEL_UPDATE_URL=<mirror URL> sudo -E tuwunel update" "下载失败(网络/被墙?)。国内可: TUWUNEL_UPDATE_URL=<加速镜像地址> sudo -E tuwunel update")"
  fi
  # 安全校验:必须是本脚本(含标识)且语法正确,才替换
  if grep -q "$MARKER" "$tmp" && bash -n "$tmp" 2>/dev/null; then
    cp -f "$tmp" "$SELF_DST" 2>/dev/null && chmod +x "$SELF_DST" 2>/dev/null || true
    install_launcher "$SELF_DST"; rm -f "$tmp"
    NEWV="$(grep -m1 -E '通用版 t|Universal t' "$SELF_DST" | grep -oE 't[0-9]+\.[0-9]+' || L unknown 未知)"
    ok "$(L "Script updated to $NEWV." "脚本已更新到 $NEWV。")"
    echo "$(L "==> Applying new config (asks a few options; data/accounts untouched)…" "==> 应用新配置(会问你几个选项,数据/账号一律不动)…")"
    exec bash "$SELF_DST" config
  else
    rm -f "$tmp"; die "$(L "The downloaded file failed validation (error page / tampered mirror?), aborted, nothing changed." "下载到的文件校验不通过(可能是错误页/被镜像篡改),已放弃,未改动任何东西。")"
  fi
fi

if [ "${1:-}" = "adduser" ]; then
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — finish the deployment first" "找不到 $INSTALL_DIR,先完成部署")"
  cd "$INSTALL_DIR"
  D="$(env_saved MATRIX_DOMAIN)"; TOK="$(env_saved REG_TOKEN)"; HS="https://matrix.$D"
  [ -n "$D" ] && [ -n "$TOK" ] || die "$(L "Can't read domain/registration token — deployment may be incomplete" "读不到域名/注册令牌,部署可能未完成")"
  docker compose ps --status running -q tuwunel 2>/dev/null | grep -q . || die "$(L "tuwunel not running: cd $INSTALL_DIR && docker compose up -d" "tuwunel 未运行: cd $INSTALL_DIR && docker compose up -d")"
  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "== Add a team member (create account + set password) ==" "== 添加团队成员(直接建好账号并设密码)==")" "$C_RESET"
  NU=""
  PROMPT_U="$(L "New member username (lowercase alphanumeric, e.g. lisi): " "新成员用户名(小写字母数字,如 lisi): ")"
  if [ -t 0 ]; then read -rp "$PROMPT_U" NU || exit 1
  elif [ -e /dev/tty ]; then read -rp "$PROMPT_U" NU < /dev/tty || exit 1
  else die "$(L "adduser needs an interactive terminal: sudo bash tuwunel-installer.sh adduser" "adduser 需交互终端: sudo bash tuwunel-installer.sh adduser")"; fi
  NU="$(echo "$NU" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
  uname_ok "$NU" || die "$(L "Invalid username (only lowercase alphanumeric and . _ - =)" "用户名不合法(只允许小写字母数字与 . _ - =)")"
  NP=""
  PROMPT_P="$(L "Password (blank = auto-generate a strong one): " "密码(留空=自动生成强密码): ")"
  if [ -t 0 ]; then read -rp "$PROMPT_P" NP || true
  elif [ -e /dev/tty ]; then read -rp "$PROMPT_P" NP < /dev/tty || true; fi
  [ -n "$NP" ] || NP="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  echo "$(L "==> Creating @$NU:$D …" "==> 正在创建 @$NU:$D …")"
  if register_user "$NU" "$NP" "$HS" "$TOK"; then
    ok "$(L "Member created." "成员已创建。")"
    printf '   %s: %s%s%s   %s: %s%s%s\n' "$(L User 账号)" "$C_B" "$NU" "$C_RESET" "$(L Password 密码)" "$C_B$C_GREEN" "$NP" "$C_RESET"
    echo "$(L "   Have them log in with Element: server = $D, using the above." "   让 TA 用 Element 登录:服务器填 $D,用上面账号密码。")"
  else
    warn "$(L "Creation failed. Possibly: username exists, token invalid, or service not ready." "创建失败。可能:该用户名已存在、令牌失效、或服务未就绪。")"
    echo "$(L "   Fallback: send [server $D + registration token $TOK] to the member to self-register;" "   兜底方案:把 [服务器 $D + 注册令牌 $TOK] 发给成员自助注册;")"
    echo "$(L "   or send !admin help in the admin room for commands." "   或在管理员房间发 !admin help 查看命令。")"
  fi
  exit 0
fi

if [ "${1:-}" = "uninstall" ]; then
  [ -t 0 ] || die "$(L "uninstall must run in an interactive terminal (prevents accidents)" "uninstall 必须在交互终端里执行(防误删)")"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found, nothing to uninstall" "没找到 $INSTALL_DIR,无需卸载")"
  INSTALL_DIR="$(readlink -f -- "$INSTALL_DIR" 2>/dev/null || echo "$INSTALL_DIR")"
  case "$INSTALL_DIR" in ""|/|/root|/home|/usr|/etc|/var|/bin|/boot|/lib*|/opt|/srv|/sys|/proc|/dev)
      die "$(L "Refusing to delete dangerous path [$INSTALL_DIR]" "拒绝删除危险路径 [$INSTALL_DIR]")" ;; esac
  grep -q "$MARKER" "$INSTALL_DIR/tuwunel.toml" 2>/dev/null || die "$(L "[$INSTALL_DIR] doesn't look like a directory deployed by this script, refusing to delete." "[$INSTALL_DIR] 不像本脚本部署的目录,拒绝删除。")"
  UN_DOMAIN="$(env_saved MATRIX_DOMAIN)"
  cat <<EOF

┌──────────────────────────────────────────────────────────┐
│  $(L "⚠️  Completely uninstall tuwunel server" "⚠️  彻底卸载 tuwunel 服务器")${UN_DOMAIN:+($UN_DOMAIN)}
└──────────────────────────────────────────────────────────┘
$(L "Will permanently delete (unrecoverable!): all chat history, media, accounts, database, certs, config ($INSTALL_DIR)." "将永久删除(无法恢复!):全部聊天记录、媒体、账号、数据库、证书、配置($INSTALL_DIR)。")

$(L "Automatically KEPT: backups in $DEFAULT_BACKUP_DIR (uninstall doesn't touch it;" "会自动【保留】:$DEFAULT_BACKUP_DIR 里的备份(卸载不碰它;")
$(L "if the install dir still has old backups, they're moved there first)." "若安装目录里还有旧版留下的备份,下面会先搬过去再删)。")

$(L "No backup? Press Ctrl+C now → re-run sudo tuwunel → menu item 5 'Back up now'," "没备份的话:现在按 Ctrl+C 退出 → 重跑 sudo tuwunel → 菜单第 5 项『立即备份』,")
$(L "the backup goes to $DEFAULT_BACKUP_DIR and won't be deleted on uninstall." "备份会存到 $DEFAULT_BACKUP_DIR,卸载时不会被删。")
EOF
  read -rp "$(L "Confirm #1: type yes to continue: " "第 1 次确认:输入 yes 继续: ")" R1 || exit 1
  [ "$R1" = "yes" ] || { echo "$(L "Cancelled." "已取消。")"; exit 0; }
  if [ -n "$UN_DOMAIN" ]; then read -rp "$(L "Confirm #2: type your domain [$UN_DOMAIN]: " "第 2 次确认:输入你的域名【$UN_DOMAIN】: ")" R2 || exit 1
    [ "$R2" = "$UN_DOMAIN" ] || { echo "$(L "No match, cancelled." "不匹配,已取消。")"; exit 0; }
  else read -rp "$(L "Confirm #2: type DELETE in caps: " "第 2 次确认:输入大写 DELETE: ")" R2 || exit 1
    [ "$R2" = "DELETE" ] || { echo "$(L "No match, cancelled." "不匹配,已取消。")"; exit 0; }; fi
  # 抢救安装目录里的历史备份(旧版本的备份就存在这儿,rm -rf 会连它一起删)
  if ls -1 "$INSTALL_DIR"/tuwunel-backup-*.tar.gz* >/dev/null 2>&1 \
     || ls -1 "$INSTALL_DIR"/backups/tuwunel-backup-* >/dev/null 2>&1; then
    mkdir -p "$DEFAULT_BACKUP_DIR" 2>/dev/null; chmod 700 "$DEFAULT_BACKUP_DIR" 2>/dev/null || true
    mv -f "$INSTALL_DIR"/tuwunel-backup-*.tar.gz* "$DEFAULT_BACKUP_DIR"/ 2>/dev/null || true
    mv -f "$INSTALL_DIR"/backups/tuwunel-backup-* "$DEFAULT_BACKUP_DIR"/ 2>/dev/null || true
    ok "$(L "Moved old backups from the install dir to $DEFAULT_BACKUP_DIR (won't be deleted)" "已把安装目录里的旧备份移到 $DEFAULT_BACKUP_DIR(不会被删除)")"
  fi
  ( cd "$INSTALL_DIR" && docker compose down --remove-orphans ) 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  ok "$(L "Uninstall complete. $INSTALL_DIR deleted." "卸载完成。$INSTALL_DIR 已删除。")"
  if ls -1 "$DEFAULT_BACKUP_DIR"/tuwunel-backup-* >/dev/null 2>&1; then
    echo "$(L "   Backups remain in: $DEFAULT_BACKUP_DIR" "   备份仍保留在: $DEFAULT_BACKUP_DIR")"
    echo "$(L "   Decrypt a backup: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:YOURPASS -in backup.enc | tar xzf - -C targetdir" "   解开备份: openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass pass:你的口令 -in 备份.enc | tar xzf - -C 目标目录")"
    echo "$(L "   (unencrypted backup: tar xzf backup.tar.gz -C targetdir)" "   (未加密的备份直接 tar xzf 备份.tar.gz -C 目标目录)")"
  fi
  exit 0
fi

RECONFIG=0
if [ "${1:-}" = "config" ]; then RECONFIG=1; set --; fi
# 子命令: enable-admin / disable-admin —— 给已部署的老服务器单独开/关 Web 管理后台
# (只改后台一项,不动注册/联邦/大文件等,也不问向导;需先加好 admin.域名 的 DNS)
if [ "${1:-}" = "enable-admin" ];  then ENABLE_ADMIN=1; RECONFIG=1; set --; fi
if [ "${1:-}" = "disable-admin" ]; then ENABLE_ADMIN=0; RECONFIG=1; set --; fi
# 子命令: enable-elementx / disable-elementx —— 开/关 Element X 手机App自助注册(tuwunel 原生 OIDC)
# 开:仍强制邀请码(不绕过);关:Element X 只能用密码登录、注册改走网页或管理员建号。
if [ "${1:-}" = "enable-elementx" ];  then ENABLE_ELEMENTX=1; RECONFIG=1; set --; fi
if [ "${1:-}" = "disable-elementx" ]; then ENABLE_ELEMENTX=0; RECONFIG=1; set --; fi
# 子命令: privacy —— 隐私/元数据:看能删什么、当前加固状态、清容器日志
if [ "${1:-}" = "privacy" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; menu_privacy; exit 0; fi
if [ "${1:-}" = "forget-secrets" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; menu_forget_secrets; exit 0; fi
# 子命令: admin-url —— 【老服务器改后台网址】把管理面板子域名 admin. 改成别的(如 console. / manage.)
# 交互问新子域 → 提醒先加 DNS → 复用 config 重生成 Caddyfile 并重启(只改这一项,数据/账号不动)。
if [ "${1:-}" = "admin-url" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — finish the deployment first" "找不到 $INSTALL_DIR,先完成部署")"
  AD="$(env_saved MATRIX_DOMAIN)"; [ -n "$AD" ] || die "$(L "Can't read the domain — deployment may be incomplete" "读不到域名,部署可能未完成")"
  [ "$(env_saved ENABLE_ADMIN)" = "1" ] || { warn "$(L "The admin panel is OFF. Enable it first (sudo tuwunel → 4), then change its URL." "后台未开启。请先开启(sudo tuwunel → 第 4 项),再改网址。")"; exit 0; }
  ACUR="$(env_saved ADMIN_SUB)"; ACUR="${ACUR:-admin}"; AIP="$(env_saved PUBLIC_IP)"
  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "== Change admin panel URL ==" "== 修改后台网址 ==")" "$C_RESET"
  echo "$(L "Current: https://$ACUR.$AD" "当前: https://$ACUR.$AD")"
  ANEW=""
  while :; do
    ask_opt "$(L "→ New subdomain [Enter=$ACUR] (e.g. console / manage): " "→ 新子域名 [回车=$ACUR](如 console / manage): ")" "$ACUR"
    ANEW="$(echo "$REPLY" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
    case "$ANEW" in matrix|livekit|matrix-rtc|www) warn "$(L "'$ANEW' is reserved by another service — pick another." "『$ANEW』被其它服务占用 —— 换一个。")"; has_tty || exit 1; continue;; esac
    echo "$ANEW" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' && break
    warn "$(L "Invalid subdomain — one label only: lowercase letters/digits/hyphen, no dots." "子域名不合法 —— 只能一个标签:小写字母/数字/连字符,不含点。")"
    has_tty || exit 1
  done
  [ "$ANEW" = "$ACUR" ] && { ok "$(L "Unchanged." "未改动。")"; exit 0; }
  echo ""
  warn "$(L "IMPORTANT — add DNS FIRST: an A record for  $ANEW.$AD  →  ${AIP:-your server IP}" "重要 —— 先加 DNS:给  $ANEW.$AD  加一条 A 记录  →  ${AIP:-你的服务器IP}")"
  echo "$(L "(the old record $ACUR.$AD can be removed afterwards)" "(旧的 $ACUR.$AD 记录之后可以删掉)")"
  press_enter "$(L "Added the DNS record? Press Enter to apply (Ctrl+C to abort)… " "加好 DNS 记录了?回车应用(Ctrl+C 取消)… ")"
  exec env ADMIN_SUB="$ANEW" INSTALL_DIR="$INSTALL_DIR" bash "$0" config
fi

# ---------------------------------------------------------------------
# 0. 基础 / 已部署检测 → 管理菜单
# ---------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "$(L "root required: sudo bash tuwunel-installer.sh yourdomain" "需要 root: sudo bash tuwunel-installer.sh 域名")"

if [ "$RECONFIG" -eq 0 ] && [ -f "$INSTALL_DIR/CREDENTIALS.txt" ] \
   && grep -q "$MARKER" "$INSTALL_DIR/tuwunel.toml" 2>/dev/null; then
  cd "$INSTALL_DIR"; SELF_BIN="$INSTALL_DIR/tuwunel-installer.sh"
  # 重跑安装命令时,把本地脚本副本刷新成当前这份(这样老部署重跑一键命令即可拿到新版),并刷新全局命令。
  # 【t1.15 修复】必须用 cd 之前就解析好的【绝对路径】$SELF_SRC:此处已 cd 到 INSTALL_DIR,
  # 再用相对的 $0(如 `bash tuwunel.sh` 时 $0=tuwunel.sh)判存在会失败 → 复制被跳过 →
  # 菜单显示的是新功能、但按下去调用的仍是旧副本(经典症状:选 a 弹出没有 a 的旧菜单)。
  if [ -n "$SELF_SRC" ] && [ -f "$SELF_SRC" ] \
     && [ "$(readlink -f -- "$SELF_SRC" 2>/dev/null)" != "$(readlink -f -- "$SELF_BIN" 2>/dev/null)" ]; then
    cp -f "$SELF_SRC" "$SELF_BIN" 2>/dev/null && chmod +x "$SELF_BIN" 2>/dev/null || true
  fi
  install_launcher "$SELF_BIN"
  if has_tty; then
    MENU_DOMAIN="$(env_saved MATRIX_DOMAIN)"
    while :; do
      cat <<EOF

┌──────────────────────────────────────────────┐
│  $(L "tuwunel management menu" "tuwunel 管理菜单")   ${MENU_DOMAIN:-}
└──────────────────────────────────────────────┘
  1) $(L "View running status" "查看运行状态")
  2) $(L "Add a team member (one command: create account + set password)" "添加团队成员(一条命令建号并设密码)")
  3) $(L "Change config (registration / federation / calls / web / admin / big files)" "修改配置(注册 / 联邦 / 通话 / 网页 / 后台 / 大文件)")
  4) $([ "$(env_saved ENABLE_ADMIN)" = "1" ] && L "Disable Web admin panel (Ketesa)" "关闭 Web 管理后台(Ketesa)" || L "Enable Web admin panel (Ketesa; add to an existing server)" "开启 Web 管理后台(Ketesa,老服务器补装)")
  5) $(L "Back up now (config + database + media)" "立即备份(配置 + 数据库 + 媒体)")
  6) $(L "Upgrade service images (docker pull latest)" "升级服务镜像(docker 拉最新)")
  7) $(L "Clean up disk" "清理磁盘")
  8) $(L "Restart all services" "重启所有服务")
  9) $(L "Update script + apply new features (pull latest from GitHub, data untouched)" "更新脚本 + 应用新功能(从 GitHub 拉最新,数据不动)")
 10) $(L "Uninstall completely" "彻底卸载")
  p) $(L "Privacy hardening / metadata cleanup (what can be deleted, clear logs)" "隐私加固 / 元数据清理(看能删什么、清日志)")
  s) $(L "Wipe plaintext credentials file (anti-forensics: remove on-disk password/token)" "涂销明文凭据文件(抗取证:去掉磁盘上的明文密码/邀请码)")
  b) $(L "Scheduled encrypted backup (optional: weekly auto, with rotation/skip-if-full)" "自动定时加密备份(可选:开启后每周自动,含轮转/满盘跳过)")
  a) $(L "Change admin panel URL (admin. → another subdomain)" "修改后台网址(admin. → 别的子域)")
  0) $(L Exit 退出)
EOF
      MCHOICE=""
      if [ -t 0 ]; then read -rp "$(L "Select [0-10]: " "请选择 [0-10]: ")" MCHOICE || exit 0
      else read -rp "$(L "Select [0-10]: " "请选择 [0-10]: ")" MCHOICE < /dev/tty 2>/dev/null || exit 0; fi
      case "$MCHOICE" in
        1) menu_status ;;
        2) [ -f "$SELF_BIN" ] && bash "$SELF_BIN" adduser || warn "$(L "script copy missing" "缺少脚本副本")" ;;
        3) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config || warn "$(L "script copy missing" "缺少脚本副本")" ;;
        4) if [ "$(env_saved ENABLE_ADMIN)" = "1" ]; then
             [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" disable-admin || warn "$(L "script copy missing" "缺少脚本副本")"
           else
             MASUB="$(env_saved ADMIN_SUB)"; MASUB="${MASUB:-admin}"
             echo "$(L "Enabling requires ${MASUB}.${MENU_DOMAIN} already resolving to this host (otherwise it stalls at the DNS check)." "开启后需要 ${MASUB}.${MENU_DOMAIN} 已解析到本机(否则会卡在 DNS 检查)。")"
             [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" enable-admin || warn "$(L "script copy missing" "缺少脚本副本")"
           fi ;;
        5) menu_backup ;;
        6) echo "$(L "==> Pulling latest images and upgrading…" "==> 拉取最新镜像并升级…")"
           { docker compose pull -q && docker compose up -d --remove-orphans && ok "$(L "Upgrade complete" "升级完成")"; } || warn "$(L "Upgrade failed: docker compose logs --tail 30" "升级失败: docker compose logs --tail 30")" ;;
        7) menu_cleanup ;;
        8) { docker compose up -d && docker compose restart; } >/dev/null 2>&1 && ok "$(L Restarted 已重启)" || warn "$(L "Restart failed: docker compose ps" "重启失败: docker compose ps")" ;;
        9) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" update || warn "$(L "script copy missing" "缺少脚本副本")"
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        10) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" uninstall || warn "$(L "script copy missing" "缺少脚本副本")"
           [ -d "$INSTALL_DIR" ] || exit 0 ;;
        p|P) menu_privacy ;;
        s|S) menu_forget_secrets ;;
        b|B) menu_autobackup ;;
        a|A) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" admin-url || warn "$(L "script copy missing" "缺少脚本副本")"
             [ -d "$INSTALL_DIR" ] || exit 0 ;;
        0|q|Q) echo "$(L Bye. 再见。)"; exit 0 ;;
        *) warn "$(L "Invalid choice, enter 0-10" "无效选择,请输入 0-10")" ;;
      esac
      press_enter "
$(L "Press Enter to return to the menu… " "按回车返回菜单… ")"
    done
  fi
  warn "$(L "Completed deployment detected — just restarting." "检测到已完成的部署,只做重启。")"; docker compose up -d; exit 0
fi

# ---- 语言选择 / Choose UI language(仅新装 + 交互 + 未预设 LANG_UI 时询问;菜单/reconfig 沿用已保存值)----
if [ "$RECONFIG" -eq 0 ] && has_tty && [ -z "$UI_LANG" ]; then
  printf '\nLanguage / 语言:\n  [1] English\n  [2] 中文(简体)\n'
  ask_opt "→ [1/2, Enter=2]: " "2"
  case "$REPLY" in 1) UI_LANG=en;; *) UI_LANG=zh;; esac
fi
[ -n "$UI_LANG" ] || UI_LANG=zh   # 兜底:非交互/未选 → 中文

# ---- 域名 ----
normalize_domain(){ echo "$1" | tr 'A-Z' 'a-z' | sed 's|^https\?://||; s|/.*$||' | tr -d '[:space:]'; }
domain_ok(){ echo "$1" | grep -Eq '^[a-z0-9.-]+\.[a-z]{2,}$' || return 1
  case "$1" in example.com|example.org|yourdomain.*|mydomain.*|domain.com) return 1;; esac; return 0; }

DOMAIN="$(normalize_domain "${1:-}")"
if [ "$RECONFIG" -eq 1 ]; then
  DOMAIN="$(normalize_domain "$(env_saved MATRIX_DOMAIN)")"
  [ -n "$DOMAIN" ] || die "$(L "No deployed config found. 'config' only works on an installed server" "未找到已部署配置。config 只能在装好的服务器上用")"
  echo "$(L "Reconfigure: $DOMAIN (domain can't change; data/accounts unchanged)" "修改配置: $DOMAIN(域名不可改;数据/账号保持不变)")"
fi
until domain_ok "$DOMAIN"; do
  [ -n "$DOMAIN" ] && warn "$(L "'$DOMAIN' is not a usable domain (needs a real one you've purchased)." "『$DOMAIN』不是可用域名(需你已购买的真实域名)。")"
  DPROMPT="$(L "Enter your domain (e.g. mychat.org): " "请输入你的域名(例 mychat.org): ")"
  if [ -t 0 ]; then read -rp "$DPROMPT" DOMAIN || die "$(L Cancelled 已取消)"
  elif [ -e /dev/tty ]; then read -rp "$DPROMPT" DOMAIN < /dev/tty 2>/dev/null || die "$(L "Read failed — pass the domain as an argument" "读取失败,请带域名参数运行")"
  else die "$(L "No interactive terminal. Pass the domain: sudo bash tuwunel-installer.sh mychat.org" "无交互终端。请带域名参数: sudo bash tuwunel-installer.sh mychat.org")"; fi
  DOMAIN="$(normalize_domain "$DOMAIN")"
done

ACME_EMAIL="${ACME_EMAIL:-admin@$DOMAIN}"
M_HOST="matrix.$DOMAIN"; LK_HOST="livekit.$DOMAIN"; RTC_HOST="matrix-rtc.$DOMAIN"
# 管理后台子域名(默认 admin;可改成 console/manage 等)。ADMIN_SUB= 预设或安装时选择,存 .env。
_ADMIN_SUB_ENV="${ADMIN_SUB:-}"                                  # 记录是否由环境变量显式传入(用于 EXPLICIT 判定)
ADMIN_SUB="${ADMIN_SUB:-$(env_saved ADMIN_SUB)}"; ADMIN_SUB="${ADMIN_SUB:-admin}"
ADMIN_SUB="$(echo "$ADMIN_SUB" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
# 只允许一个合法 DNS 标签(小写字母数字+连字符,不含点);非法或与其它服务冲突则回落 admin
echo "$ADMIN_SUB" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' || ADMIN_SUB="admin"
case "$ADMIN_SUB" in matrix|livekit|matrix-rtc|www) ADMIN_SUB="admin";; esac
A_HOST="$ADMIN_SUB.$DOMAIN"
apt-get update -qq >/dev/null 2>&1 || true
command -v curl >/dev/null 2>&1 || apt-get install -y -qq curl || die "$(L "curl install failed" "curl 安装失败")"
command -v openssl >/dev/null 2>&1 || apt-get install -y -qq openssl || die "$(L "openssl install failed" "openssl 安装失败")"
PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
bold "$(L "Target: $DOMAIN  →  server ${PUBLIC_IP:-unknown}  →  dir $INSTALL_DIR  (engine: tuwunel/Rust)" "目标: $DOMAIN  →  服务器 ${PUBLIC_IP:-未知}  →  目录 $INSTALL_DIR  (引擎: tuwunel/Rust)")"

# ---------------------------------------------------------------------
# 选项(回车=推荐默认;重跑沿用;环境变量可预设)
# ---------------------------------------------------------------------
EXPLICIT=0; [ -n "${REG_MODE:-}${ENABLE_FEDERATION:-}${ENABLE_CALLS:-}${ENABLE_WEB:-}${ENABLE_ADMIN:-}${ENABLE_ELEMENTX:-}${ENABLE_PRIVACY:-}${PRIVACY:-}${MAX_UPLOAD:-}${_ADMIN_SUB_ENV:-}" ] && EXPLICIT=1
REG_MODE="${REG_MODE:-$(env_saved REG_MODE)}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-$(env_saved ENABLE_FEDERATION)}"
ENABLE_CALLS="${ENABLE_CALLS:-$(env_saved ENABLE_CALLS)}"
ENABLE_WEB="${ENABLE_WEB:-$(env_saved ENABLE_WEB)}"   # 自托管 Element Web 网页客户端(你的域名注册/登录)
ENABLE_ADMIN="${ENABLE_ADMIN:-$(env_saved ENABLE_ADMIN)}"   # 自托管 Ketesa Web 管理后台(admin.你的域名)
ENABLE_ELEMENTX="${ENABLE_ELEMENTX:-$(env_saved ENABLE_ELEMENTX)}"   # Element X 手机App自助注册(tuwunel原生OIDC;默认开)
ENABLE_PRIVACY="${PRIVACY:-${ENABLE_PRIVACY:-$(env_saved ENABLE_PRIVACY)}}"   # 隐私加固/元数据最小化(默认开)
USE_CDN="${CDN:-$(env_saved USE_CDN)}"   # 服务器前是否有 Cloudflare/CDN 代理(影响 DNS 预检与提示;不改生成的配置)
MAX_UPLOAD="${MAX_UPLOAD:-}"
SAVED_BYTES="$(env_saved MAX_UPLOAD_BYTES)"

DEF_REG=1; DEF_FED=N; DEF_CALL=n; DEF_WEB=Y; DEF_ADMIN=Y
if [ "$RECONFIG" -eq 1 ] && [ "$EXPLICIT" -eq 0 ]; then
  has_tty || die "$(L "config needs an interactive terminal; or use env vars: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config" "config 需交互终端;或用环境变量: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config")"
  case "$REG_MODE" in open) DEF_REG=2;; *) DEF_REG=1;; esac
  [ "$ENABLE_FEDERATION" = "1" ] && DEF_FED=y || DEF_FED=N
  [ "$ENABLE_CALLS" = "1" ] && DEF_CALL=Y || DEF_CALL=n
  [ "$ENABLE_WEB" = "0" ] && DEF_WEB=n || DEF_WEB=Y
  [ "$ENABLE_ADMIN" = "0" ] && DEF_ADMIN=n || DEF_ADMIN=Y
  echo ""; echo "$(L "Current" "当前"): $(L Reg 注册)[$REG_MODE] · $(L Federation 联邦)[$([ "$ENABLE_FEDERATION" = "1" ] && L on 开 || L off 关)] · $(L Calls 通话)[$([ "$ENABLE_CALLS" = "1" ] && L on 开 || L off 关)] · $(L Web 网页客户端)[$([ "$ENABLE_WEB" = "1" ] && L on 开 || L off 关)] · $(L Admin 管理后台)[$([ "$ENABLE_ADMIN" = "1" ] && L on 开 || L off 关)] · $(L Big-files 大文件)[$(human "${SAVED_BYTES:-4294967296}")]"
  echo "$(L "Press Enter = keep current value." "直接回车 = 保持当前值。")"
  REG_MODE=""; ENABLE_FEDERATION=""; ENABLE_CALLS=""; ENABLE_WEB=""; ENABLE_ADMIN=""
fi

if has_tty && { [ -z "$REG_MODE" ] || [ -z "$ENABLE_FEDERATION" ] || [ -z "$ENABLE_CALLS" ] || [ -z "$ENABLE_WEB" ] || [ -z "$ENABLE_ADMIN" ]; }; then
  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "Install options: unsure? just press Enter for the recommended (already the most private, safest) values." "安装选项:看不懂就直接回车用推荐值(已是私密最安全组合)。")" "$C_RESET"

  if [ -z "$REG_MODE" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 1/6] Who can register" "【选项 1/6】谁能注册账号")" "$C_RESET"
    printf '%s\n' "$(L "  [1] Invite token required (recommended) — only people you give the token to can register; the first registrant becomes admin.
  [2] Fully open — anyone can register (very risky; do not use for business)." "  [1] 需注册令牌(推荐)—— 只有拿到你发的令牌的人才能注册;首个注册者=管理员。
  [2] 完全开放 —— 任何人都能注册(风险极高,商用勿选)。")"
    ask_opt "$(L "→ [1/2, Enter=$DEF_REG]: " "→ [1/2,回车=$DEF_REG]: ")" "$DEF_REG"
    case "$REPLY" in 2) REG_MODE=open; warn "$(L "Open registration selected — at your own risk!" "已选开放注册,风险自负!")";; *) REG_MODE=token;; esac
  fi

  if [ -z "$ENABLE_FEDERATION" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 2/6] Federation (connect to the external Matrix world)" "【选项 2/6】联邦互通(与外部 Matrix 世界相连)")" "$C_RESET"
    printf '%s\n' "$(L "  [N] Off (recommended) — an island; outsiders cannot message your members. Smallest attack surface, best for confidentiality.
  [y] On — can interoperate with matrix.org etc., but larger exposure." "  [N] 关闭(推荐)—— 孤岛,外人无法向你的成员发消息,攻击面最小,商密首选。
  [y] 开启 —— 可与 matrix.org 等互通,暴露面变大。")"
    ask_opt "$(L "→ [y/N, Enter=$DEF_FED]: " "→ [y/N,回车=$DEF_FED]: ")" "$DEF_FED"
    case "$REPLY" in y|Y) ENABLE_FEDERATION=1;; *) ENABLE_FEDERATION=0;; esac
  fi

  if [ -z "$ENABLE_CALLS" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 3/6] Voice/video calls (Element Call)" "【选项 3/6】语音/视频通话(Element Call)")" "$C_RESET"
    printf '%s\n' "$(L "  [n] Off (recommended first) — natively supported, but the call path is newer; get chat + big files stable first.
  [Y] On — also installs LiveKit + lk-jwt; needs two extra DNS records (livekit. / matrix-rtc.) and ports 7881/7882." "  [n] 关闭(推荐先关)—— tuwunel 原生支持,但通话链路较新;先跑稳聊天+大文件。
  [Y] 开启 —— 额外装 LiveKit + lk-jwt,需再加 livekit. / matrix-rtc. 两条 DNS 和 7881/7882 端口。")"
    ask_opt "$(L "→ [y/N, Enter=$DEF_CALL]: " "→ [y/N,回车=$DEF_CALL]: ")" "$DEF_CALL"
    case "$REPLY" in y|Y) ENABLE_CALLS=1;; *) ENABLE_CALLS=0;; esac
  fi

  if [ -z "$ENABLE_WEB" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 4/6] Web client on your own domain (Element Web)" "【选项 4/6】自家域名网页客户端(Element Web)")" "$C_RESET"
    printf '%s\n' "$(L "  [Y] On (recommended) — host a web Element on your OWN domain: members open
       https://your-domain to register, log in and chat — no element.io, no app.
       Locked to your server, white-labelable; no extra DNS (uses root domain). ~30MB RAM.
  [n] Off — members can only use the Element X app or app.element.io to log into your server." "  [Y] 开启(推荐)—— 在【你自己的域名】放一个网页版 Element:成员打开
       https://你的域名 就能【直接注册、登录、聊天】,不用去 element.io、不用装 App。
       锁定到你的服务器、可白标;放根域名不需再加 DNS。多占约 30MB 内存。
  [n] 关闭 —— 成员只能用 Element X App 或 app.element.io 登录你的服务器。")"
    ask_opt "$(L "→ [Y/n, Enter=$DEF_WEB]: " "→ [Y/n,回车=$DEF_WEB]: ")" "$DEF_WEB"
    case "$REPLY" in n|N) ENABLE_WEB=0;; *) ENABLE_WEB=1;; esac
  fi

  if [ -z "$ENABLE_ADMIN" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 5/6] Web admin panel (Ketesa graphical panel)" "【选项 5/6】Web 管理后台(Ketesa 图形面板)")" "$C_RESET"
    printf '%s\n' "$(L "  [Y] On (recommended) — host a mature graphical admin panel at admin.your-domain
       (Ketesa, officially supported by tuwunel): manage users, issue/revoke invite codes,
       view rooms/media, deactivate accounts, reset passwords — all in a browser, no commands.
       Needs one extra 'admin.' DNS record. ~20MB RAM.
  [n] Off — manage only via the command line (sudo tuwunel menu / admin-room commands)." "  [Y] 开启(推荐)—— 在【admin.你的域名】放一个成熟的图形管理面板(Ketesa,
       tuwunel 官方支持):浏览器里【图形化】管理用户、发/吊销邀请码、看房间/媒体、
       停用账号、改密码,不用敲命令。需再加一条 admin. 的 DNS。多占约 20MB 内存。
  [n] 关闭 —— 只用命令行(sudo tuwunel 菜单 / 管理员房间命令)管理。")"
    ask_opt "$(L "→ [Y/n, Enter=$DEF_ADMIN]: " "→ [Y/n,回车=$DEF_ADMIN]: ")" "$DEF_ADMIN"
    case "$REPLY" in n|N) ENABLE_ADMIN=0;; *) ENABLE_ADMIN=1;; esac
    # 新装时可自定义后台子域名(默认 admin)。老服务器改子域走 `sudo tuwunel admin-url`。
    if [ "$ENABLE_ADMIN" = 1 ] && [ "$RECONFIG" -eq 0 ]; then
      while :; do
        ask_opt "$(L "   → Admin panel subdomain [Enter=$ADMIN_SUB] (e.g. admin / console / manage): " "   → 后台面板子域名 [回车=$ADMIN_SUB](如 admin / console / manage): ")" "$ADMIN_SUB"
        NEWSUB="$(echo "$REPLY" | tr 'A-Z' 'a-z' | tr -d '[:space:]')"
        case "$NEWSUB" in matrix|livekit|matrix-rtc|www) warn "$(L "'$NEWSUB' is reserved by another service — pick another." "『$NEWSUB』被其它服务占用 —— 换一个。")"; has_tty || { NEWSUB="admin"; break; }; continue;; esac
        echo "$NEWSUB" | grep -Eq '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' && break
        warn "$(L "Invalid subdomain — one label only: lowercase letters/digits/hyphen, no dots." "子域名不合法 —— 只能一个标签:小写字母/数字/连字符,不含点。")"
        has_tty || { NEWSUB="admin"; break; }
      done
      ADMIN_SUB="$NEWSUB"; A_HOST="$ADMIN_SUB.$DOMAIN"
    fi
  fi

  if [ -z "$MAX_UPLOAD" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 6/6] Max file size (send big files/photos/long videos)" "【选项 6/6】单文件上限(发大文件/大图/长视频)")" "$C_RESET"
    echo "$(L "  Set any size (e.g. 4G / 4.5G / 512M / 1T); bigger uses more disk. Enter = 4G." "  设多大都行(如 4G / 4.5G / 512M / 1T);越大越占磁盘。回车=4G。")"
    while :; do
      ask_opt "$(L "→ Max file size [Enter=$(human "${SAVED_BYTES:-4294967296}")]: " "→ 单文件上限 [回车=$(human "${SAVED_BYTES:-4294967296}")]: ")" "${SAVED_BYTES:+$(human "$SAVED_BYTES")}"
      [ -z "$REPLY" ] && REPLY="4G"
      if size_ok "$REPLY"; then MAX_UPLOAD="$REPLY"; break; fi
      warn "$(L "Didn't understand '$REPLY'. Write it like 4G / 4.5G / 512M / 1T (number + K/M/G/T), or press Enter for the default." "看不懂『$REPLY』。请写成 4G / 4.5G / 512M / 1T 这样(数字 + K/M/G/T),或直接回车用默认。")"
      has_tty || { MAX_UPLOAD="4G"; break; }
    done
  fi
fi
REG_MODE="${REG_MODE:-token}"; ENABLE_FEDERATION="${ENABLE_FEDERATION:-0}"; ENABLE_CALLS="${ENABLE_CALLS:-0}"; ENABLE_WEB="${ENABLE_WEB:-1}"; ENABLE_ADMIN="${ENABLE_ADMIN:-1}"
case "$ENABLE_FEDERATION" in 1) :;; *) ENABLE_FEDERATION=0;; esac
case "$ENABLE_CALLS" in 1) :;; *) ENABLE_CALLS=0;; esac
case "$ENABLE_WEB" in 0) :;; *) ENABLE_WEB=1;; esac
case "$ENABLE_ADMIN" in 0) :;; *) ENABLE_ADMIN=1;; esac
case "$ENABLE_ELEMENTX" in 0) :;; *) ENABLE_ELEMENTX=1;; esac
case "$ENABLE_PRIVACY" in 0) :;; *) ENABLE_PRIVACY=1;; esac
case "$REG_MODE" in token|open) :;; *) REG_MODE=token;; esac
if [ -n "$MAX_UPLOAD" ]; then MAX_UPLOAD_BYTES="$(to_bytes "$MAX_UPLOAD")"
elif [ -n "$SAVED_BYTES" ]; then MAX_UPLOAD_BYTES="$SAVED_BYTES"
else MAX_UPLOAD_BYTES=4294967296; fi

REQUIRED_HOSTS="$DOMAIN $M_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp"
[ "$ENABLE_ADMIN" = "1" ] && REQUIRED_HOSTS="$REQUIRED_HOSTS $A_HOST"
if [ "$ENABLE_CALLS" = "1" ]; then REQUIRED_HOSTS="$REQUIRED_HOSTS $LK_HOST $RTC_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp 7881/tcp 7882/udp"; fi
echo ""
printf '  %s%s[%s] · %s[%s] · %s[%s] · %s[%s] · %s[%s] · %s[%s] · %s[%s]%s\n' "$C_GREEN" \
  "$(L '✔ Config: reg' '✔ 配置: 注册')" "$REG_MODE" \
  "$(L Federation 联邦)"    "$([ "$ENABLE_FEDERATION" = 1 ] && L on 开 || L off 关)" \
  "$(L Calls 通话)"         "$([ "$ENABLE_CALLS" = 1 ] && L on 开 || L off 关)" \
  "$(L Web 网页客户端)"     "$([ "$ENABLE_WEB" = 1 ] && L on 开 || L off 关)" \
  "$(L Admin 管理后台)"     "$([ "$ENABLE_ADMIN" = 1 ] && L on 开 || L off 关)" \
  "$(L 'Phone-signup' 手机App注册)" "$([ "$ENABLE_ELEMENTX" = 1 ] && L on 开 || L off 关)" \
  "$(L 'Max-file' 大文件上限)" "$(human "$MAX_UPLOAD_BYTES")" "$C_RESET"

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

${C_CYAN}┌──────────────────────────────────────────────────────────┐${C_RESET}
$(L "  tuwunel one-command install · Rust · lean · built for big files & privacy" "│  tuwunel 轻量一键安装 · Rust 省资源 · 为大文件与保密而生   │")
${C_CYAN}└──────────────────────────────────────────────────────────┘${C_RESET}
$(L "Two things you must do yourself (in your provider's web console):" "两件事必须你在【网页后台】手动做:")

 ${C_B}${C_YELLOW}$(L "① At your domain registrar → add these A records, all pointing to" "① 域名商 → 加下列 A 记录,全部指向") ${PUBLIC_IP:-$(L "your server IP" 本服务器IP)}:${C_RESET}
${C_GREEN}$DNS_LINES${C_RESET}

 ${C_B}${C_YELLOW}$(L "② At your VPS provider → security group / firewall, allow:" "② 服务器商 → 安全组/防火墙 放行:")${C_RESET}
      ${C_GREEN}$PORT_LINE${C_RESET}
EOF
  # 是否用了 Cloudflare/CDN(仅在未通过 CDN= 预设时询问)
  if [ -z "$USE_CDN" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "Is there a Cloudflare / CDN proxy in front of your server?" "服务器前面用了 Cloudflare / CDN 代理吗?")" "$C_RESET"
    printf '%s\n' "$(L "  [n] No (recommended) — DNS resolves straight to this server. Pick this in almost all cases.
  [y] Yes — relaxes the DNS check. Note: a CDN orange-cloud kills big files (Free/Pro cap 100MB)
      and can block certificate issuance; the matrix & media hosts MUST stay grey-cloud (DNS-only)." "  [n] 没有(推荐)—— DNS 直接解析到本服务器,绝大多数情况选这个。
  [y] 用了 —— 会放宽 DNS 检查。但注意:CDN 橙云会掐死大文件(免费/Pro 上限 100MB)、
      还可能让证书签不出;matrix 与媒体主机务必走【灰云/仅DNS】。")"
    ask_opt "$(L "→ [y/N, Enter=n]: " "→ [y/N,回车=n]: ")" "n"
    case "$REPLY" in y|Y) USE_CDN=1;; *) USE_CDN=0;; esac
  fi
  if [ "$USE_CDN" = "1" ]; then cat <<CDNEOF

 ${C_B}${C_YELLOW}$(L "⚠️ You chose CDN — configure it exactly like this, or big files/certs will fail:" "⚠️ 你选了 CDN —— 务必按下面配,否则大文件/证书会失败:")${C_RESET}
$(L "   · ${C_GREEN}matrix.$DOMAIN and the media host MUST be grey-cloud (DNS-only)${C_RESET} (else Caddy can't get a cert, and big files hit the CDN 100MB cap)
   · At most, put only the static front-ends (web client / admin panel) behind the orange-cloud proxy
   · Cloudflare dashboard: turn OFF Bot Fight Mode; set Bypass cache for /_matrix/* and /.well-known/matrix/*
   · SSL/TLS mode = Full (Strict), not Flexible (causes infinite redirects)
   · Hiding the origin IP via orange-cloud barely works (CT logs / grey-cloud subdomains leak it) — don't rely on it for privacy" "   · ${C_GREEN}matrix.$DOMAIN 和媒体主机必须【灰云/仅DNS】${C_RESET}(否则 Caddy 签不出证书、大文件被 CDN 100MB 上限掐死)
   · 顶多把纯静态前端(网页版/管理后台)挂橙云代理
   · Cloudflare 后台:关 Bot Fight Mode;对 /_matrix/* 与 /.well-known/matrix/* 设 Bypass 缓存
   · SSL/TLS 模式设 Full(Strict),别用 Flexible(会无限重定向)
   · 想用橙云\"藏源站 IP\"基本无效(证书透明度/灰云子域会泄漏),别指望它做隐私")
CDNEOF
  fi
  press_enter "$(L "Done with ① ②? Press Enter to start… (not done? Ctrl+C to quit) " "①② 做好了按回车开始…(没做?Ctrl+C 退出) ")"
fi

# ---------------------------------------------------------------------
# 1. DNS 预检
# ---------------------------------------------------------------------
case "$USE_CDN" in 1) :;; *) USE_CDN=0;; esac
dns_check(){ local bad=0 h R4
  for h in $REQUIRED_HOSTS; do
    R4="$(getent ahosts "$h" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.' | grep -Ev '^127\.' | sort -u || true)"
    if [ -z "$R4" ]; then warn "$h → $(L "no DNS record" 无解析)"; bad=1
    elif [ -n "$PUBLIC_IP" ] && ! echo "$R4" | grep -qx "$PUBLIC_IP"; then
      if [ "$USE_CDN" = "1" ]; then echo "  ~ $h → $(echo "$R4"|tr '\n' ' ')$(L "(via CDN, not direct — allowed for CDN mode; keep matrix/media grey-cloud)" "(经 CDN,未直连本机——已按 CDN 放行;确保 matrix/媒体走灰云)")"
      else warn "$h → $(echo "$R4"|tr '\n' ' ')$(L "(not pointing at this host $PUBLIC_IP; if you use Cloudflare/CDN, re-run and choose CDN, or set CDN=1)" "(未指向本机 $PUBLIC_IP;若用了 Cloudflare/CDN,请重跑选 CDN 或加 CDN=1)")"; bad=1; fi
    else echo "  ✓ $h → $(echo "$R4"|head -1)"; fi
  done; return $bad; }
if [ "${SKIP_DNS_CHECK:-0}" != "1" ]; then
  bold "$(L "1/6 Check DNS" "1/6 检查 DNS")"; A=0
  until dns_check; do A=$((A+1))
    has_tty || { echo "$(L "DNS not ready — fix the records and re-run." "DNS 未就绪,改好后重跑。")"; exit 1; }
    [ "$A" -ge 40 ] && die "$(L "Waited too long — check the records and re-run." "等待过久,请检查记录后重跑")"
    warn "$(L "DNS not propagated yet, retrying in 60s… (Ctrl+C to quit)" "DNS 还没生效,60 秒后重测…(Ctrl+C 退出)")"; sleep 60
  done; ok "$(L "DNS ready" "DNS 就绪")"
else warn "$(L "DNS pre-check skipped" "已跳过 DNS 预检")"; fi

# ---------------------------------------------------------------------
# 2. Docker + 内存/Swap/BBR + 防火墙
# ---------------------------------------------------------------------
bold "$(L "2/6 Install Docker" "2/6 安装 Docker")"
command -v docker >/dev/null 2>&1 || curl -fsSL https://get.docker.com | sh
docker compose version >/dev/null 2>&1 || apt-get install -y -qq docker-compose-plugin || die "$(L "docker compose v2 unavailable" "docker compose v2 不可用")"

bold "$(L "3/6 System tuning (Swap / BBR)" "3/6 系统调优(Swap / BBR)")"
RAM_MB="$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo 2>/dev/null || true)"   # 缺 /proc/meminfo 也不因 set -e 中止
if [ "${RAM_MB:-0}" -lt 2500 ] && [ -z "$(swapon --show --noheadings 2>/dev/null)" ]; then
  if { fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none 2>/dev/null; } \
     && chmod 600 /swapfile 2>/dev/null && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile 2>/dev/null; then
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' > /etc/sysctl.d/99-tuwunel-swap.conf; sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    echo "$(L "RAM ${RAM_MB}MB — added 2G swap." "内存 ${RAM_MB}MB,已加 2G swap。")"
  else rm -f /swapfile; warn "$(L "Couldn't add swap, skipping (no impact)." "无法加 swap,跳过(不影响)。")"; fi
else echo "$(L "RAM ${RAM_MB:-?}MB, swap OK, skipping." "内存 ${RAM_MB:-?}MB,swap OK,跳过。")"; fi
if modprobe tcp_bbr 2>/dev/null || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' > /etc/sysctl.d/99-tuwunel-bbr.conf
  { sysctl -p /etc/sysctl.d/99-tuwunel-bbr.conf || sysctl --system; } >/dev/null 2>&1 || true
  [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ] && echo "$(L "BBR enabled." "已启用 BBR。")" || warn "$(L "BBR not active immediately (common on container VPS), check after reboot." "BBR 未即时生效(容器型 VPS 常见),重启后再看。")"
else warn "$(L "Kernel doesn't support BBR, skipping." "内核不支持 BBR,跳过。")"; fi
# 内存档:tuwunel 很轻
if [ "${RAM_MB:-0}" -ge 3500 ]; then TUWUNEL_MEM=2g; else TUWUNEL_MEM=1g; fi

bold "$(L "4/6 Firewall (ufw)" "4/6 防火墙 (ufw)")"
SSH_PORT="$(ss -tlnpH 2>/dev/null | awk '/sshd/{sub(/.*:/,"",$4); print $4; exit}' || true)"; SSH_PORT="${SSH_PORT:-22}"
if command -v ufw >/dev/null 2>&1 || apt-get install -y -qq ufw >/dev/null 2>&1; then
  if ufw allow "${SSH_PORT}/tcp" >/dev/null 2>&1; then
    ufw allow 80/tcp >/dev/null; ufw allow 443/tcp >/dev/null; ufw allow 443/udp >/dev/null
    if [ "$ENABLE_CALLS" = "1" ]; then ufw allow 7881/tcp >/dev/null; ufw allow 7882/udp >/dev/null
    else ufw delete allow 7881/tcp >/dev/null 2>&1 || true; ufw delete allow 7882/udp >/dev/null 2>&1 || true; fi
    ufw --force enable >/dev/null; echo "$(L "Allowed: SSH(${SSH_PORT}) + $PORT_LINE" "已放行: SSH(${SSH_PORT}) + $PORT_LINE")"
  else warn "$(L "ufw unavailable — open the ports yourself." "ufw 不可用,请自行放行端口。")"; fi
else warn "$(L "ufw unavailable — open the ports yourself." "ufw 不可用,请自行放行端口。")"; fi
warn "$(L "Your cloud provider's 'security group' must also allow: $PORT_LINE" "云服务商『安全组』也要放行: $PORT_LINE")"

# ---------------------------------------------------------------------
# 5. 目录 / 机密 / 配置文件
# ---------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" || die "$(L "Cannot create $INSTALL_DIR" "无法创建 $INSTALL_DIR")"; cd "$INSTALL_DIR"; INSTALL_DIR="$PWD"
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
  printf '30 4 * * * root INSTALL_DIR="%s" bash "%s" diskguard >/dev/null 2>&1\n' "$INSTALL_DIR" "$SELF_DST" \
    > /etc/cron.d/tuwunel-diskguard 2>/dev/null && chmod 644 /etc/cron.d/tuwunel-diskguard 2>/dev/null || true
fi

# 已完成的部署且非 config → 只重启
if [ "$RECONFIG" -eq 0 ] && [ -f tuwunel.toml ] && grep -q "$MARKER" tuwunel.toml 2>/dev/null && [ -f CREDENTIALS.txt ]; then
  warn "$(L "Completed deployment detected — just restarting." "检测到已完成的部署,只做重启。")"; docker compose up -d; exit 0
fi
# 端口占用预检
if ! docker compose ps -q caddy 2>/dev/null | grep -q .; then
  if ss -tlnH 2>/dev/null | awk '{print $4}' | grep -Eq ':(80|443)$'; then
    die "$(L "80/443 is in use by another program (nginx/apache?) — stop it and re-run" "80/443 被别的程序占用(nginx/apache?),先停掉再重跑")"; fi
fi

bold "$(L "5/6 Generate keys & config" "5/6 生成密钥与配置")"
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
UI_LANG=$UI_LANG
PUBLIC_IP=$PUBLIC_IP
REG_TOKEN=$REG_TOKEN
REG_MODE=$REG_MODE
ENABLE_FEDERATION=$ENABLE_FEDERATION
ENABLE_CALLS=$ENABLE_CALLS
ENABLE_WEB=$ENABLE_WEB
ENABLE_ADMIN=$ENABLE_ADMIN
ADMIN_SUB=$ADMIN_SUB
ENABLE_ELEMENTX=$ENABLE_ELEMENTX
ENABLE_PRIVACY=$ENABLE_PRIVACY
USE_CDN=$USE_CDN
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
# Element X 手机 App 自助注册:开启 tuwunel 内置 OIDC(不需另装 MAS)。注册仍走 UIAA、强制邀请码,不绕过。
# 安全前提:本脚本【不添加任何 [[global.identity_provider]] 上游 IdP】(那才会绕过邀请码),故开着也守得住邀请制。
if [ "$ENABLE_ELEMENTX" = "1" ]; then OIDC_LINE="oidc_native_auth = true          # 让 Element X 手机App能自助注册/登录(原生OIDC;注册仍强制邀请码)"
else OIDC_LINE="# oidc_native_auth = false        # Element X 手机注册关闭(成员改用网页注册/管理员建号;Element X 仍可用密码登录)"; fi

# ---- 隐私加固(元数据最小化)----
# 依据 tuwunel v1.8.2 源码核实的键;只用确认存在的键(写错的键会让容器起不来,故本块有回滚保护)。
# 代价仅:在线状态/正在输入消失(对保密团队反而是优点)。关掉用: PRIVACY=0 sudo -E tuwunel config
if [ "$ENABLE_PRIVACY" = "1" ]; then PRIVACY_LINES='
# ===== 隐私加固:元数据最小化 =====
# 【最高价值】只认 TCP 对端(=Caddy 容器),真实客户端 IP 根本进不了库。
# tuwunel 在建设备时无条件记录 IP 且无开关可关,这是唯一缓解手段。
# 副作用:按 IP 的限流失效(所有人看起来同一 IP);邀请制内网部署可接受。
ip_source = "connect_info"

# 日志:warn 恰好切掉两处会把 client_ip 打进容器日志的 span。切勿设 debug(会记录每个请求)。
log = "warn"
log_span_events = "none"

# 在线状态:三个键必须一起关(只关出向会被启动校验拒绝)。关掉即不再落盘 presence,也不再刷新设备 last-seen。
allow_local_presence = false
allow_incoming_presence = false
allow_outgoing_presence = false

# 正在输入:tuwunel 只存内存不落盘,这两键是联邦方向的双保险。
allow_outgoing_typing = false
allow_incoming_typing = false

# 【陷阱修复】撤回即真撤回:默认会把撤回消息的原文再留 60 天且管理员可取回。
save_unredacted_events = false
redaction_retention_seconds = 0
allow_room_admins_to_request_unredacted_events = false

# 资料/目录暴露面收紧
require_auth_for_profile_requests = true
allow_inbound_profile_lookup_federation_requests = false
allow_device_name_federation = false
allow_public_room_directory_without_auth = false
lockdown_public_room_directory = true
allow_unlisted_room_search_by_id = false
show_all_local_users_in_user_directory = false

# 管理房操作流水:默认会把注册/改密码/停用推进管理房,形成可读的元数据流水
admin_room_notices = false
log_guest_registrations = false

# 第三方遥测(默认就关,写死防回归)
sentry = false
allow_jaeger = false
tracing_flame = false

# RocksDB 自身日志
rocksdb_log_level = "error"
rocksdb_log_stderr = false
rocksdb_max_log_files = 1'
else PRIVACY_LINES='# (隐私加固未启用:PRIVACY=1 sudo -E tuwunel config 可开启元数据最小化)'; fi

# 改配置前先备份,便于新键不被本版 tuwunel 接受时自动回滚(见下方 READY 失败处理)
TOML_BAK=""
[ -f tuwunel.toml ] && { TOML_BAK="tuwunel.toml.bak-$(date +%s)"; cp -a tuwunel.toml "$TOML_BAK"; }
cat > tuwunel.toml <<EOF
# ===== $MARKER($(date +%F))=====
[global]
server_name = "$DOMAIN"          # 一旦部署不可更改!改需清库
database_path = "/var/lib/tuwunel"   # RocksDB:数据库+媒体都在这
address = ["0.0.0.0"]            # Docker 下必须 0.0.0.0,让 Caddy 能连到
port = 8008
max_request_size = $MAX_UPLOAD_BYTES   # 单文件上限(字节)= $(human "$MAX_UPLOAD_BYTES")
allow_encryption = true          # 允许端到端加密(注意:这只是"允许",不强制)
# 【关键】强制新建房间默认开启 E2EE。此键默认为 "none",不写的话客户端没主动要求加密时,
# 消息正文会以明文存进数据库——对保密场景是致命缺口。
encryption_enabled_by_default_for_room_type = "all"
grant_admin_to_first_user = true # 第一个注册的人=服务器管理员
create_admin_room = true
new_user_displayname_suffix = "" # 去掉默认昵称后缀
allow_public_room_directory_over_federation = false
$OIDC_LINE
$FED_LINE
$TRUST_LINE
$REG_LINES
$PRIVACY_LINES

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
	# 隐私:降到 ERROR,减少日志面(访问日志本就未开启=opt-in)。
	# 不用 output discard,否则证书申请失败时无从排查。
	log default {
		level ERROR
	}
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

EOF
# matrix host 块:开了后台则加"举报页空桩"。tuwunel 未实现 event_reports/user_reports(会 404),
# Ketesa 的"报告事件/被举报用户"两页会红报错;拦截这两个精确路径返回空列表(200)→ 页面显示干净的"暂无数据"。
# 这两条路径不经过 tuwunel,故 CORS 由 Caddy 自补,且严格限定在 handle 内(不污染被代理路径的 tuwunel CORS)。
if [ "$ENABLE_ADMIN" = "1" ]; then
cat >> Caddyfile <<EOF

$M_HOST {
	@reportstub path /_synapse/admin/v1/event_reports /_synapse/admin/v1/user_reports
	@opts method OPTIONS
	@ev path /_synapse/admin/v1/event_reports
	@ur path /_synapse/admin/v1/user_reports
	handle @reportstub {
		route {
			header Access-Control-Allow-Origin "*"
			header Access-Control-Allow-Methods "GET, OPTIONS"
			header Access-Control-Allow-Headers "Authorization, Content-Type"
			header Access-Control-Max-Age "86400"
			header Content-Type "application/json"
			respond @opts 204
			respond @ev \`{"event_reports":[],"total":0}\` 200
			respond @ur \`{"user_reports":[],"total":0}\` 200
		}
	}
	handle {
		reverse_proxy tuwunel:8008
	}
}

$A_HOST {
	reverse_proxy ketesa:8080
}
EOF
else
cat >> Caddyfile <<EOF

$M_HOST {
	reverse_proxy tuwunel:8008
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
# 清理历史遗留的手动 override:早期修 502 时手工建的 docker-compose.override.yml(只给 element-web 设了
# ELEMENT_WEB_PORT、无 image)。脚本已内置该修复;若网页客户端关闭,主 compose 无 element-web,残留
# override 会变成"无 image 的服务"导致校验失败。识别到就备份移除。
if [ -f docker-compose.override.yml ] && grep -qE 'ELEMENT_WEB_PORT|element-web' docker-compose.override.yml 2>/dev/null; then
  mv -f docker-compose.override.yml "docker-compose.override.yml.obsolete-$(date +%s)" 2>/dev/null || rm -f docker-compose.override.yml
  warn "$(L "Removed a leftover docker-compose.override.yml (early manual 502 patch — now built in; would conflict)." "已移除历史遗留的 docker-compose.override.yml(早期手动 502 补丁,脚本已内置,留着会冲突)。")"
fi
docker compose config -q || die "$(L "compose config validation failed" "compose 配置校验失败")"

# 预校验 Caddyfile:语法错会让 caddy 起不来 → 整站 502。用一次性 caddy 容器先校验;
# 不通过则本次【不重启 caddy】(老配置继续跑,不中断),并提示用户。
CADDY_OK=1
if command -v docker >/dev/null 2>&1 && docker image inspect caddy:2 >/dev/null 2>&1; then
  if docker run --rm -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2 \
       caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
    ok "$(L "Caddyfile validated" "Caddyfile 校验通过")"
  else
    CADDY_OK=0
    warn "$(L "Caddyfile syntax check FAILED! Skipped the caddy restart to avoid taking the whole site down. Please send me $INSTALL_DIR/Caddyfile to debug." "Caddyfile 语法校验未通过!已跳过 caddy 重启以免整站中断。请把 $INSTALL_DIR/Caddyfile 发我排查。")"
  fi
fi

# ---------------------------------------------------------------------
# 6. 启动 + 验收
# ---------------------------------------------------------------------
bold "$(L "6/6 Start up (first run pulls images, a few minutes)" "6/6 启动(首次拉镜像需几分钟)")"
[ "$RECONFIG" -eq 0 ] && docker compose pull -q || true
# up -d 不会因 Caddyfile(绑定挂载)内容变化而重启正在运行的 caddy,只创建新容器(如 ketesa)/启动停止的容器,故对运行中的站点安全。
docker compose up -d --remove-orphans
# 只有显式 restart caddy 才会让它重读 Caddyfile;Caddyfile 没过校验就跳过,保住老配置不中断。
if [ "$RECONFIG" -eq 1 ]; then
  if [ "$CADDY_OK" = "1" ]; then docker compose restart tuwunel caddy >/dev/null 2>&1 || true; echo "$(L "Restarted with the new config." "已按新配置重启。")"
  else docker compose restart tuwunel >/dev/null 2>&1 || true; warn "$(L "caddy not restarted, new Caddyfile not applied yet; once fixed run: cd $INSTALL_DIR && docker compose restart caddy" "caddy 未重启,新 Caddyfile 暂未生效;修好后执行: cd $INSTALL_DIR && docker compose restart caddy")"; fi
fi

echo "$(L "Waiting for tuwunel to be ready…" "等待 tuwunel 就绪…")"; READY=0
for i in $(seq 1 40); do
  if docker compose exec -T tuwunel curl -fsS --max-time 3 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1 \
     || curl -4 -fsS --max-time 3 "http://127.0.0.1" >/dev/null 2>&1; then :; fi
  if curl -4 -fsS --max-time 4 "https://$M_HOST/_matrix/client/versions" >/dev/null 2>&1; then READY=1; ok "$(L "tuwunel is online, HTTPS is live." "tuwunel 在线,HTTPS 已生效。")"; break; fi
  sleep 5
done
if [ "$READY" -ne 1 ] && [ -n "${TOML_BAK:-}" ] && [ -f "$TOML_BAK" ]; then
  # tuwunel 起不来最常见的原因是配置里有本版不支持的键(尤其隐私加固新键)。自动回滚,保住服务可用。
  if ! docker compose ps tuwunel 2>/dev/null | grep -qi 'up\|healthy'; then
    warn "$(L "tuwunel failed to start — this version may not accept a config key. Auto-rolling back to the previous tuwunel.toml…" "tuwunel 未能启动 —— 可能本版不支持某个配置键。正在自动回滚到改动前的 tuwunel.toml…")"
    cp -a "$TOML_BAK" tuwunel.toml
    docker compose up -d tuwunel >/dev/null 2>&1 || true
    for i in $(seq 1 12); do
      curl -4 -fsS --max-time 4 "https://$M_HOST/_matrix/client/versions" >/dev/null 2>&1 && { READY=1; break; }
      sleep 5
    done
    if [ "$READY" -eq 1 ]; then
      warn "$(L "Rolled back and restored service. Privacy hardening is NOT applied — please send this line + 'docker compose logs tuwunel --tail 30' to the author to check the key name." "已回滚并恢复服务。隐私加固未生效 —— 请把这句和 docker compose logs tuwunel --tail 30 发给作者排查键名。")"
    else
      warn "$(L "Still not ready after rollback, check: cd $INSTALL_DIR && docker compose logs tuwunel --tail 40" "回滚后仍未就绪,请看: cd $INSTALL_DIR && docker compose logs tuwunel --tail 40")"
    fi
  fi
fi
[ "$READY" -eq 1 ] || warn "$(L "Not ready yet. Common causes: cloud security group not allowing 80/443, or DNS not fully propagated; Caddy retries the cert automatically, no reinstall needed. Logs: cd $INSTALL_DIR && docker compose logs --tail 40" "还没就绪。常见:云安全组没放行 80/443,或 DNS 未全球生效;Caddy 会自动重试证书,无需重装。看日志: cd $INSTALL_DIR && docker compose logs --tail 40")"

[ "$ENABLE_WEB" = "1" ] && WEB_URL="https://$DOMAIN" || WEB_URL=""
[ "$ENABLE_ADMIN" = "1" ] && ADMIN_URL="https://$A_HOST" || ADMIN_URL=""

# ---- 自动创建管理员(首个账号=管理员)+ 写凭据(成功才写,作为"部署完成"标志)----
ADMIN_USER="admin"; ADMIN_PASS=""; ADMIN_OK=0
if [ -f CREDENTIALS.txt ]; then
  ADMIN_OK=1                       # config/续跑:已有账号,不重复建、不覆盖凭据
elif [ "$READY" -eq 1 ]; then
  ADMIN_PASS="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
  echo "$(L "==> Auto-creating admin @$ADMIN_USER:$DOMAIN (the first account is the server admin)…" "==> 自动创建管理员 @$ADMIN_USER:$DOMAIN(第一个账号即服务器管理员)…")"
  if register_user "$ADMIN_USER" "$ADMIN_PASS" "https://$M_HOST" "$REG_TOKEN"; then
    ADMIN_OK=1; ok "$(L "Admin created automatically." "管理员已自动创建。")"
  else
    warn "$(L "Auto-creating the admin failed (service may have just started). Later run: sudo bash tuwunel-installer.sh adduser to create it (the first one is the admin)." "自动建管理员失败(服务可能刚起未完全就绪)。稍后执行: sudo bash tuwunel-installer.sh adduser 建号(首个即管理员)。")"
  fi
fi

if [ "$ADMIN_OK" -eq 1 ] && [ ! -f CREDENTIALS.txt ]; then
cat > CREDENTIALS.txt <<EOF
==== $(L "tuwunel deployment credentials" "tuwunel 部署凭据")  $DOMAIN  $(date '+%F %T') ====
$(L "Install dir:  " "安装目录:  ")  $INSTALL_DIR
$(L "Engine:       " "引擎:      ")  tuwunel (Rust, RocksDB, no Postgres)
$([ -n "$WEB_URL" ] && echo "$(L "Web signup/login:" "网页注册/登录:") $WEB_URL   $(L "(your domain — register in the browser, no element.io)" "(你的域名,浏览器直接注册,不用 element.io)")")
$(L "Client login: " "客户端登录:")  $(L "also Element X app / app.element.io, server =" "也可用 Element X App / app.element.io,服务器填") $DOMAIN
$(L "Admin user:   " "管理员账号:")  $ADMIN_USER   (ID: @$ADMIN_USER:$DOMAIN)
$(L "Admin password:" "管理员密码:")  $ADMIN_PASS
$([ -n "$ADMIN_URL" ] && echo "$(L "Web admin panel:" "Web 管理后台:")  $ADMIN_URL   $(L "(log in with the admin user/password above; graphical user/invite/room management)" "(用上面的管理员账号密码登录;图形化管理用户/邀请码/房间)")")
$(L "Registration token:" "注册令牌:")  $REG_TOKEN
$(L "Add member:   " "加成员:    ")  sudo bash tuwunel-installer.sh adduser
$(L "Max file size:" "单文件上限:")  $(human "$MAX_UPLOAD_BYTES")   (MAX_UPLOAD=10G sudo -E bash tuwunel-installer.sh config)
$(L "★ Must back up:" "★ 必须备份:")  $(L "the whole data/tuwunel dir (database + all media) + tuwunel.toml + .env" "整个 data/tuwunel 目录(含数据库与全部媒体)+ tuwunel.toml + .env")
EOF
chmod 600 CREDENTIALS.txt
fi

# ---- 收尾报告 ----
CALL_NOTE=""
[ "$ENABLE_CALLS" = "1" ] && CALL_NOTE="
 $(L "Calls (Element Call) are on: start a group call from any client. If it doesn't connect, first check curl -s https://$RTC_HOST returns 200 and that 7882/udp is open." "通话(Element Call)已开:客户端里发起群组通话即可。若不通,先 curl -s https://$RTC_HOST 看是否 200,并确认 7882/udp 放行。")"

if [ "$ADMIN_OK" -eq 1 ] && [ -n "$ADMIN_PASS" ]; then
  ADMIN_INFO="   $(L User 账号): ${C_B}$ADMIN_USER${C_RESET}    $(L Password 密码): ${C_B}${C_GREEN}$ADMIN_PASS${C_RESET}
   $(L "→ Log in with Element (server = $DOMAIN) and you're the admin." "→ 用 Element 直接登录(服务器填 $DOMAIN)即可,你就是管理员。")"
elif [ "$ADMIN_OK" -eq 1 ]; then
  ADMIN_INFO="   $(L "User/password unchanged (see $INSTALL_DIR/CREDENTIALS.txt)" "账号密码不变(见 $INSTALL_DIR/CREDENTIALS.txt)")"
else
  ADMIN_INFO="   ${C_YELLOW}$(L "Not created yet" 还没建好)${C_RESET} → $(L "once the service is ready, run:" "服务就绪后执行:") ${C_B}sudo bash tuwunel-installer.sh adduser${C_RESET}$(L " (the first account created is the admin)" "(首个建成的即管理员)")"
fi

cat <<EOF

${C_GREEN}========================================================${C_RESET}
 ${C_B}${C_GREEN}$(L "🎉 tuwunel deployment complete!" "🎉 tuwunel 部署完成!")${C_RESET}  ${C_B}$DOMAIN${C_RESET}
 ($(L reg 注册)[$REG_MODE] · $(L federation 联邦)[$([ "$ENABLE_FEDERATION" = 1 ] && L on 开 || L off 关)] · $(L calls 通话)[$([ "$ENABLE_CALLS" = 1 ] && L on 开 || L off 关)] · $(L web 网页客户端)[$([ "$ENABLE_WEB" = 1 ] && L on 开 || L off 关)] · $(L admin 管理后台)[$([ "$ENABLE_ADMIN" = 1 ] && L on 开 || L off 关)] · $(L phone-signup 手机App注册)[$([ "$ENABLE_ELEMENTX" = 1 ] && L on 开 || L off 关)] · $(L big-files 大文件)[$(human "$MAX_UPLOAD_BYTES")] · $(L "engine tuwunel/Rust, no Postgres" "引擎 tuwunel/Rust,免Postgres"))

 ${C_B}${C_YELLOW}$(L "Member signup / login" "成员注册 / 登录")${C_RESET}$([ -n "$WEB_URL" ] && printf '\n   %s' "$(L "Web (recommended): open $C_B$C_GREEN$WEB_URL$C_RESET in a browser to register & log in — your own domain, no element.io, no app (works in mobile browsers too)." "网页版(推荐):浏览器打开 $C_B$C_GREEN$WEB_URL$C_RESET 直接注册登录 —— 你自己的域名,不用去 element.io、不用装 App(手机浏览器也能用)。")")
   $(L "Phone app: install ${C_B}Element X${C_RESET} (app store) → server address = ${C_B}$DOMAIN${C_RESET} → " "手机 App:装 ${C_B}Element X${C_RESET}(应用商店)→ 服务器地址填 ${C_B}$DOMAIN${C_RESET} → ")$([ "$ENABLE_ELEMENTX" = 1 ] && L "register directly (invite token required) or log in — native OIDC is on" "可【直接注册】(需邀请码)或登录 —— 已开启原生 OIDC" || L "log in with username + password (Element X can't register; create accounts via web or adduser below)" "用【用户名+密码登录】(Element X 不支持注册;账号请走网页或下面的 adduser)")
$([ "$REG_MODE" = "token" ] && L "   (invite token is in CREDENTIALS.txt; or run sudo tuwunel adduser to create an account and send it to the member, who logs in with Element X using the password)" "   (邀请码在 CREDENTIALS.txt;或直接 sudo tuwunel adduser 建好账号发给成员,成员用 Element X 密码登录)")

 ${C_B}${C_YELLOW}$(L "Admin (created automatically — no manual signup)" "管理员(已自动创建,不用你手动注册)")${C_RESET}
$ADMIN_INFO
   $(L "(credentials stored in $INSTALL_DIR/CREDENTIALS.txt)" "(凭据存于 $INSTALL_DIR/CREDENTIALS.txt)")
$([ -n "$ADMIN_URL" ] && printf '\n %s%s%s%s\n   %s\n   %s\n   %s' "$C_B" "$C_YELLOW" "$(L "Web admin panel (graphical, recommended)" "Web 管理后台(图形化,推荐)")" "$C_RESET" "$(L "Open $C_B$C_GREEN$ADMIN_URL$C_RESET in a browser, log in with the admin user/password above." "浏览器打开 $C_B$C_GREEN$ADMIN_URL$C_RESET,用上面的管理员账号密码登录。")" "$(L "Graphically manage members, issue/revoke invite codes, view rooms & media, deactivate accounts, reset passwords — no commands." "可【图形化】管理成员、发/吊销邀请码、看房间与媒体、停用账号、改密码——不用敲命令。")" "$(L "(panel locked to your server; Ketesa, officially supported by tuwunel)" "(面板锁定到你的服务器;成熟面板 Ketesa,tuwunel 官方支持)")")

 $(L "Day-to-day management (global command installed — no paths, no domain needed):" "日常管理(已装好全局命令,不用记路径、不用再带域名):")
   ${C_B}sudo tuwunel${C_RESET}          $(L "open the management menu" "打开管理菜单")
   ${C_B}sudo tuwunel adduser${C_RESET}  $(L "add a member (one command: create account + set password)" "加成员(一条命令建号并设密码)")
$CALL_NOTE
 $(L "Send big files/photos/long videos:" "发大文件/大图/长视频:") $(L "the limit is set to" "已把上限设到") $(human "$MAX_UPLOAD_BYTES")$(L ", just send them in chat." ",直接在聊天里发即可。")
   $(L "Note: media is stored in data/tuwunel (local disk); big videos grow it fast, watch disk; very large files in E2EE rooms use more client memory." "注意:媒体存在 data/tuwunel(本地盘),大视频涨盘快,留意磁盘;E2EE 房超大文件较吃客户端内存。")

 $(L "Self-check:" "自检:")
   curl -s https://$DOMAIN/.well-known/matrix/client
   cd $INSTALL_DIR && docker compose ps    # $(L "all containers should be running" "容器都应 running")

 ${C_YELLOW}$(L "⚠️ Cloud security group must allow: $PORT_LINE" "⚠️ 云安全组放行: $PORT_LINE")${C_RESET}
$([ -n "$ADMIN_URL" ] && printf ' %s%s%s' "$C_DIM" "$(L "Note: the Ketesa admin panel relies on tuwunel v1.8.1+ Synapse admin API (newer); if the panel login errors, first run docker compose pull tuwunel. Core features (users/invites/rooms/media) work; reports/rate-limit and other edge pages being unavailable is normal." "提示:管理后台 Ketesa 依赖 tuwunel v1.8.1+ 的 Synapse 管理 API(较新);若面板登录报错,先 docker compose pull tuwunel 拉最新版。核心功能(用户/邀请码/房间/媒体)可用,举报/限速等边角页面不可用属正常。")" "$C_RESET")
${C_GREEN}========================================================${C_RESET}
EOF
