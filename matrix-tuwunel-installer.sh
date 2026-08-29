#!/usr/bin/env bash
# =====================================================================
#  Matrix 轻量一键安装脚本 · tuwunel 版(通用版 t1.23)
#  Matrix one-command installer · tuwunel edition (Universal t1.23)
#  t1.23:【VeilX 自研管理后台】管理后台新增选择:VeilX 自研(默认)/ Ketesa。自研后台是
#         纯静态 SPA(内嵌进本脚本,Caddy file_server 托管,不另起容器),只调 tuwunel 真正
#         支持的接口——用户/邀请码/房间(含发布到公开目录)都能用,不像 Ketesa 有一堆坏页。
#         并接入 VeilX 专属能力:【设备安全】远程冻结/销毁(走 OPRF 服务新增的 /oprf/admin/*
#         管理员路由,服务端校验管理员身份,对任意账号操作、无需停容器)。ADMIN_UI=veilx|ketesa。
#  t1.22:【默认孤岛·不再逐项问】隔离与加固写死,安装向导从 8 问精简到 3 问。
#         固定(不再询问):注册=令牌、联邦=关、只面向VeilX、不装Element Web、
#         隐私加固=开、OPRF=开。VeilX 本就是"自建、只服务本团队"的孤岛,这些是产品
#         定义而非可选项,选错任何一个都会破坏保密模型。仅保留 3 个纯功能问题:
#         【通话 / 管理后台 / 文件上限】。极个别破例仍可用环境变量显式覆盖(如
#         ENABLE_FEDERATION=1),但绝不弹交互;重跑配置一律回到孤岛默认。
#  t1.21:【团队通讯录】两件事一起放开,让团队【用户+房间】都可被发现:
#         ① show_all_local_users_in_user_directory=true —— 任何成员都能搜到本服全部用户
#            (默认只显示"同过房/公开房里"的人,新同事谁都搜不到)。
#         ② lockdown_public_room_directory=false —— 普通成员建的公开房也能进目录被搜到
#            (原隐私加固块把它锁成"仅管理员可发布",于是成员建的公开房永远搜不到;
#            且该块还把 ① 又设回 false,把团队通讯录整个抵消掉 —— 现已从隐私块移除,
#            两个开关统一在 [global] 按团队模型设置)。私密房间不受影响,外服由客户端域名过滤挡住。
#         老服务器:`sudo tuwunel` 菜单重跑配置(或手动改 tuwunel.toml 后重启容器)即可生效;
#         已经建出来的公开房是"未发布"状态,需重新发布一次(重建,或在客户端里把它设为公开)。
#  t1.20:【只面向 VeilX 客户端】新增【选项 8/8】(默认开,VEILX_ONLY=1|0|strict)。开启后
#         ①不部署 Element Web ②关掉 Element X 自助注册(原生 OIDC) ③Caddy 拒绝
#         User-Agent 不含 VeilX 的 /_matrix/client/* 与 /_synapse/admin/*。
#         动机:阅后即焚等策略是【由客户端执行】的,队里有一个人用 Element,
#         他的旧消息就永远不会被清掉,房间策略对他形同虚设。
#         ⚠️ 这是【门槛】不是【保证】:UA 是客户端自述字符串,伪造成本约等于零,
#         已登录的会话也不受影响。真要强制只能上应用完整性证明,而那与本项目
#         "能在去 Google 化手机上跑"冲突。别对外宣称成安全边界。
#         刻意保留的放行:/_matrix/client/versions(规范公开,且安装器就绪检查、
#         菜单在线检查、客户端加速验证都在打它)、/_matrix/federation/* 与
#         /_matrix/key/*(否则开联邦会整个断掉)。
#         管理后台**不在 matrix 主机上开任何例外**:Ketesa 改成同源走 admin 主机,
#         在那里单独放行它真正调用的十来个端点(login/whoami/profile/publicRooms/
#         directory/media/_synapse/admin/*)——这份清单里没有 /sync、没有
#         /rooms/*/messages、没有 /send,所以把 Element 指过去也同步不了、发不出。
#         (早先草案在 matrix 主机放行 `Origin: https://admin.<域名>`,那是个人人可用的
#          口子:Origin 同样是自述头,admin 子域又是公开 DNS,加个请求头即可全绕。)
#  t1.19:【远程停用】服务器可远程让员工手机①冻结=加密上锁(可撤销)②销毁=永久不可解。
#         指令用服务器的 Ed25519 私钥签名(/data/signing.key 首次启动自动生成,0600),
#         客户端在启用最高档时固定公钥,**中间人无法伪造销毁指令去毁掉任意员工数据**。
#         新增: GET /oprf/pubkey(公开)、POST /oprf/status(签名裁决 ok/frozen/killed)、
#         `--admin-reap <天>` 长期未签到自动【冻结】(配 cron;可撤销,≥7 天才受理)。
#         要不可逆销毁得显式用 `--admin-reap-destroy <天>`。
#         限速 12→30 次/小时(客户端后台立即零化后解锁更频繁,12 会误伤正常使用)。
#         修复: 应急处置里的"吊销登录会话"原用 `tuwunel --execute`,但服务器运行时
#         RocksDB 被占锁必然失败;tuwunel 只能在【管理员房间】发 !admin 命令,
#         现改为打印确切命令让运维执行,不再假装已完成。
#  t1.18:【修复 OPRF 卡死/502】t1.17 的成员管理少了 docker compose run 的 -T,在 SSH 里
#         会挂起、占着数据库锁,导致主容器崩溃循环、全队最高档手机被锁在外面。本版:
#         ①run 一律加 -T + trap 兜底 + 管理后强制验证服务复活;②容器打不开锁时不再 panic
#         死循环,而是等锁释放最多 30s;③新增 `sudo tuwunel oprf-repair`(菜单第 3 项)
#         一键强杀卡死容器+干净重启(绝不碰数据库文件);④管理前先清理残留的 -run- 容器。
#  t1.17:【VeilX 加固:服务器辅助 PIN(OPRF)】新增可选组件,安装时【选项 7/8】默认开,
#         装好后菜单 o) 项或 `sudo tuwunel oprf` 管理(状态/开关/销毁某成员密钥/日志),
#         也可 `sudo tuwunel enable-oprf|disable-oprf`。作用:VeilX 手机解锁必须问这台服务器,
#         于是【失窃且离线的手机永远无法爆破 PIN】,设备丢失或员工离职时可远程销毁其密钥让手机永久打不开。
#         实现:docker 服务(oprf/,多阶段编译 Rust,不在宿主机装工具链),Caddy 把
#         matrix.域名/oprf/ 反代到它——复用现有证书,不需新域名/DNS。它看不到任何人的 PIN。
#         容错:OPRF 是唯一需本地编译的服务,故在主 up -d 前单独 build,失败自动退回未开启
#         并摘掉编排/路由,保证聊天服务照常可用。
#  t1.16:【装好后可随时切换界面语言】此前语言只在首次安装时问一次、之后无处可改。现新增
#         菜单项 L 与 `sudo tuwunel lang`:在 English / 简体中文 间切换,写入 .env(UI_LANG=)持久化,
#         菜单立即用新语言重绘。(老服务器需先把副本更新到本版,见 t1.15 补救。)
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
#  t1.10:【保密加固/机密最小化】(1) 修复关键缺口:强制新房间默认 E2EE
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
#      sudo tuwunel lang            # 【切换界面语言】English / 简体中文(存 .env,持久生效)
#      sudo tuwunel enable-elementx # 【开 Element X 手机自助注册】(原生OIDC;disable-elementx 关)
#      sudo tuwunel cf-cert         # 【全橙云】粘贴 CF Origin 证书(橙云下 Caddy 签不出证书时用)
#                                     #   cf-cert status 看到期  /  cf-cert off 关掉回自动 HTTPS
#      sudo tuwunel privacy        # 隐私/元数据:看能删什么、查加固状态、清日志
#      sudo tuwunel forget-secrets  # 无痕清理:涂销磁盘上的明文密码/邀请码
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
#    ADMIN_SUB=veilx            后台子域名(默认:VeilX 自研=veilx、Ketesa=admin;可设 console 等,需加对应 DNS)
#    ADMIN_UI=veilx|ketesa      用哪个管理后台(默认 veilx=自研;ketesa=通用 synapse-admin)
#    CDN=1|0                    服务器前是否有 Cloudflare/CDN 代理(默认 0;放宽 DNS 预检)
#    CF_ORIGIN=1|0              全橙云:用 CF Origin 证书替代自动 HTTPS(默认 0)
#                               橙云下 Caddy 的 ACME 必失败(TLS-ALPN-01 被 CF 终止、
#                               HTTP-01 在 Full(Strict) 下死锁),故须自带证书。
#                               代价:上传上限 100MB、通话不可用、VeilX 代理不可用。
#    MAX_UPLOAD=4G              单文件上限(默认 4G;支持 K/M/G,内部转字节)
#    VEILX_ONLY=1|0|strict      只面向 VeilX 客户端(默认 1)。开启时:
#                               ① 不部署 Element Web ② 关掉 Element X 自助注册(原生 OIDC)
#                               ③ Caddy 只放行 User-Agent 含 VeilX 的 /_matrix/client/*
#                                  与 /_synapse/admin/*(/versions 永远放行)
#                               strict = 连管理后台的例外也不留,并自动关掉 Ketesa
#                               ⚠️ 这是【门槛】不是【保证】:UA 是客户端自述字符串,
#                                  改个 UA 即可绕过。真要强制只能上应用完整性证明
#                                  (Play Integrity/App Attest),而那与本项目的去 Google 化冲突。
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
# 安装器自己的 User-Agent。**必须含 "VeilX"**:开了 VEILX_ONLY 之后,Caddy 只放行
# UA 含 VeilX 的 /_matrix/client/*,而建号走的正是 /_matrix/client/v3/register ——
# 不带这个,新装时【自动创建管理员】和 `sudo tuwunel adduser` 都会被自己的拦截 403。
INSTALLER_UA="VeilX-Installer/1.0"
register_user() {
  local u="$1" p="$2" hs="$3" tok="$4" r sess eu ep et es
  eu="$(json_esc "$u")"; ep="$(json_esc "$p")"; et="$(json_esc "$tok")"
  # UIAA 第一步:拿 session
  r="$(curl -4 -sS --max-time 15 -A "$INSTALLER_UA" -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$eu\",\"password\":\"$ep\",\"inhibit_login\":true}" 2>/dev/null || true)"
  case "$r" in *'"user_id"'*) return 0 ;; esac   # 万一无需 UIAA 直接成功
  sess="$(printf '%s' "$r" | grep -o '"session"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  [ -n "$sess" ] || return 1
  es="$(json_esc "$sess")"
  # 第二步:带注册令牌
  r="$(curl -4 -sS --max-time 15 -A "$INSTALLER_UA" -X POST "$hs/_matrix/client/v3/register" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$eu\",\"password\":\"$ep\",\"inhibit_login\":true,\"auth\":{\"type\":\"m.login.registration_token\",\"token\":\"$et\",\"session\":\"$es\"}}" 2>/dev/null || true)"
  case "$r" in
    *'"user_id"'*) return 0 ;;
    *'m.login.dummy'*)   # 部分实现在令牌后还要 dummy 阶段
      r="$(curl -4 -sS --max-time 15 -A "$INSTALLER_UA" -X POST "$hs/_matrix/client/v3/register" \
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
  local vonly vonly_txt; vonly="$(env_saved VEILX_ONLY)"
  case "$vonly" in
    0|"")   vonly_txt="$(L "off (any Matrix client)" "关(任何 Matrix 客户端)")" ;;
    strict) vonly_txt="$(L "STRICT (no admin-panel exception)" "严格(不留后台例外)")" ;;
    *)      vonly_txt="$(L "on (non-VeilX clients refused)" "开(拒绝非 VeilX 客户端)")" ;;
  esac
  echo "  $(L "VeilX-only" 仅VeilX): $vonly_txt"
  echo "  $(L Hardening 加固): $([ "$(env_saved ENABLE_OPRF)" = "1" ] && L "server-assisted PIN ON" "服务器辅助PIN 已开" || L "off" 未开)"
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
  _pk(){ if grep -qE "^$1[[:space:]]*=" tuwunel.toml 2>/dev/null; then echo "  ✔ $2"; else echo "  ✘ $2 $(L "(not enabled)" "(未启用)")"; fi; }
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
      echo "$(L "but they are the highest-value target for anyone who gets physical access to the disk after a disk image. This wipes those two lines; the file stays (as a deployment marker)." "却是拿到磁盘镜像的人\"一击拿走\"的最高价值目标。此操作会把这两行涂掉,文件保留(作部署标记)。")"
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

# 设备应急处置:设备丢失/失窃/员工离职时对该账号的密钥做处置。
# 分层的关键:【冻结】可撤销,是刚发现异常那几小时该做的事(还不知道设备能不能找回);
# 【销毁】不可撤销,确认拿不回来了再用。只有这两级分开,管理员才敢在第一时间动手。
menu_oprf_members() {
  cd "$INSTALL_DIR" 2>/dev/null || return
  local D; D="$(env_saved MATRIX_DOMAIN)"
  # 处置时可顺带吊销该账号的 Matrix 登录会话:否则拿到手机的人若赶上【已解锁+联网】
  # 状态,仍能用这个账号继续收发消息、看群里在说什么。
  # tuwunel is administered from its ADMIN ROOM, not the CLI: `tuwunel --execute`
  # cannot run while the server holds the RocksDB lock, so the old attempt here
  # always failed. Deactivating is the operator's most urgent action (it removes
  # the member from every room, which rotates the Megolm keys so the compromised
  # account stops receiving new messages), so spell out the exact command rather
  # than pretend to have done it.
  _revoke_sessions() {
    local acct="$1"
    printf '\n%s\n' "$(L "  ACTION REQUIRED — in the admin room of your VeilX/Element client, send:" "  需要你手动执行 —— 在客户端的【管理员房间】里发送:")"
    printf '      %s\n' "!admin users deactivate $acct"
    printf '%s\n' "$(L "  This removes them from every room and rotates the encryption keys, so the compromised account can no longer read new messages or impersonate them." "  这会把该账号踢出所有房间并轮换加密密钥,失控的账号从此读不到新消息、也无法冒充该员工发言。")"
    return 0
  }
  # sled 是单进程独占的:任何管理操作都必须先停服务容器,否则打不开数据库。
  # 停机时间约 1-2 秒;期间成员解锁会失败(会自动重试)。
  # 关键:必须带 -T(不分配伪终端),否则在 SSH/脚本里 `run` 会挂起等待终端、
  # 一直占着数据库锁,导致随后启动的主容器打不开库而崩溃重启(502)。
  # 用 trap 兜底:无论中途出什么错,一定把主容器重新拉起来。
  _oprf_admin() {
    local out rc
    docker compose stop oprf >/dev/null 2>&1
    # Clean up any leftover one-off admin container that could still hold the lock.
    docker ps -aq --filter name=oprf-run 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1
    trap 'docker compose up -d oprf >/dev/null 2>&1' RETURN
    out="$(docker compose run --rm -T oprf "$@" 2>&1)"; rc=$?
    docker compose up -d oprf >/dev/null 2>&1
    trap - RETURN
    # Never leave the service down: if it didn't come back healthy, force a clean
    # restart so highest-tier phones aren't locked out.
    sleep 2
    if ! docker compose ps --status running -q oprf 2>/dev/null | grep -q .; then
      warn "$(L "OPRF service didn't come back — forcing a clean restart…" "OPRF 服务没能自动恢复 —— 正在强制干净重启…")"
      oprf_repair
    fi
    printf '%s' "$out"
    return $rc
  }
  while :; do
    printf '\n%s\n' "$(L "── Device incident response ──" "── 设备应急处置 ──")"
    printf '%s\n' "$(L '
  Device lost, stolen, or an employee leaving? FREEZE first — it blocks that phone
  from unlocking but keeps the key, so you can undo it if the device turns up. Only
  DESTROY once you are sure: that is permanent, and even the correct PIN will never
  open it again.' '
  设备丢失/失窃,或员工离职?先【冻结】—— 挡住那台手机解锁,但保住密钥,设备找回可撤销。
  确认拿不回来了再【销毁】——不可逆,之后连正确的 PIN 也永远打不开。')"
    echo ""
    echo "  1) $(L "Device status (who is enrolled; keys are never shown)" "查看设备状态(谁启用了;不显示任何密钥)")"
    echo "  2) $(L "FREEZE an account (reversible — use this first)" "【冻结】某账号(可撤销 —— 第一时间用这个)")"
    echo "  3) $(L "Release an account (undo freeze)" "【解冻】某账号(撤销冻结)")"
    echo "  4) $(L "DESTROY an account's key (permanent)" "【销毁】某账号的密钥(永久,不可逆)")"
    echo "  5) $(L "DESTROY EVERY ENROLLED DEVICE (org-wide incident)" "【全员销毁】(全组织级安全事件)")"
    echo "  0) $(L Back 返回)"
    local R=""; if [ -t 0 ]; then read -rp "$(L "Select: " "请选择: ")" R || return; else read -rp "$(L "Select: " "请选择: ")" R < /dev/tty 2>/dev/null || return; fi
    local acct="" c=""
    case "$R" in
      1)
        echo ""
        printf '  %-34s %-12s %-10s %s\n' "$(L ACCOUNT 账号)" "$(L STATE 状态)" "$(L "USED/HR" 本小时)" "$(L "LAST USE" 最近使用)"
        _oprf_admin --admin-list 2>/dev/null | grep -E '^@' | while IFS=$'\t' read -r a s c2 ls; do
          local st when
          case "$s" in
            destroyed) st="$(L destroyed 已销毁)";;
            frozen)    st="$(L frozen 已冻结)";;
            *)         st="$(L ok 正常)";;
          esac
          if [ "${ls:-0}" = "0" ]; then when="—"; else when="$(date -d "@$ls" '+%m-%d %H:%M' 2>/dev/null || echo "$ls")"; fi
          printf '  %-34s %-12s %-10s %s\n' "$a" "$st" "${c2:-0}" "$when"
        done
        echo ""
        echo "$(L "  (empty = nobody has enabled the highest level yet)" "  (空 = 还没有员工启用最高级别)")" ;;
      2|3|4)
        read -rp "$(L "Full user id (e.g. @li:$D): " "完整用户 id(如 @li:$D): ")" acct || continue
        [ -n "$acct" ] || continue
        case "$R" in
          2) # 必须确认真的生效:紧急时刻误报"已冻结"比失败更危险。
             if _oprf_admin --admin-freeze "$acct" | grep -q '^ok'; then
               ok "$(L "FROZEN: $acct can no longer unlock. Reversible — use 'Release' when safe." "已冻结:$acct 暂时无法解锁。可撤销 —— 人安全后用【解冻】。")"
               printf "%s" "$(L "  Also revoke their Matrix login sessions? [y/N]: " "  是否同时吊销他的 Matrix 登录会话? [y/N]: ")"
               read -r c || c=""
               case "$c" in y|Y) _revoke_sessions "$acct";; esac
             else
               warn "$(L "NOT frozen — no such account, or it was already destroyed. Check the status list." "未能冻结 —— 没有这个账号,或已被销毁。请查看成员状态。")"
             fi ;;
          3) if _oprf_admin --admin-unfreeze "$acct" | grep -q '^ok'; then
               ok "$(L "Released: $acct can unlock again." "已解冻:$acct 可以正常解锁了。")"
             else
               warn "$(L "Failed — no such account, or it was already destroyed." "失败 —— 没有这个账号,或已被销毁。")"
             fi ;;
          4) warn "$(L "PERMANENT: even the correct PIN will never open $acct's phone again." "不可逆:之后连正确的 PIN 也永远打不开 $acct 的手机。")"
             read -rp "$(L "Type yes to confirm: " "输入 yes 确认: ")" c || continue
             [ "$c" = yes ] || { echo "$(L Cancelled 已取消)"; continue; }
             if _oprf_admin --admin-kill "$acct" | grep -q '^killed'; then
               ok "$(L "Destroyed. $acct's phones can never be unlocked." "已销毁。$acct 的手机再也无法解锁。")"
             else warn "$(L "Failed — check: docker compose logs oprf" "失败 —— 请查: docker compose logs oprf")"; fi
             printf "%s" "$(L "  Also revoke their Matrix login sessions? [Y/n]: " "  是否同时吊销他的 Matrix 登录会话? [Y/n]: ")"
             read -r c || c=""
             case "$c" in n|N) :;; *) _revoke_sessions "$acct";; esac ;;
        esac ;;
      5)
        warn "$(L "This destroys EVERY member's key. Every VeilX phone on this server becomes permanently unopenable. There is no undo." "这会销毁【所有成员】的密钥。本服务器上每一台 VeilX 手机都将永久打不开。无法撤销。")"
        read -rp "$(L "Type DESTROY ALL to confirm: " "输入 DESTROY ALL 确认: ")" c || continue
        [ "$c" = "DESTROY ALL" ] || { echo "$(L Cancelled 已取消)"; continue; }
        _oprf_admin --admin-kill-all | grep -E '^killed' || true
        ok "$(L "All member keys destroyed." "全部成员密钥已销毁。")" ;;
      0|"") return ;;
    esac
    press_enter "
$(L "Press Enter to continue… " "按回车继续… ")"
  done
}

# VeilX 加固(服务器辅助 PIN):状态 / 开关 / 远程销毁某账号的密钥。
menu_oprf() {
  cd "$INSTALL_DIR" 2>/dev/null || { warn "$(L "Deployment directory not found" "未找到部署目录")"; return; }
  local D; D="$(env_saved MATRIX_DOMAIN)"
  while :; do
    local on running
    oprf_enabled && on=1 || on=0
    running=$(docker compose ps --status running -q oprf 2>/dev/null | grep -c . || echo 0)
    printf '\n%s\n' "$(L "── VeilX hardening: server-assisted PIN ──" "── VeilX 加固:服务器辅助 PIN ──")"
    printf '%s\n' "$(L '
  What it does: VeilX phones must ask THIS server to unlock. So a lost or stolen
  phone that is OFFLINE can never be brute-forced, and you can destroy the key of a
  device you cannot get back, making it permanently unopenable. It never sees any PIN.' '
  作用:VeilX 手机解锁时必须问【这台服务器】。于是失窃且【离线】的手机永远无法爆破
  PIN;设备拿不回来时你可销毁其密钥,让那台手机永久打不开。它全程看不到任何人的 PIN。')"
    echo ""
    echo "  $(L Status 状态): $([ "$on" = 1 ] && L "ON" "已开启" || L "OFF" "未开启")   $(L Container 容器): $([ "$running" -gt 0 ] && L running 运行中 || L "not running" 未运行)"
    [ "$on" = 1 ] && echo "  $(L "Client endpoint (the app finds this automatically)" "客户端端点(App 会自动找到)"): https://matrix.$D/oprf/"
    echo ""
    if [ "$on" = 1 ]; then
      echo "  1) $(L "DEVICE INCIDENT RESPONSE (lost / stolen / offboarding: freeze / release / destroy)" "【设备应急处置】(丢失 / 失窃 / 离职:冻结 / 解冻 / 销毁)")"
      echo "  2) $(L "Logs" 查看日志)"
      echo "  3) $(L "RESTART / REPAIR service (if phones can't unlock / 502)" "重启 / 修复服务(手机解不了锁 / 502 时)")"
      echo "  4) $(L "Turn OFF (phones fall back to PIN + hardware only)" "关闭(手机退回仅 PIN + 硬件加密)")"
    else
      echo "  1) $(L "Turn ON" 开启)"
    fi
    echo "  0) $(L Back 返回)"
    local R=""; if [ -t 0 ]; then read -rp "$(L "Select: " "请选择: ")" R || return; else read -rp "$(L "Select: " "请选择: ")" R < /dev/tty 2>/dev/null || return; fi
    case "$R" in
      1) if [ "$on" = 1 ]; then menu_oprf_members
         else
           [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" enable-oprf || warn "$(L "script copy missing" "缺少脚本副本")"
           return
         fi ;;
      2) [ "$on" = 1 ] && { docker compose logs --tail 50 oprf 2>/dev/null || true; } ;;
      3) [ "$on" = 1 ] && oprf_repair ;;
      4) [ "$on" = 1 ] || continue
         [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" disable-oprf || warn "$(L "script copy missing" "缺少脚本副本")"
         return ;;
      0|"") return ;;
    esac
  done
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
  # 【必须一起备份 data/oprf】最高档(服务器辅助 PIN)的每账号密钥 k 只存在这里 ——
  # 丢了它,所有最高档用户的本地消息库【永远打不开】,备份里的聊天记录也救不回来
  # (库是用 PIN+k 派生的密钥加的);signing.key 也在里面,丢了远程停用的签名就验不过。
  BK_PATHS=".env tuwunel.toml data/tuwunel"
  [ -d data/oprf ] && BK_PATHS="$BK_PATHS data/oprf"
  ( umask 077; tar czf - $BK_PATHS 2>/dev/null \
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
  # data/oprf 同上:最高档的每账号密钥 k 与 signing.key 都在里面,不备份=最高档用户数据永久锁死。
  BK_PATHS=".env CREDENTIALS.txt tuwunel.toml data/tuwunel"
  [ -d data/oprf ] && BK_PATHS="$BK_PATHS data/oprf"
  if [ -n "$pw" ]; then
    # 口令走环境变量(不进 argv/ps),openssl 从 stdin 读 tar 流并加密
    tar czf - $BK_PATHS 2>/dev/null \
      | BKPW="$pw" openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass env:BKPW -out "$f" 2>/dev/null || true
  else
    tar czf "$f" $BK_PATHS 2>/dev/null || true
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

# =====================================================================
#  VeilX 专用代理(VLESS + XTLS-Vision + REALITY)
#  ------------------------------------------------------------------
#  为什么这台机器特别适合做 REALITY:REALITY 需要"借"一个真实网站的 TLS
#  握手来伪装,而本机【本来就在跑真实的 Matrix/Element 站点 + 真实证书】。
#  于是 dest 直接指向本机的 Caddy —— 探测者打过来看到的是【货真价实】的
#  站点和证书,IP↔域名↔证书三者完全自洽(比借 microsoft.com 更难被识破)。
#
#  端口布局(开启后):
#    :80/tcp   → Caddy      (保留!ACME HTTP-01 续证靠它)
#    :443/tcp  → Xray       ├─ 合法 VeilX 客户端 → freedom 出网
#                           └─ 其他任何人/主动探测 → caddy:443 → 真实站点
#    :443/udp  → 不发布      (否则浏览器走 HTTP/3 会绕过 Xray)
#
#  客户端凭据存 xray/clients.tsv,config.json 每次由它重新生成(不依赖 jq)。
# =====================================================================
XRAY_IMAGE="${XRAY_IMAGE:-ghcr.io/xtls/xray-core:latest}"

px_dir()      { echo "$INSTALL_DIR/xray"; }
px_clients()  { echo "$INSTALL_DIR/xray/clients.tsv"; }
px_enabled()  { [ "$(env_saved ENABLE_PROXY)" = "1" ]; }
oprf_enabled(){ [ "$(env_saved ENABLE_OPRF)" = "1" ]; }

# 强杀所有卡住的 oprf 容器(释放 sled 锁)并起一个干净的。绝不碰数据库文件,只动容器。
# 用于:管理操作后没自动恢复、或容器崩溃循环时的一键自救。
oprf_repair() {
  cd "$INSTALL_DIR" 2>/dev/null || return 1
  docker compose stop oprf >/dev/null 2>&1
  docker ps -aq --filter name=oprf 2>/dev/null | xargs -r docker rm -f >/dev/null 2>&1
  docker compose up -d oprf >/dev/null 2>&1
  # CRITICAL: rm+recreate gives oprf a NEW container IP; Caddy caches the old one
  # and keeps returning 502. Restart caddy so it re-resolves the upstream.
  docker compose restart caddy >/dev/null 2>&1
  sleep 4
  if docker compose ps --status running -q oprf 2>/dev/null | grep -q .; then
    ok "$(L "OPRF service is running again (Caddy re-pointed)." "OPRF 服务已恢复运行(Caddy 已重新指向)。")"
  else
    warn "$(L "Still down — check: docker compose logs --tail 20 oprf" "仍未恢复 —— 请查: docker compose logs --tail 20 oprf")"
  fi
}

# ---- VeilX 加固:服务器辅助 PIN(OPRF)---------------------------------------
# 在 $INSTALL_DIR/oprf 写出 Dockerfile + Rust 源码(由 compose 的 build: 编译)。
# 协议 ristretto255 2HashDH:客户端发盲化点 B=r·P,服务端回 E=k·B,客户端解盲得 k·P。
# 服务端全程看不到 PIN;k 只存在本机 sled 库里,永不下发。
oprf_write_files() {
  mkdir -p oprf/src data/oprf
  chown -R 10001:10001 data/oprf 2>/dev/null || true
  cat > oprf/Dockerfile <<'EOF'
FROM rust:1-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY Cargo.toml ./
COPY src ./src
RUN cargo build --release

FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/target/release/veilx-oprf-guard /usr/local/bin/veilx-oprf-guard
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/veilx-oprf-guard"]
EOF
  cat > oprf/Cargo.toml <<'EOF'
[package]
name = "veilx-oprf-guard"
version = "0.1.0"
edition = "2021"
description = "Server half of VeilX's server-assisted PIN (ristretto255 OPRF), with per-account rate limiting, reversible freeze, and signed remote-deactivation verdicts."

[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["rt-multi-thread", "macros", "net"] }
curve25519-dalek = { version = "4", features = ["rand_core"] }
rand_core = { version = "0.6", features = ["getrandom"] }
sled = "0.34"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
base64 = "0.22"
# Token verification against the homeserver (whoami). rustls to avoid OpenSSL.
reqwest = { version = "0.12", default-features = false, features = ["json", "rustls-tls"] }
# Signs the remote-deactivation verdicts the client verifies against a pinned key.
ed25519-dalek = { version = "2", features = ["rand_core"] }

[profile.release]
strip = true
lto = true
EOF
  cat > oprf/src/main.rs <<'EOF'
//! VeilX OPRF guard — server half of the server-assisted PIN.
//!
//! Holds a per-account ristretto255 secret `k` and evaluates `E = k · B` on the
//! client's blinded point `B`. It never sees the PIN (only the blinded point) and
//! never returns `k`. Because unlocking needs this evaluation, a lost OFFLINE
//! device cannot brute-force the PIN — and this server can refuse (remote
//! deactivation), plus it rate-limits so even online guessing is hopeless.
//!
//! HTTP (JSON):
//!   POST /oprf/eval    { "account", "blinded" }  Authorization: Bearer <matrix token>
//!         -> { "evaluated" }        429 rate-limited/frozen · 410 destroyed
//!   POST /oprf/kill    { "account" }             Authorization: Bearer <matrix token>
//!         -> 204. NOTE: authenticated **as the account owner** — this is the
//!         "I lost my phone, kill it from my other device" path. An operator
//!         acting on someone else's account uses the local `--admin-*` commands
//!         below, which is why they exist.
//!   GET  /oprf/pubkey  -> { "pubkey" }  public; the client pins it at enrollment
//!   POST /oprf/status  { "account" }             Authorization: Bearer <matrix token>
//!         -> { "state": ok|frozen|killed, "ts", "sig" }, Ed25519-signed over
//!         "account:state:ts" so a hostile network can't forge a verdict.
//!
//! Operator surface (server-admin only; drives the VeilX admin console). The
//! bearer token is checked against the homeserver's admin API, so only an
//! operator — not the account owner — can act on someone else's account. These
//! run against the RUNNING process (no container stop, unlike the CLI below):
//!   GET  /oprf/admin/list                        -> [{account,state,count,last_seen}]
//!   POST /oprf/admin/freeze   { "account" }      -> 204  (reversible hold)
//!   POST /oprf/admin/unfreeze { "account" }      -> 204
//!   POST /oprf/admin/kill     { "account" }      -> 204  (PERMANENT destroy)
//!
//! Local admin (run by the installer, never exposed over HTTP — deliberately has
//! no way to print `k`):
//!   --admin-list · --admin-freeze <acct> · --admin-unfreeze <acct>
//!   --admin-kill <acct> · --admin-kill-all
//!   --admin-reap <days>          冻结长期未签到的账号（可撤销，默认行为）
//!   --admin-reap-destroy <days>  同上但永久销毁（不可逆，需显式选择）
//!
//! Config via env: BIND, DB, HOMESERVER, RATE_LIMIT, RATE_WINDOW_SECS,
//! SIGNING_KEY (defaults to `signing.key` next to the database).
//!
//! ⚠️ 这个文件是**单一事实来源**。两个安装器内嵌的副本由
//!    `veilx_matrix_ocs/scripts/sync-oprf.py` 从这里生成 —— 改完请跑一次 --write。
use axum::{extract::State, http::StatusCode, routing::{get, post}, Json, Router};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use curve25519_dalek::{ristretto::CompressedRistretto, scalar::Scalar};
use ed25519_dalek::{Signer, SigningKey};
use rand_core::OsRng;
use serde::{Deserialize, Serialize};
use std::{sync::Arc, time::{SystemTime, UNIX_EPOCH}};

#[derive(Clone)]
struct App {
    db: sled::Db,
    http: reqwest::Client,
    homeserver: String,
    rate_limit: u32,
    rate_window: u64,
    // Ed25519 key the client pins at enrollment; every deactivation status response
    // is signed with it, so a man-in-the-middle cannot forge a "destroy" verdict.
    signing_key: SigningKey,
}
#[derive(Serialize, Deserialize)]
struct Record {
    k: [u8; 32],
    window_start: u64,
    count: u32,
    killed: bool,
    /// Reversible hold: refuses unlocks but keeps k, so an incident that turns out
    /// fine can be undone. `killed` destroys k and can never be undone.
    #[serde(default)]
    frozen: bool,
    /// Unix time of the last successful evaluation (for the admin status list).
    #[serde(default)]
    last_seen: u64,
}
#[derive(Deserialize)] struct EvalReq { account: String, blinded: String }
#[derive(Serialize)]   struct EvalResp { evaluated: String }
#[derive(Deserialize)] struct KillReq { account: String }

fn now() -> u64 { SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() }

/// The bearer token must belong to `account` — verified against the homeserver.
async fn verify(app: &App, headers: &axum::http::HeaderMap, account: &str) -> bool {
    let Some(tok) = headers.get(axum::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok()).and_then(|s| s.strip_prefix("Bearer ")) else { return false };
    let url = format!("{}/_matrix/client/v3/account/whoami", app.homeserver.trim_end_matches('/'));
    let Ok(resp) = app.http.get(&url).bearer_auth(tok).send().await else { return false };
    if !resp.status().is_success() { return false }
    let Ok(body) = resp.json::<serde_json::Value>().await else { return false };
    body.get("user_id").and_then(|v| v.as_str()) == Some(account)
}

async fn eval(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<EvalReq>)
    -> Result<Json<EvalResp>, StatusCode> {
    if !verify(&app, &headers, &req.account).await { return Err(StatusCode::UNAUTHORIZED) }
    let raw = B64.decode(req.blinded.as_bytes()).map_err(|_| StatusCode::BAD_REQUEST)?;
    let point = CompressedRistretto::from_slice(&raw).map_err(|_| StatusCode::BAD_REQUEST)?
        .decompress().ok_or(StatusCode::BAD_REQUEST)?;
    let key = req.account.as_bytes();
    let mut rec: Record = match app.db.get(key).ok().flatten() {
        Some(b) => serde_json::from_slice(&b).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?,
        None => Record { k: Scalar::random(&mut OsRng).to_bytes(), window_start: now(), count: 0,
                         killed: false, frozen: false, last_seen: 0 },
    };
    if rec.killed { return Err(StatusCode::GONE) }
    // Frozen: same refusal as rate-limited, so a phone in the wrong hands just
    // looks "try again later" rather than announcing that the account was frozen.
    if rec.frozen { return Err(StatusCode::TOO_MANY_REQUESTS) }
    let t = now();
    if t.saturating_sub(rec.window_start) >= app.rate_window { rec.window_start = t; rec.count = 0 }
    if rec.count >= app.rate_limit {
        let _ = app.db.insert(key, serde_json::to_vec(&rec).unwrap());
        return Err(StatusCode::TOO_MANY_REQUESTS);
    }
    rec.count += 1;
    rec.last_seen = t;
    let k: Scalar = Option::from(Scalar::from_canonical_bytes(rec.k)).ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;
    let evaluated = (point * k).compress().to_bytes();
    app.db.insert(key, serde_json::to_vec(&rec).unwrap()).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let _ = app.db.flush_async().await;
    Ok(Json(EvalResp { evaluated: B64.encode(evaluated) }))
}

/// Destroy this account's k — its devices become permanently unopenable.
async fn kill(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<KillReq>) -> StatusCode {
    if !verify(&app, &headers, &req.account).await { return StatusCode::UNAUTHORIZED }
    let rec = Record { k: [0u8; 32], window_start: now(), count: 0, killed: true, frozen: false, last_seen: 0 };
    let _ = app.db.insert(req.account.as_bytes(), serde_json::to_vec(&rec).unwrap());
    let _ = app.db.flush_async().await;
    StatusCode::NO_CONTENT
}

#[derive(Serialize)] struct PubkeyResp { pubkey: String }
#[derive(Deserialize)] struct StatusReq { account: String }
#[derive(Serialize)] struct StatusResp { state: String, ts: u64, sig: String }

/// The client pins this at enrollment; public, so no auth. It is only a *verify*
/// key — the private half never leaves the server.
async fn pubkey(State(app): State<Arc<App>>) -> Json<PubkeyResp> {
    Json(PubkeyResp { pubkey: B64.encode(app.signing_key.verifying_key().to_bytes()) })
}

/// Deactivation status: the phone polls this. The verdict is SIGNED over
/// "account:state:ts", so a hostile network cannot forge "killed" to destroy an
/// employee's data, nor forge "ok" that the client would trust over a real kill
/// (the client only ACTS on killed/frozen, and only when the signature checks).
///  - ok:     do nothing
///  - frozen: encrypt-and-lock now (reversible)
///  - killed: destroy now (permanent)
async fn status(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<StatusReq>)
    -> Result<Json<StatusResp>, StatusCode> {
    if !verify(&app, &headers, &req.account).await { return Err(StatusCode::UNAUTHORIZED) }
    let rec: Option<Record> = app.db.get(req.account.as_bytes()).ok().flatten()
        .and_then(|b| serde_json::from_slice(&b).ok());
    let state = match rec {
        Some(r) if r.killed => "killed",
        Some(r) if r.frozen => "frozen",
        _ => "ok",
    };
    let ts = now();
    let msg = format!("{}:{}:{}", req.account, state, ts);
    let sig = app.signing_key.sign(msg.as_bytes());
    Ok(Json(StatusResp { state: state.to_string(), ts, sig: B64.encode(sig.to_bytes()) }))
}

// ---- Operator (server-admin) HTTP surface ----
// Mirrors the `--admin-*` CLI, but authenticated as a **server admin** and run
// against the live process, so the VeilX admin console can freeze/kill/list any
// account with no downtime (the CLI needs the container stopped — sled is
// single-writer). Reachable at `/oprf/admin/*`.
#[derive(Deserialize)] struct AdminReq { account: String }
#[derive(Serialize)]   struct AdminAccount { account: String, state: String, count: u32, last_seen: u64 }

/// The bearer token must belong to a **server admin** — verified by calling an
/// admin-only homeserver endpoint with it (200 = admin, 403 = not). This reuses
/// tuwunel's own admin gate instead of keeping a second list of who's an operator.
async fn verify_admin(app: &App, headers: &axum::http::HeaderMap) -> bool {
    let Some(tok) = headers.get(axum::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok()).and_then(|s| s.strip_prefix("Bearer ")) else { return false };
    let url = format!("{}/_synapse/admin/v2/users?from=0&limit=1&guests=false",
                      app.homeserver.trim_end_matches('/'));
    match app.http.get(&url).bearer_auth(tok).send().await {
        Ok(resp) => resp.status().is_success(),
        Err(_) => false,
    }
}

/// account + state + eval count + last_seen — never any key material.
async fn admin_list(State(app): State<Arc<App>>, headers: axum::http::HeaderMap)
    -> Result<Json<Vec<AdminAccount>>, StatusCode> {
    if !verify_admin(&app, &headers).await { return Err(StatusCode::UNAUTHORIZED) }
    let mut out = Vec::new();
    for kv in app.db.iter() {
        let Ok((k, v)) = kv else { continue };
        let Ok(r) = serde_json::from_slice::<Record>(&v) else { continue };
        let state = if r.killed { "destroyed" } else if r.frozen { "frozen" } else { "ok" };
        out.push(AdminAccount {
            account: String::from_utf8_lossy(&k).to_string(),
            state: state.to_string(), count: r.count, last_seen: r.last_seen,
        });
    }
    Ok(Json(out))
}

/// Reversible hold on someone else's account (keeps k). CONFLICT if already destroyed.
async fn admin_freeze(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<AdminReq>) -> StatusCode {
    set_frozen(&app, &headers, &req.account, true).await
}
async fn admin_unfreeze(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<AdminReq>) -> StatusCode {
    set_frozen(&app, &headers, &req.account, false).await
}
async fn set_frozen(app: &Arc<App>, headers: &axum::http::HeaderMap, account: &str, freeze: bool) -> StatusCode {
    if !verify_admin(app, headers).await { return StatusCode::UNAUTHORIZED }
    match app.db.get(account.as_bytes()).ok().flatten()
        .and_then(|b| serde_json::from_slice::<Record>(&b).ok()) {
        Some(mut r) if !r.killed => {
            r.frozen = freeze;
            let _ = app.db.insert(account.as_bytes(), serde_json::to_vec(&r).unwrap());
            let _ = app.db.flush_async().await;
            StatusCode::NO_CONTENT
        }
        Some(_) => StatusCode::CONFLICT,   // already destroyed — nothing to (un)freeze
        None => StatusCode::NOT_FOUND,
    }
}

/// Destroy someone else's k — permanent, irreversible. Operator-only.
async fn admin_kill(State(app): State<Arc<App>>, headers: axum::http::HeaderMap, Json(req): Json<AdminReq>) -> StatusCode {
    if !verify_admin(&app, &headers).await { return StatusCode::UNAUTHORIZED }
    let r = Record { k: [0u8; 32], window_start: now(), count: 0, killed: true, frozen: false, last_seen: 0 };
    let _ = app.db.insert(req.account.as_bytes(), serde_json::to_vec(&r).unwrap());
    let _ = app.db.flush_async().await;
    StatusCode::NO_CONTENT
}

/// Load the Ed25519 signing key from `path`, generating+persisting it on first run.
/// Kept next to the sled db (0600, in the same LUKS-backed volume).
fn load_or_make_key(path: &str) -> SigningKey {
    if let Ok(bytes) = std::fs::read(path) {
        if let Ok(arr) = <[u8; 32]>::try_from(bytes.as_slice()) {
            return SigningKey::from_bytes(&arr);
        }
    }
    let key = SigningKey::generate(&mut OsRng);
    let _ = std::fs::write(path, key.to_bytes());
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600));
    }
    key
}

/// Local admin operations (run by the installer, never exposed over HTTP).
/// Deliberately has no way to print k: the key must never leave the database.
fn admin(db: &sled::Db, args: &[String]) {
    let load = |a: &str| -> Option<Record> {
        db.get(a.as_bytes()).ok().flatten().and_then(|b| serde_json::from_slice(&b).ok())
    };
    let save = |a: &str, r: &Record| {
        let _ = db.insert(a.as_bytes(), serde_json::to_vec(r).unwrap());
        let _ = db.flush();
    };
    match args[1].as_str() {
        // account<TAB>state<TAB>used/limit<TAB>last_seen — no key material.
        "--admin-list" => {
            for kv in db.iter() {
                let Ok((k, v)) = kv else { continue };
                let acct = String::from_utf8_lossy(&k).to_string();
                let Ok(r) = serde_json::from_slice::<Record>(&v) else { continue };
                let state = if r.killed { "destroyed" } else if r.frozen { "frozen" } else { "ok" };
                println!("{}\t{}\t{}\t{}", acct, state, r.count, r.last_seen);
            }
        }
        "--admin-freeze" | "--admin-unfreeze" => {
            let freeze = args[1] == "--admin-freeze";
            match load(&args[2]) {
                Some(mut r) if !r.killed => { r.frozen = freeze; save(&args[2], &r); eprintln!("ok"); }
                Some(_) => eprintln!("already destroyed"),
                None => eprintln!("no such account"),
            }
        }
        "--admin-kill" => {
            let r = Record { k: [0u8; 32], window_start: now(), count: 0, killed: true, frozen: false, last_seen: 0 };
            save(&args[2], &r);
            eprintln!("killed {}", args[2]);
        }
        // Org-wide destruction, for a company-level security incident.
        "--admin-kill-all" => {
            let mut n = 0;
            let accts: Vec<String> = db.iter().filter_map(|kv| kv.ok())
                .map(|(k, _)| String::from_utf8_lossy(&k).to_string()).collect();
            for a in accts {
                let r = Record { k: [0u8; 32], window_start: now(), count: 0, killed: true, frozen: false, last_seen: 0 };
                save(&a, &r); n += 1;
            }
            eprintln!("killed {n}");
        }
        // Idle reaper: act on accounts not seen for N days. Meant to run from cron,
        // so a device that has been out of contact far longer than any normal absence
        // is handled automatically, without an operator having to be online.
        //
        // ⚠️ **FREEZES by default, does not destroy.** An unattended cron job that
        // permanently destroys data is the wrong default: parental leave, a long
        // holiday, a hospital stay or a spare phone in a drawer all look exactly like
        // a lost device from here. Freezing is reversible (`--admin-unfreeze`), costs
        // the person one call to IT, and still blocks the device from unlocking —
        // which is the whole point. `--admin-reap-destroy` keeps the irreversible
        // behaviour for whoever deliberately wants it.
        //
        // The <7d floor exists for the same reason: a week is shorter than any normal
        // absence, and anything below that is almost certainly a misconfigured cron.
        "--admin-reap" | "--admin-reap-destroy" => {
            let destroy = args[1] == "--admin-reap-destroy";
            let days: u64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(0);
            if days == 0 {
                eprintln!("usage: --admin-reap <days>            (freeze, reversible)");
                eprintln!("       --admin-reap-destroy <days>    (destroy, PERMANENT)");
                return;
            }
            if days < 7 {
                eprintln!("refusing: <7 days is shorter than a normal absence \
                           (holiday / leave / spare device) — pick a longer window");
                return;
            }
            let cutoff = now().saturating_sub(days * 86400);
            let mut n = 0;
            let victims: Vec<(String, Record)> = db.iter().filter_map(|kv| kv.ok())
                .filter_map(|(k, v)| {
                    let r: Record = serde_json::from_slice(&v).ok()?;
                    // Only act on enrolled, still-alive accounts with a real last_seen.
                    // Already-frozen ones are skipped so a daily cron stays quiet.
                    if !r.killed && !r.frozen && r.last_seen != 0 && r.last_seen < cutoff {
                        Some((String::from_utf8_lossy(&k).to_string(), r))
                    } else { None }
                }).collect();
            for (a, mut r) in victims {
                if destroy {
                    r = Record { k: [0u8; 32], window_start: now(), count: 0,
                                 killed: true, frozen: false, last_seen: 0 };
                } else {
                    r.frozen = true;   // keep k — this must stay undoable
                }
                save(&a, &r); n += 1;
                eprintln!("{} {a}", if destroy { "destroyed" } else { "froze" });
            }
            eprintln!("{} {n} account(s) idle > {days}d",
                      if destroy { "destroyed" } else { "froze" });
        }
        _ => eprintln!("unknown admin command"),
    }
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    let env = |k: &str, d: &str| std::env::var(k).unwrap_or_else(|_| d.to_string());
    let db_path = env("DB", "./oprf.db");
    // Don't panic-loop if an admin one-off container is briefly holding the lock:
    // wait for it to release (up to ~30s) instead of crashing and restarting.
    // A crash-loop here locks out EVERY highest-tier phone, so recover gracefully.
    let db = {
        let mut opened = None;
        for _ in 0..60 {
            match sled::open(&db_path) {
                Ok(d) => { opened = Some(d); break; }
                Err(_) => std::thread::sleep(std::time::Duration::from_millis(500)),
            }
        }
        opened.expect("open db (lock still held after 30s)")
    };
    // Local admin operations, run by the installer (see `admin`).
    if args.len() >= 2 && args[1].starts_with("--admin-") {
        admin(&db, &args);
        return;
    }
    // 默认与数据库同目录：docker 下是 /data/signing.key，独立部署是 <DIR>/data/signing.key。
    // 两种部署因此都不必单独配这一项（仍可用 SIGNING_KEY 覆盖）。
    let default_signing = std::path::Path::new(&db_path)
        .parent()
        .map(|p| p.join("signing.key"))
        .unwrap_or_else(|| std::path::PathBuf::from("signing.key"));
    let signing_key = load_or_make_key(&env("SIGNING_KEY", &default_signing.to_string_lossy()));
    let app = Arc::new(App {
        db, http: reqwest::Client::new(),
        homeserver: env("HOMESERVER", "https://localhost"),
        rate_limit: env("RATE_LIMIT", "30").parse().unwrap_or(30),
        rate_window: env("RATE_WINDOW_SECS", "3600").parse().unwrap_or(3600),
        signing_key,
    });
    let bind = env("BIND", "127.0.0.1:8787");
    let router = Router::new()
        .route("/oprf/eval", post(eval))
        .route("/oprf/kill", post(kill))
        .route("/oprf/pubkey", get(pubkey))
        .route("/oprf/status", post(status))
        .route("/oprf/admin/list", get(admin_list))
        .route("/oprf/admin/freeze", post(admin_freeze))
        .route("/oprf/admin/unfreeze", post(admin_unfreeze))
        .route("/oprf/admin/kill", post(admin_kill))
        .with_state(app);
    let listener = tokio::net::TcpListener::bind(&bind).await.expect("bind");
    eprintln!("veilx-oprf-guard listening on {bind}");
    axum::serve(listener, router).await.unwrap();
}
EOF
}

# 在 .env 里写/改一个键(不重写整个文件,供子命令单独调用)
# 用 awk 而非 sed:值里可能含 | & \ 等 sed 替换串的元字符(域名列表、dest 的
# 冒号、随手输入的竖线),用 sed 会被解释甚至让脚本在 set -e 下直接中断。
px_env_set() {
  local k="$1" v="$2" f="$INSTALL_DIR/.env" tmp
  [ -f "$f" ] || return 1
  tmp="$f.tmp$$"
  KEY="$k" VAL="$v" awk '
    BEGIN { k=ENVIRON["KEY"]; v=ENVIRON["VAL"]; done=0 }
    index($0, k "=") == 1 { if (!done) { print k "=" v; done=1 } ; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
  chmod 600 "$f" 2>/dev/null || true
}

# 借用 xray 镜像本身生成密钥,不往宿主机装任何东西
px_xray_run() { docker run --rm "$XRAY_IMAGE" "$@" 2>/dev/null; }

# 由 clients.tsv 重新生成 xray/config.json
# ---- 可调参数(存 .env,均有安全默认值) ----
# PROXY_PORT   监听端口。443 时接管 Caddy 的 443(伪装最好);其它端口则不动 Caddy。
# PROXY_DEST   REALITY 借用的目标。留空=本机真实站点(caddy:443,推荐)
# PROXY_SNI    serverNames,逗号分隔。留空=本机域名 + matrix 子域
# PROXY_FLOW   xtls-rprx-vision(默认) 或 空
# PROXY_FP     uTLS 指纹:chrome(默认)/firefox/safari/edge/ios/android/random
px_port() { local v; v="$(env_saved PROXY_PORT)"; case "$v" in ''|*[!0-9]*) echo 443;; *) echo "$v";; esac; }
px_flow() { local v; v="$(env_saved PROXY_FLOW)"; [ -n "$v" ] && { [ "$v" = "none" ] && echo "" || echo "$v"; } || echo "xtls-rprx-vision"; }
px_fp()   { local v; v="$(env_saved PROXY_FP)";   [ -n "$v" ] && echo "$v" || echo "chrome"; }
px_dest() { local v; v="$(env_saved PROXY_DEST)"; [ -n "$v" ] && echo "$v" || echo "caddy:443"; }
# serverNames:自定义优先,否则本机域名 + matrix 子域
px_sni_list() {
  local v dom; v="$(env_saved PROXY_SNI)"; dom="$(env_saved MATRIX_DOMAIN)"
  [ -n "$v" ] && echo "$v" || echo "$dom,matrix.$dom"
}
# 客户端连接时用的 SNI(取 serverNames 第一个)
px_sni_primary() { px_sni_list | cut -d, -f1; }

px_write_config() {
  local d; d="$(px_dir)"
  local dom pbk_priv sids port flow dest
  dom="$(env_saved MATRIX_DOMAIN)"
  pbk_priv="$(cat "$d/private.key" 2>/dev/null)"
  sids="$(cat "$d/shortids.txt" 2>/dev/null | tr '\n' ' ')"
  [ -n "$dom" ] && [ -n "$pbk_priv" ] || return 1
  port="$(px_port)"; flow="$(px_flow)"; dest="$(px_dest)"

  # clients 数组。
  # 两个必须去重的点:
  #  · email 必须唯一 —— 重复会让 xray 直接拒绝启动
  #    ("failed to initiate user > proxy/vless: User X already exists")
  #    所以在备注后面缀上 UUID 前 8 位,既唯一又能看出是谁。
  #  · UUID 本身也去重,防止同一台设备被加了两次。
  local cl="" uuid label rest first=1 flowfield="" seen=""
  [ -n "$flow" ] && flowfield="\"flow\":\"$flow\","
  while IFS="$(printf '\t')" read -r uuid label rest; do
    [ -n "$uuid" ] || continue
    case "$uuid" in \#*) continue;; esac
    case " $seen " in *" $uuid "*) continue;; esac   # 同一 UUID 只保留一次
    seen="$seen $uuid"
    [ $first -eq 1 ] || cl="$cl,"
    cl="$cl{\"id\":\"$uuid\",$flowfield\"email\":\"$(json_esc "${label:-client}-${uuid%%-*}")\"}"
    first=0
  done < "$(px_clients)"

  # shortIds 数组
  local si="" s; first=1
  for s in $sids; do
    [ $first -eq 1 ] || si="$si,"
    si="$si\"$s\""; first=0
  done
  [ -n "$si" ] || si='""'

  # serverNames 数组
  local sn="" n; first=1
  for n in $(px_sni_list | tr ',' ' '); do
    [ -n "$n" ] || continue
    [ $first -eq 1 ] || sn="$sn,"
    sn="$sn\"$(json_esc "$n")\""; first=0
  done
  [ -n "$sn" ] || sn="\"$dom\""

  cat > "$d/config.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "veilx-reality",
      "listen": "0.0.0.0",
      "port": $port,
      "protocol": "vless",
      "settings": { "clients": [$cl], "decryption": "none" },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$(json_esc "$dest")",
          "xver": 0,
          "serverNames": [$sn],
          "privateKey": "$(json_esc "$pbk_priv")",
          "shortIds": [$si]
        }
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block",  "protocol": "blackhole" }
  ]
}
EOF
  # 官方 xray 镜像以非 root(uid 65532)运行,600 的 root 属主文件它读不了,
  # 容器会直接起不来。所以配置文件必须可被容器读取(644);私钥的保护靠
  # 外层目录 700(px_enable 里设置),宿主机上其它用户仍进不来。
  chmod 644 "$d/config.json" 2>/dev/null || true
}

# 生成 veilx:// 链接(标准 REALITY 参数,客户端内部还原成标准 vless://)
px_link() {
  local uuid="$1" label="${2:-VeilX}" d dom pbk sid host port flow fp sni extra
  d="$(px_dir)"; dom="$(env_saved MATRIX_DOMAIN)"
  pbk="$(cat "$d/public.key" 2>/dev/null)"
  sid="$(head -1 "$d/shortids.txt" 2>/dev/null)"
  host="$(env_saved PROXY_HOST)"; [ -n "$host" ] || host="$dom"
  port="$(px_port)"; flow="$(px_flow)"; fp="$(px_fp)"; sni="$(px_sni_primary)"
  extra=""; [ -n "$flow" ] && extra="&flow=$flow"
  printf 'veilx://proxy?proto=reality&server=%s&port=%s&id=%s&pbk=%s&sid=%s&sni=%s&fp=%s%s&type=tcp&name=%s&v=1' \
    "$host" "$port" "$uuid" "$pbk" "$sid" "$sni" "$fp" "$extra" "$(px_urlenc "$label")"
}

# 百分号编码。必须逐【字节】处理:printf "'$c" 对 >127 的字节在 bash 里
# 是有符号的,中文会被编成 %FFFFFFFFFFFFFFE6 这种垃圾。这里先用 od 拿到
# 十六进制字节,再按 ASCII 码值判断是否需要转义,与语言环境无关。
px_urlenc() {
  local s="$1" out="" h d
  for h in $(printf '%s' "$s" | od -An -tx1 -v | tr -s ' \n' ' '); do
    [ -n "$h" ] || continue
    d=$((16#$h))
    if { [ "$d" -ge 48 ] && [ "$d" -le 57 ]; } \
      || { [ "$d" -ge 65 ] && [ "$d" -le 90 ]; } \
      || { [ "$d" -ge 97 ] && [ "$d" -le 122 ]; } \
      || [ "$d" -eq 45 ] || [ "$d" -eq 46 ] || [ "$d" -eq 95 ] || [ "$d" -eq 126 ]; then
      out="$out$(printf "\\$(printf '%03o' "$d")")"
    else
      out="$out$(printf '%%%02X' "$d")"
    fi
  done
  printf '%s' "$out"
}

px_qr() {
  command -v qrencode >/dev/null 2>&1 || {
    echo "$(L "  (installing qrencode for the QR code…)" "  (正在安装 qrencode 以显示二维码…)")"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qrencode >/dev/null 2>&1 || true
  }
  command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 -m 1 "$1" 2>/dev/null || true
}

px_print_client() {
  local uuid="$1" label="$2" link
  link="$(px_link "$uuid" "$label")"
  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "== VeilX proxy link ==" "== VeilX 代理链接 ==")" "$C_RESET"
  printf '  %s: %s%s%s\n' "$(L Label 备注)" "$C_B" "$label" "$C_RESET"
  printf '\n%s\n\n' "$link"
  px_qr "$link"
  echo "$(L "  Scan it in VeilX (Settings → Proxy → Scan), or tap the link on the phone." "  在 VeilX 里扫码添加(设置 → 代理 → 扫码),或在手机上直接点这个链接。")"
}

# 读一行输入,答案打到 stdout(供 R="$(px_ask ...)" 捕获)。
# 注意:提示语必须走 stderr / dev/tty —— bash 的 `read -rp` 把提示写 stderr,
# 之前那种 `read -rp "..." R </dev/tty 2>/dev/null` 会把提示一起吞掉,
# 用户只看到光标卡住,完全不知道脚本在等什么。
px_ask() {
  local prompt="$1" ans=""
  if [ -t 0 ]; then
    # 交互终端:提示走 stderr(stdout 要留给返回值)
    printf '%s' "$prompt" >&2
    IFS= read -r ans || ans=""
  elif [ -e /dev/tty ] && (exec </dev/tty) 2>/dev/null; then
    # stdin 被重定向了(如 bash <(curl ...)),但仍有控制终端
    printf '%s' "$prompt" > /dev/tty 2>/dev/null || true
    IFS= read -r ans < /dev/tty || ans=""
  else
    # 完全非交互(管道/自动化):从 stdin 读一行,读不到就返回空走默认值
    printf '%s' "$prompt" >&2
    IFS= read -r ans || ans=""
  fi
  printf '%s' "$ans"
}

# 验证一个站点能不能当伪装目标。
# 这一步很重要:同样是知名大站,能不能用差别极大(实测 www.apple.com /
# dl.google.com / www.irs.gov 可用,而 www.microsoft.com 不可用),而且选错
# 之后客户端只会显示"超时",完全看不出原因。要求:TLS1.3 + H2 + 证书匹配。
# 粗筛,不是保证。REALITY 对 dest 的真实要求是:TLS1.3 + 用 X25519 密钥交换
# 且不触发 HelloRetryRequest + 支持 H2。这里用 openssl 尽量逼近(-groups X25519
# 是关键),但仍有站点能过粗筛却用不了 —— 实测 www.microsoft.com 就是 TLS1.3+H2
# 齐全却依然握手不成。所以默认走下面那份【实测验证过】的清单,自定义输入只挡
# 明显不合格的(比如只会 301 跳转的 irs.gov)。
px_check_dest() {
  local host="${1%%:*}" out="" TO=""
  # timeout(1) 是 GNU coreutils 的,Ubuntu 有、别的系统未必 —— 没有就不加,
  # 否则整条命令会因 "command not found" 而被误判成"站点不可用"。
  command -v timeout >/dev/null 2>&1 && TO="timeout 12"
  if command -v openssl >/dev/null 2>&1; then
    out="$(echo | $TO openssl s_client -connect "$host:443" -servername "$host" \
            -tls1_3 -groups X25519 -alpn h2 2>&1)"
    # openssl 版本太老不认这些参数时,别误判成"不可用"
    if echo "$out" | grep -qiE "unknown option|unrecognized|Usage"; then out=""; fi
    if [ -n "$out" ]; then
      echo "$out" | grep -q "TLSv1.3" || return 1
      echo "$out" | grep -qi "ALPN protocol: h2" || return 1
      return 0
    fi
  fi
  # 退路:至少确认它是个 HTTP/2 的正常站点,而不是跳转页
  command -v curl >/dev/null 2>&1 || return 0
  local v; v="$(curl -sI --max-time 12 -o /dev/null -w '%{http_version} %{http_code}' "https://$host/" 2>/dev/null)"
  case "$v" in 2\ 200|2\ 30*) return 0 ;; *) return 1 ;; esac
}

# 放行代理端口。80/443 一般默认开着,但 8443 这种非标端口几乎总是被挡:
# 既可能是机器上的 ufw/firewalld,也可能是云厂商控制台里的安全组 —— 后者
# 我们改不了,只能明确告诉用户去开,否则手机永远连不上而且毫无提示。
px_open_firewall() {
  local port="$1" opened=""
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "^Status: active"; then
    ufw allow "$port"/tcp >/dev/null 2>&1 && opened="ufw"
  elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="$port"/tcp >/dev/null 2>&1 \
      && firewall-cmd --reload >/dev/null 2>&1 && opened="firewalld"
  fi
  [ -n "$opened" ] && ok "$(L "Opened port $port in the local firewall ($opened)." "已在本机防火墙放行 $port 端口($opened)。")"

  # 本机放行了不代表外网能进 —— 云厂商的安全组在机器之外。
  if [ "$port" != "443" ] && [ "$port" != "80" ]; then
    echo
    warn "$(L "IMPORTANT: port $port must also be allowed in your VPS provider's firewall / security group." "重要:$port 端口还必须在你的 VPS 服务商控制台(防火墙/安全组)里放行。")"
    echo "$(L "  Ports 80 and 443 are usually open by default; $port almost never is." "  80 和 443 通常默认开放,$port 基本上一定是关的。")"
    echo "$(L "  Without that, your phone will simply time out with no useful error." "  不放行的话,手机只会一直超时,而且看不出原因。")"
  fi
}

# 运行状态自检。用大白话说结论,不堆术语 —— 用户要的是
# 「现在到底能不能用」,而不是一堆容器名和端口号。
px_status() {
  cd "$INSTALL_DIR" 2>/dev/null || return 1
  local dom port running
  dom="$(env_saved MATRIX_DOMAIN)"; port="$(px_port)"
  printf '\n%s%s%s\n\n' "$C_B$C_CYAN" "$(L "== Status ==" "== 运行状态 ==")" "$C_RESET"

  # 1) 代理本身
  if docker compose ps --status running -q xray 2>/dev/null | grep -q .; then
    ok "$(L "Proxy is running (port $port)" "代理正在运行(端口 $port)")"
    running=1
  else
    warn "$(L "Proxy is NOT running" "代理没有在运行")"
    echo "   $(L "See why:" "查看原因:") docker compose logs --tail 30 xray"
    running=0
  fi

  # 2) 你的 Matrix 网站 —— 用户最关心的其实是这个
  local code
  code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 "https://$dom/" 2>/dev/null)"
  case "$code" in
    000|"") warn "$(L "Your Matrix site did NOT respond!" "你的 Matrix 网站没有响应!")"
            if [ "$port" = "443" ]; then
              echo "   $(L "The proxy shares port 443 with your site. Roll back with:" "代理和网站共用 443 端口。回滚:")"
              echo "   sudo tuwunel proxy disable"
            fi ;;
    *)      ok "$(L "Your Matrix site is up (HTTP $code)" "你的 Matrix 网站正常(HTTP $code)")" ;;
  esac

  # 3) 端口是否真的从外网进得来 —— 容器在跑 ≠ 手机连得上。
  #    绝大多数"连不上"其实卡在云厂商安全组,而不是软件本身。
  if [ "$running" = "1" ]; then
    local ip reach
    ip="$(env_saved PUBLIC_IP)"
    [ -n "$ip" ] || ip="$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null)"
    if [ -n "$ip" ] && command -v curl >/dev/null 2>&1; then
      # 从本机绕到公网 IP 打自己的端口:能通说明外部也能通。
      if timeout 10 bash -c "</dev/tcp/$ip/$port" 2>/dev/null; then
        ok "$(L "Port $port is reachable from outside." "$port 端口从外部可以连通。")"
      else
        warn "$(L "Port $port is NOT reachable from outside — this is why phones can't connect." "$port 端口从外部【连不通】—— 手机连不上就是因为这个。")"
        echo "   $(L "Open it in your VPS provider's firewall / security group." "请到 VPS 服务商控制台的防火墙/安全组里放行它。")"
        echo "   $(L "Or switch to port 443 (menu → 9 → Advanced), which is usually already open." "或者改用 443 端口(菜单 → 9 高级设置),那个通常已经开着。")"
      fi
    fi
  fi

  # 4) 设备数
  local n=0
  [ -f "$(px_clients)" ] && n="$(grep -c . "$(px_clients)" 2>/dev/null || echo 0)"
  echo "   $(L "Devices added:" "已添加设备:") $n"
  [ "$n" = "0" ] && echo "   $(L "Add one from the menu to get a QR code for your phone." "在菜单里添加一台,就能拿到手机扫的二维码。")"
  echo
}

# ---------------------------------------------------------------------
# 一键向导:面向不懂网络的用户。
# 只问一个真正需要人决定的问题(用哪个端口),其余全部自动:
# 密钥、UUID、shortId、借用目标(本机真站)、SNI、flow、uTLS 都用最优默认值。
# ---------------------------------------------------------------------
px_wizard() {
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — deploy the Matrix server first" "找不到 $INSTALL_DIR —— 请先部署 Matrix 服务器")"
  cd "$INSTALL_DIR"
  local dom; dom="$(env_saved MATRIX_DOMAIN)"
  [ -n "$dom" ] || die "$(L "Can't read your domain from .env" "读不到 .env 里的域名")"

  cat <<EOF

┌────────────────────────────────────────────────────────┐
│  $(L "Set up the VeilX proxy — guided" "VeilX 专用代理 · 一键向导")
└────────────────────────────────────────────────────────┘

$(L "This lets your phone reach this server even where it is blocked." "这能让你的手机在被封锁的网络里也能连上这台服务器。")
$(L "It disguises itself as your own website — a probe sees the real site." "它会伪装成你自己的网站 —— 别人探测时看到的就是你真实的站点。")

$(L "Everything is automatic (keys, IDs, camouflage target)." "密钥、账号、伪装目标等全部自动生成,你不用懂。")
$(L "You only need to answer ONE question:" "你只需要回答一个问题:")

EOF

  cat <<EOF
$(L "Which port should the proxy use?" "代理用哪个端口?")

  1) $(L "8443  — SAFE. Your Matrix site is NOT touched at all." "8443  —— 【安全】完全不动你的 Matrix 网站。")
     $(L "         Recommended for the first try." "         第一次用推荐选这个。")

  2) $(L "443   — BEST disguise, but your site briefly restarts and" "443   —— 【伪装最好】但你的网站会短暂重启,")
     $(L "         shares the port with the proxy." "         而且要和代理共用端口。")
     $(L "         Only pick this once 8443 already works." "         建议先用 8443 跑通了再换成这个。")

EOF
  local R; R="$(px_ask "$(L "Select [1-2, default 1]: " "请选择 [1-2,直接回车=1]: ")")"
  case "$R" in
    2) px_env_set PROXY_PORT 443
       echo; warn "$(L "Your website will restart briefly. If anything goes wrong, run: sudo tuwunel proxy disable" "你的网站会短暂重启。万一出问题,执行: sudo tuwunel proxy disable")" ;;
    *) px_env_set PROXY_PORT 8443
       echo; ok "$(L "Using 8443 — your Matrix site will not be affected." "使用 8443 —— 你的 Matrix 网站不受任何影响。")" ;;
  esac

  # ---- 伪装成哪个网站 ----
  cat <<EOF

$(L "The proxy disguises itself as some real HTTPS website." "代理会把自己伪装成某个真实的 HTTPS 网站。")
$(L "Anyone probing your server just sees that website." "别人探测你的服务器时,看到的就是那个网站。")

  1) $(L "A well-known public site (no domain of your own needed)" "借用一个知名网站(不需要你自己的域名)")
     $(L "         Keeps the proxy unrelated to your Matrix server." "         好处:代理和你的 Matrix 服务器互不相关。")

  2) $(L "This server's own Matrix site" "用这台服务器自己的 Matrix 网站")
     $(L "         Strongest consistency, but ties the proxy to your domain." "         一致性最强,但会把代理和你的域名绑在一起。")

EOF
  local C; C="$(px_ask "$(L "Select [1-2, default 1]: " "请选择 [1-2,直接回车=1]: ")")"
  if [ "$C" = "2" ]; then
    px_env_set PROXY_DEST "caddy:443"
    px_env_set PROXY_SNI  ""
    px_env_set PROXY_HOST ""
    ok "$(L "Disguising as your own Matrix site." "将伪装成你自己的 Matrix 站点。")"
  else
    # 逐个验证,选第一个真正可用的 —— 不能用的站会让客户端只报超时。
    local site="" cand
    echo "$(L "  Checking which sites work as a disguise…" "  正在检测哪些站点可用作伪装…")"
    for cand in www.apple.com dl.google.com www.irs.gov addons.mozilla.org www.cloudflare.com; do
      if px_check_dest "$cand"; then site="$cand"; echo "    ✓ $cand"; break; else echo "    ✗ $cand"; fi
    done
    if [ -z "$site" ]; then
      warn "$(L "No candidate worked — falling back to this server's own site." "没有可用的候选 —— 退回使用本机站点。")"
      px_env_set PROXY_DEST "caddy:443"; px_env_set PROXY_SNI ""; px_env_set PROXY_HOST ""
    else
      px_env_set PROXY_DEST "$site:443"
      px_env_set PROXY_SNI  "$site"
      # 不用域名了 —— 客户端直接连 IP。
      local myip; myip="$(env_saved PUBLIC_IP)"
      [ -n "$myip" ] || myip="$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null)"
      [ -n "$myip" ] && px_env_set PROXY_HOST "$myip"
      ok "$(L "Disguising as $site — your domain is not involved." "将伪装成 $site —— 不涉及你的域名。")"
    fi
  fi

  px_env_set PROXY_FLOW "xtls-rprx-vision"
  px_env_set PROXY_FP   "chrome"

  echo
  echo "$(L "Setting up… (first run downloads the proxy image, a minute or two)" "正在部署…(首次会下载代理镜像,需要一两分钟)")"
  px_enable
}

# 交互式设置:端口 / 目标网站 / SNI / flow / uTLS 指纹(专家用)
px_config() {
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found" "找不到 $INSTALL_DIR")"
  cd "$INSTALL_DIR"
  local dom; dom="$(env_saved MATRIX_DOMAIN)"
  local R

  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "== VeilX proxy settings ==" "== VeilX 专用代理设置 ==")" "$C_RESET"
  printf '  %s: %s\n' "$(L "Port" 端口)"       "$(px_port)"
  printf '  %s: %s\n' "$(L "Borrowed site" 借用目标)" "$(px_dest)"
  printf '  %s: %s\n' "$(L "SNI" SNI)"          "$(px_sni_list)"
  printf '  %s: %s\n' "$(L "flow" flow)"        "$(px_flow | sed 's/^$/(none)/')"
  printf '  %s: %s\n' "$(L "uTLS" uTLS)"        "$(px_fp)"
  echo

  # ---- 端口 ----
  echo "$(L "Listening port. 443 gives the best camouflage (Xray takes 443, Caddy keeps 80 and stays internal)." "监听端口。443 伪装最好(Xray 接管 443,Caddy 保留 80 并转内网)。")"
  echo "$(L "Any other port leaves Caddy's 443 untouched — less invasive, but a non-443 proxy port is more conspicuous." "填其它端口则完全不动 Caddy 的 443 —— 侵入性最小,但非 443 的代理端口更显眼。")"
  R="$(px_ask "$(L "Port [$(px_port)]: " "端口 [$(px_port)]: ")")"
  if [ -n "$R" ]; then
    case "$R" in ''|*[!0-9]*) warn "$(L "Not a number, keeping current." "不是数字,保持原值。")";;
      *) [ "$R" -ge 1 ] && [ "$R" -le 65535 ] && px_env_set PROXY_PORT "$R" || warn "$(L "Out of range." "超出范围。")";; esac
  fi

  # ---- 借用目标 ----
  echo
  echo "$(L "Which real site should the proxy disguise itself as? Probes that aren't VeilX clients get forwarded there." "代理伪装成哪个真实网站?非 VeilX 客户端的探测会被转发过去。")"
  echo "  1) $(L "This server's own Matrix/Element site (recommended — the IP really does host it)" "本机真实的 Matrix/Element 站点(推荐 —— 这个 IP 确实托管它)")"
  echo "  2) $(L "An external site (e.g. www.microsoft.com:443)" "外部站点(如 www.microsoft.com:443)")"
  R="$(px_ask "$(L "Select [1-2, blank=keep]: " "请选择 [1-2,留空=不改]: ")")"
  case "$R" in
    1) px_env_set PROXY_DEST "caddy:443"; px_env_set PROXY_SNI ""
       ok "$(L "Using the local site." "已设为本机站点。")" ;;
    2) local DHOST=""
       DHOST="$(px_ask "$(L "  Target host:port (e.g. www.microsoft.com:443): " "  目标 主机:端口(如 www.microsoft.com:443): ")")"
       if [ -n "$DHOST" ]; then
         case "$DHOST" in *:*) :;; *) DHOST="$DHOST:443";; esac
         echo "$(L "  Checking $DHOST …" "  正在检测 $DHOST …")"
         if px_check_dest "$DHOST"; then
           px_env_set PROXY_DEST "$DHOST"
           px_env_set PROXY_SNI "${DHOST%%:*}"
           ok "$(L "Borrowing $DHOST" "已改为借用 $DHOST")"
         else
           warn "$(L "$DHOST can't be used as a disguise (needs TLS 1.3 + HTTP/2). Keeping the current setting." "$DHOST 不能用作伪装目标(需要 TLS 1.3 + HTTP/2)。保持原设置。")"
           echo "$(L "  Known-good: www.apple.com, dl.google.com, www.irs.gov, addons.mozilla.org" "  已验证可用: www.apple.com、dl.google.com、www.irs.gov、addons.mozilla.org")"
         fi
       fi ;;
  esac

  # ---- 自定义 SNI ----
  echo
  R="$(px_ask "$(L "serverNames (comma-separated, blank=keep) [$(px_sni_list)]: " "serverNames(逗号分隔,留空=不改)[$(px_sni_list)]: ")")"
  [ -n "$R" ] && px_env_set PROXY_SNI "$R"

  # ---- flow ----
  echo
  echo "$(L "flow: xtls-rprx-vision is the standard and recommended; 'none' disables it." "flow:xtls-rprx-vision 是标准且推荐;填 none 表示不用。")"
  R="$(px_ask "$(L "flow [$(px_flow | sed 's/^$/none/')]: " "flow [$(px_flow | sed 's/^$/none/')]: ")")"
  case "$R" in
    "") : ;;
    none|NONE) px_env_set PROXY_FLOW "none" ;;
    xtls-rprx-vision) px_env_set PROXY_FLOW "xtls-rprx-vision" ;;
    *) warn "$(L "Unknown flow, keeping current." "未知 flow,保持原值。")" ;;
  esac

  # ---- uTLS ----
  echo
  echo "$(L "uTLS fingerprint. Keep 'chrome' unless you know why: a rare fingerprint is a SMALLER crowd to hide in, not a safer one." "uTLS 指纹。没有特别理由就用 chrome —— 冷门指纹意味着可藏身的人群更小,不是更安全。")"
  R="$(px_ask "$(L "uTLS (chrome/firefox/safari/edge/ios/android/random) [$(px_fp)]: " "uTLS(chrome/firefox/safari/edge/ios/android/random)[$(px_fp)]: ")")"
  case "$R" in
    "") : ;;
    chrome|firefox|safari|edge|ios|android|random|randomized) px_env_set PROXY_FP "$R" ;;
    *) warn "$(L "Unknown fingerprint, keeping current." "未知指纹,保持原值。")" ;;
  esac

  echo
  if px_enabled; then
    echo "$(L "Applying…" "正在应用…")"
    px_write_config || die "$(L "Failed to write xray config" "写入 xray 配置失败")"
    px_apply_compose || die "$(L "compose update refused — settings saved but NOT applied; nothing was changed on disk." "compose 更新被拒绝 —— 设置已保存但【未应用】,磁盘上的编排文件没有改动。")"
    docker compose up -d --remove-orphans >/dev/null 2>&1 || true
    docker compose restart xray >/dev/null 2>&1 || true
    sleep 3
    # 必须确认 xray 真起来了:端口是 443 时 Caddy 已经让出 443,
    # 若 xray 崩溃循环则整站 HTTPS 都没人应答。
    if docker compose ps --status running -q xray 2>/dev/null | grep -q .; then
      ok "$(L "Applied. Re-issue client links so they carry the new settings: sudo tuwunel proxy list" "已应用。请重新分发客户端链接以带上新设置:sudo tuwunel proxy list")"
    else
      warn "$(L "xray did NOT come up with the new settings." "xray 用新设置【没能启动】。")"
      echo "  docker compose logs --tail 30 xray"
      if [ "$(px_port)" = "443" ]; then
        warn "$(L "Caddy has already released :443 — your site is DOWN until this is fixed. Roll back now with: sudo tuwunel proxy disable" "Caddy 已经让出 :443 —— 在修好之前你的站点是【下线】状态。立即回滚:sudo tuwunel proxy disable")"
      fi
    fi
  else
    ok "$(L "Saved. They take effect when you run: sudo tuwunel proxy enable" "已保存。执行 sudo tuwunel proxy enable 时生效。")"
  fi
}

px_add_client() {
  local label="${1:-}"
  [ -f "$(px_clients)" ] || die "$(L "Proxy not enabled yet — run: sudo tuwunel proxy enable" "尚未开启代理 —— 请先执行: sudo tuwunel proxy enable")"
  if [ -z "$label" ]; then
    local p; p="$(L "Label for this device (e.g. my-phone): " "这台设备的备注(如 my-phone): ")"
    if [ -t 0 ]; then read -rp "$p" label || true
    elif [ -e /dev/tty ]; then read -rp "$p" label < /dev/tty || true; fi
  fi
  label="$(printf '%s' "${label:-device}" | tr -d '\t\n')"
  # 备注重名会让列表分不清谁是谁(email 唯一性由 px_write_config 保证),
  # 这里自动加序号,体验上更清楚。
  if [ -f "$(px_clients)" ] && cut -f2 "$(px_clients)" 2>/dev/null | grep -qxF "$label"; then
    local _i=2
    while cut -f2 "$(px_clients)" 2>/dev/null | grep -qxF "$label-$_i"; do _i=$((_i+1)); done
    label="$label-$_i"
  fi
  # 允许指定 UUID(第二个参数或交互输入);留空则自动生成
  local uuid="${2:-}"
  if [ -z "$uuid" ] && [ -t 0 ]; then
    uuid="$(px_ask "$(L "UUID (blank = generate): " "UUID(留空=自动生成): ")")"
  fi
  uuid="$(printf '%s' "$uuid" | tr -d '[:space:]')"
  if [ -n "$uuid" ]; then
    echo "$uuid" | grep -Eqi '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' \
      || die "$(L "Not a valid UUID" "UUID 格式不合法")"
    grep -q "^$uuid	" "$(px_clients)" 2>/dev/null && die "$(L "That UUID is already in use" "该 UUID 已存在")"
  else
    uuid="$(px_xray_run uuid)"
    [ -n "$uuid" ] || uuid="$(cat /proc/sys/kernel/random/uuid 2>/dev/null)"
  fi
  [ -n "$uuid" ] || die "$(L "Failed to generate a UUID" "生成 UUID 失败")"
  printf '%s\t%s\t%s\n' "$uuid" "$label" "$(date +%F)" >> "$(px_clients)"
  px_write_config || die "$(L "Failed to write xray config" "写入 xray 配置失败")"
  ( cd "$INSTALL_DIR" && docker compose up -d xray >/dev/null 2>&1 && docker compose restart xray >/dev/null 2>&1 ) || true
  ok "$(L "Client added." "客户端已添加。")"
  px_print_client "$uuid" "$label"
}

px_list() {
  local f; f="$(px_clients)"
  [ -f "$f" ] || die "$(L "Proxy not enabled yet." "尚未开启代理。")"
  printf '\n%s\n' "$(L "== VeilX proxy clients ==" "== VeilX 代理客户端 ==")"
  local uuid label date_ n=0
  while IFS="$(printf '\t')" read -r uuid label date_; do
    [ -n "$uuid" ] || continue
    n=$((n+1))
    printf '  %s) %-20s %s  %s\n' "$n" "${label:-device}" "${date_:-}" "${uuid%%-*}…"
  done < "$f"
  [ "$n" -gt 0 ] || echo "$(L "  (none yet — sudo tuwunel proxy add)" "  (还没有 —— sudo tuwunel proxy add)")"
  echo
}

px_enable() {
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — deploy the server first" "找不到 $INSTALL_DIR —— 请先部署服务器")"
  cd "$INSTALL_DIR"
  local dom; dom="$(env_saved MATRIX_DOMAIN)"
  [ -n "$dom" ] || die "$(L "Can't read the domain from .env" "读不到 .env 里的域名")"
  local d; d="$(px_dir)"; mkdir -p "$d"; chmod 700 "$d"

  # 已开启:不当作 no-op —— compose 可能在一次 reconfigure 后丢了 xray 段,
  # 这时用户正是靠再跑一次 enable 来修复的。重新注入并起服务。
  if px_enabled && [ -f "$d/config.json" ]; then
    echo "$(L "Proxy already enabled — re-applying config and compose…" "代理已开启 —— 重新应用配置与编排…")"
    px_write_config || warn "$(L "Failed to write xray config" "写入 xray 配置失败")"
    if px_apply_compose; then
      docker compose up -d --remove-orphans >/dev/null 2>&1 || true
      sleep 2
      docker compose ps --status running -q xray 2>/dev/null | grep -q . \
        && ok "$(L "Proxy is running." "代理运行中。")" \
        || warn "$(L "xray is not running: docker compose logs --tail 30 xray" "xray 未在运行: docker compose logs --tail 30 xray")"
    else
      warn "$(L "compose update refused — see the message above." "compose 更新被拒绝 —— 见上方提示。")"
    fi
    px_list; return 0
  fi

  bold "$(L "Setting up the VeilX dedicated proxy" "开启 VeilX 专用代理")"
  if [ "$(px_port)" = "443" ]; then
    echo "$(L "  Xray will take over :443; Caddy keeps :80 (for cert renewal) and stays reachable internally." "  Xray 将接管 :443;Caddy 保留 :80(续证用)并继续在内网提供服务。")"
  else
    echo "$(L "  Xray will listen on :$(px_port); Caddy keeps :80 and :443 untouched." "  Xray 将监听 :$(px_port);Caddy 的 :80 和 :443 完全不动。")"
  fi
  echo "$(L "  Probes that aren't VeilX clients get your REAL Matrix site — that's the camouflage." "  非 VeilX 客户端的探测会看到你【真实的】Matrix 站点 —— 这就是伪装。")"

  docker image inspect "$XRAY_IMAGE" >/dev/null 2>&1 || {
    echo "$(L "  Pulling Xray image…" "  正在拉取 Xray 镜像…")"
    docker pull -q "$XRAY_IMAGE" >/dev/null 2>&1 || die "$(L "Failed to pull $XRAY_IMAGE" "拉取 $XRAY_IMAGE 失败")"
  }

  # 密钥对 + shortIds(仅在首次生成)
  if [ ! -f "$d/private.key" ]; then
    local kp priv pub
    kp="$(px_xray_run x25519)"
    priv="$(printf '%s\n' "$kp" | grep -iE 'private' | sed 's/.*: *//' | tr -d '\r')"
    pub="$(printf '%s\n' "$kp"  | grep -iE 'public'  | sed 's/.*: *//' | tr -d '\r')"
    [ -n "$priv" ] && [ -n "$pub" ] || die "$(L "Failed to generate proxy keys" "生成代理密钥失败")"
    printf '%s\n' "$priv" > "$d/private.key"
    printf '%s\n' "$pub"  > "$d/public.key"
    chmod 600 "$d/private.key" "$d/public.key"
  fi
  [ -f "$d/shortids.txt" ] || { openssl rand -hex 4 > "$d/shortids.txt"; chmod 600 "$d/shortids.txt"; }
  [ -f "$(px_clients)" ] || { : > "$(px_clients)"; chmod 600 "$(px_clients)"; }

  px_env_set ENABLE_PROXY 1
  px_write_config || die "$(L "Failed to write xray config" "写入 xray 配置失败")"
  px_apply_compose || die "$(L "Failed to update docker-compose.yml" "更新 docker-compose.yml 失败")"

  echo "$(L "  Restarting services…" "  正在重启服务…")"
  docker compose up -d --remove-orphans >/dev/null 2>&1 || warn "$(L "compose up reported an error — check: docker compose ps" "compose up 报错 —— 请查: docker compose ps")"
  sleep 3
  if ! docker compose ps --status running -q xray 2>/dev/null | grep -q .; then
    # 起不来时直接把日志摆出来 —— 不懂网络的人不该被要求自己去敲 docker 命令。
    # 也【不】发二维码:给一个连不上的节点只会让人白折腾半天。
    echo
    warn "$(L "The proxy did NOT start. Nothing was handed out — your Matrix site is untouched." "代理没能启动。没有生成任何节点 —— 你的 Matrix 网站不受影响。")"
    echo
    echo "$(L "── Log (last 20 lines) ──" "── 日志(最后 20 行)──")"
    docker compose logs --tail 20 --no-log-prefix xray 2>&1 | sed 's/^/  /' || true
    echo
    echo "$(L "Send the lines above for help. To undo:  sudo tuwunel proxy disable" "把上面的内容发给我排查。撤销:  sudo tuwunel proxy disable")"
    return 1
  fi

  ok "$(L "VeilX proxy is running on :$(px_port)." "VeilX 代理已在 :$(px_port) 运行。")"
  px_open_firewall "$(px_port)"
  # 端口非 443 时,curl https://域名 打的是 Caddy 而不是代理 —— 那样"验证通过"
  # 是假象,所以要显式带上代理端口。
  if [ "$(px_port)" = "443" ]; then
    echo "$(L "  Verify camouflage from outside:  curl -I https://$dom" "  从外部验证伪装:  curl -I https://$dom")"
  else
    echo "$(L "  Verify camouflage from outside:  curl -I --resolve $dom:$(px_port):<server-ip> https://$dom:$(px_port)" "  从外部验证伪装:  curl -I --resolve $dom:$(px_port):<服务器IP> https://$dom:$(px_port)")"
  fi
  echo "$(L "  Roll back any time:              sudo tuwunel proxy disable" "  随时回滚:                        sudo tuwunel proxy disable")"
  # 直接把第一台设备的链接+二维码打出来:用户装完就能扫,
  # 不用再回菜单找「添加设备」。第二个参数留空=自动生成 UUID。
  # 只有在一个客户端都没有时才自动创建 —— 否则重跑向导会不断堆叠设备。
  if [ -s "$(px_clients)" ]; then
    echo
    ok "$(L "Existing devices kept — nothing new was created." "已保留原有设备 —— 没有新建。")"
    px_list
  else
    px_add_client "$(L "my phone" "我的手机")" ""
  fi
  cat <<EOF

$(L "── What to do next ──" "── 接下来怎么做 ──")
$(L "1. Open VeilX on your phone" "1. 手机上打开 VeilX")
$(L "2. Menu → 网络代理 → 扫码添加 VeilX 代理" "2. 侧边菜单 → 网络代理 → 扫码添加 VeilX 代理")
$(L "3. Scan the QR code above, then turn on the 代理 switch" "3. 扫上面的二维码,然后打开「代理」开关")

$(L "Add more devices:  sudo tuwunel proxy add" "再加设备:  sudo tuwunel proxy add")
$(L "Check status:      sudo tuwunel proxy" "查看状态:  sudo tuwunel proxy")
EOF
}

px_disable() {
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found" "找不到 $INSTALL_DIR")"
  cd "$INSTALL_DIR"
  local pport; pport="$(px_port)"
  # 先停容器,再改 compose —— 反过来的话服务已从 compose 里消失,
  # stop/rm 就找不到它了,容器会残留并继续占着端口。
  docker compose stop xray >/dev/null 2>&1 || true
  docker compose rm -f xray >/dev/null 2>&1 || true
  px_env_set ENABLE_PROXY 0
  px_apply_compose || warn "$(L "Failed to restore docker-compose.yml — check the .bak-preproxy backup" "还原 docker-compose.yml 失败 —— 请查 .bak-preproxy 备份")"
  docker compose up -d --remove-orphans >/dev/null 2>&1 || true
  sleep 3
  if [ "$pport" = "443" ]; then
    ok "$(L ":443 has been handed back to Caddy. Client credentials are kept (re-enable any time)." ":443 已还给 Caddy。客户端凭据保留(随时可再开启)。")"
  else
    ok "$(L "Proxy stopped (:$pport released). Client credentials are kept." "代理已停止(:$pport 已释放)。客户端凭据保留。")"
  fi
  echo "$(L "  Verify the site is up:  curl -I https://$(env_saved MATRIX_DOMAIN)" "  确认站点正常:  curl -I https://$(env_saved MATRIX_DOMAIN)")"
}

# 按 ENABLE_PROXY 改写 docker-compose.yml:caddy 端口 + xray 服务
# 改动前自动留一份 .bak-preproxy(只留第一次的,即"未开代理时"的原样)
# 全程在副本上改,校验通过才落盘 —— 关键:开代理时会先把 443 从 Caddy 拿走,
# 若此时注入 xray 失败却仍写回,宿主机 443 就没人监听 = 整站直接下线。
px_apply_compose() {
  local f="$INSTALL_DIR/docker-compose.yml"
  [ -f "$f" ] || return 1
  [ -f "$f.bak-preproxy" ] || cp -a "$f" "$f.bak-preproxy"

  # 不用 `trap ... RETURN`:RETURN 触发时函数的 local 变量已经不在作用域里,
  # 在 set -u 下会炸成 "work: unbound variable"。改成每个出口显式清理。
  local work="$f.veilxwork$$" tmp="$f.veilxtmp$$"
  px_cleanup_tmp() { rm -f "$work" "$tmp" 2>/dev/null || true; }
  cp -a "$f" "$work" || { px_cleanup_tmp; return 1; }

  # 先移除脚本上次注入的 xray 段(幂等)
  sed -i '/# >>> veilx-proxy >>>/,/# <<< veilx-proxy <<</d' "$work" || { px_cleanup_tmp; return 1; }

  if px_enabled; then
    local pport; pport="$(px_port)"
    if [ "$pport" = "443" ]; then
      # Caddy 让出宿主机 443(容器内仍监听 443,Xray 通过内网 caddy:443 转发)
      sed -i 's|^\( *\)ports: \["80:80", "443:443", "443:443/udp"\]|\1ports: ["80:80"]   # veilx-proxy: 443 交给 xray|' "$work" || { px_cleanup_tmp; return 1; }
    else
      # 非 443:完全不动 Caddy,若之前被改过则还原
      sed -i 's|^\( *\)ports: \["80:80"\] *# veilx-proxy.*|\1ports: ["80:80", "443:443", "443:443/udp"]|' "$work" || { px_cleanup_tmp; return 1; }
    fi
    # 在 networks: 段之前插入 xray 服务
    awk -v pport="$pport" -v img="$XRAY_IMAGE" '
      /^networks:/ && !done {
        print "# >>> veilx-proxy >>>"
        print "  xray:"
        print "    image: " img
        print "    restart: unless-stopped"
        # 不用 *log 锚点:万一目标 compose 没定义它,YAML 解析会整体失败,
        # 连带把 Matrix 的所有容器一起弄down。这里写死等价配置,自包含。
        print "    logging:"
        print "      driver: json-file"
        print "      options: { max-size: \"10m\", max-file: \"3\" }"
        print "    security_opt: [\"no-new-privileges:true\"]"
        print "    depends_on: [caddy]"
        print "    ports: [\"" pport ":" pport "/tcp\"]"
        print "    volumes:"
        print "      - ./xray/config.json:/etc/xray/config.json:ro"
        print "    command: [\"run\", \"-c\", \"/etc/xray/config.json\"]"
        print "    mem_limit: 96m"
        print "    networks: [internal]"
        print ""
        print "# <<< veilx-proxy <<<"
        done=1
      }
      { print }
    ' "$work" > "$tmp" && mv "$tmp" "$work" || { px_cleanup_tmp; return 1; }

    # 校验:xray 段确实注入了,且必须有人监听宿主机 443(Caddy 或 xray),
    # 否则拒绝写回 —— 宁可不开代理,也不能把整站打没。
    grep -q '# >>> veilx-proxy >>>' "$work" || {
      warn "$(L "xray block was not injected — refusing to write docker-compose.yml" "xray 段未能注入 —— 拒绝写回 docker-compose.yml")"; px_cleanup_tmp; return 1; }
    if ! grep -qE '"443:443"|"443:443/tcp"' "$work"; then
      warn "$(L "Nothing would listen on host :443 — refusing to write docker-compose.yml" "没有任何服务会监听宿主机 :443 —— 拒绝写回 docker-compose.yml")"
      px_cleanup_tmp; return 1
    fi
  else
    # 还原 caddy 端口
    sed -i 's|^\( *\)ports: \["80:80"\] *# veilx-proxy.*|\1ports: ["80:80", "443:443", "443:443/udp"]|' "$work" || { px_cleanup_tmp; return 1; }
  fi

  cat "$work" > "$f" || { px_cleanup_tmp; return 1; }
  px_cleanup_tmp
  return 0
}

menu_proxy() {
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found" "找不到 $INSTALL_DIR")"
  cd "$INSTALL_DIR"
  while :; do
    # 未部署时只给一个入口:一键向导。菜单里堆满 SNI/flow/uTLS 这种词
    # 只会让不懂网络的人不敢按,也更容易点错把站点搞挂。
    if ! px_enabled; then
      cat <<EOF

┌────────────────────────────────────────────────────────┐
│  $(L "VeilX dedicated proxy" "VeilX 专用代理")   [$(L "not set up" "尚未部署")]
└────────────────────────────────────────────────────────┘
  $(L "Lets your phone connect even on a restricted or unstable network," "让你的手机在受限或不稳定的网络下也能连上这台服务器,")
  $(L "by disguising the connection as your own website." "方法是把连接伪装成你自己的网站。")

  1) $(L "Set it up now (guided, one question)" "一键部署(向导,只问一个问题)")
  0) $(L Back 返回)
EOF
      local c0; c0="$(px_ask "$(L "Select [0-1]: " "请选择 [0-1]: ")")"
      case "$c0" in
        1) px_wizard ;;
        *) return 0 ;;
      esac
      press_enter
      continue
    fi

    local st port
    st="$(L "ON" "运行中")"; port="$(px_port)"
    cat <<EOF

┌────────────────────────────────────────────────────────┐
│  $(L "VeilX dedicated proxy" "VeilX 专用代理")   [$st · $(L "port" 端口) $port]
└────────────────────────────────────────────────────────┘
  1) $(L "Add a device → get its link + QR code" "添加设备 → 得到链接和二维码")
  2) $(L "My devices" "我的设备列表")
  3) $(L "Show a device's link/QR again" "重新显示某台设备的链接/二维码")
  4) $(L "Check status" "检查运行状态")
  5) $(L "Turn it off" "关闭代理")
  9) $(L "Advanced settings (only if you know what you're doing)" "高级设置(不懂就别动)")
  0) $(L Back 返回)
EOF
    local c; c="$(px_ask "$(L "Select: " "请选择: ")")"
    case "$c" in
      1) px_add_client ;;
      2) px_list ;;
      3) px_list
         local n="" i=0 uuid label rest
         n="$(px_ask "$(L "Which number? " "第几个? ")")"
         while IFS="$(printf '\t')" read -r uuid label rest; do
           [ -n "$uuid" ] || continue; i=$((i+1))
           [ "$i" = "$n" ] && { px_print_client "$uuid" "${label:-device}"; break; }
         done < "$(px_clients)" ;;
      4) px_status ;;
      5) px_disable ;;
      9) px_config ;;
      0|"") return 0 ;;
      *) warn "$(L "Invalid choice" "无效选择")" ;;
    esac
    press_enter
  done
}

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


# =====================================================================
# CF Origin 证书(全橙云模式)
# ---------------------------------------------------------------------
# 橙云下 Caddy 自动 HTTPS 一定失败,两条验证方式全被 CF 挡住:
#   · TLS-ALPN-01:CF 在边缘终止 TLS,acme-tls/1 这个 ALPN 传不到源站 —— 必失败
#   · HTTP-01    :Full(Strict) 下是死锁 —— CF 回源要求源站already有有效证书,
#                  而你正是因为没有证书才在申请
# 解法:用 CF 后台签的 Origin Certificate(免费/15 年/只有 CF 认它),Caddy 用
# tls 指令直接加载,全程不碰 ACME。
# 关键设计:证书路径 + 开关(CF_ORIGIN)都存进 .env,Caddyfile 的生成逻辑读它 ——
# 所以以后 tuwunel config / update / 重跑安装 重新生成 Caddyfile 时会自动带上
# tls 指令,不会像"手动改 Caddyfile"那样被覆盖掉。
# =====================================================================
CF_DIR_NAME="cf-origin"

# 读取用户粘贴的一段 PEM:忽略 BEGIN 之前的杂物,读到 END 行为止。
# 容忍从网页/Windows 复制来的 CRLF(否则 openssl 会报莫名其妙的解析错)。
cf_read_pem() {
  local line out=""
  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [ -z "$out" ]; then
      case "$line" in *-----BEGIN*) out="$line"$'\n';; *) continue;; esac
    else
      out="$out$line"$'\n'
      case "$line" in *-----END*) break;; esac
    fi
  done
  printf '%s' "$out"
}

# 取证书的 SAN,输出形如 DNS:example.com,DNS:*.example.com
# 不用 `openssl x509 -ext`(那是 OpenSSL 3 专属,LibreSSL/旧版会报 unknown option
# 并静默返回空 → SAN 检查会把好证书误判成坏的)。-text 的格式各实现一致。
cf_san_of() {
  openssl x509 -in "$1" -noout -text 2>/dev/null \
    | awk '/Subject Alternative Name/{getline; gsub(/[ \t]/,""); print; exit}'
}

# 校验:能解析 / 没过期 / 证书与私钥配对 / SAN 同时覆盖根域名和 *.域名。
# 任何一条不过就拒绝落盘 —— 宁可不装,也不能让 Caddy 抱着一张废证书起不来。
cf_validate() {
  local crt="$1" key="$2" dom="$3" pc pk san
  openssl x509 -in "$crt" -noout >/dev/null 2>&1 || { warn "$(L "Certificate does not parse — did you paste the whole PEM block?" "证书解析失败 —— 整段 PEM 都粘上了吗?")"; return 1; }
  openssl pkey -in "$key" -noout >/dev/null 2>&1 || { warn "$(L "Private key does not parse" "私钥解析失败")"; return 1; }
  openssl x509 -in "$crt" -noout -checkend 0 >/dev/null 2>&1 || { warn "$(L "Certificate has already expired" "证书已经过期了")"; return 1; }
  pc="$(openssl x509 -in "$crt" -noout -pubkey 2>/dev/null | openssl md5 2>/dev/null)"
  pk="$(openssl pkey -in "$key" -pubout 2>/dev/null | openssl md5 2>/dev/null)"
  [ -n "$pc" ] && [ "$pc" = "$pk" ] || { warn "$(L "Certificate and private key are not a pair" "证书和私钥不是一对(粘串了?)")"; return 1; }
  san="$(cf_san_of "$crt")"
  case "$san" in *"DNS:$dom"*) :;; *) warn "$(L "Certificate SAN does not cover $dom (needed for the root domain)" "证书 SAN 不含 $dom(根域名要用)")"; return 1;; esac
  case "$san" in *"DNS:*.$dom"*) :;; *) warn "$(L "Certificate SAN does not cover *.$dom (needed for matrix./admin.)" "证书 SAN 不含 *.$dom(matrix. / admin. 等子域要用)")"; return 1;; esac
  return 0
}

# 交互收集 + 校验 + 落盘。$1=域名 $2=目标目录。成功 0 / 失败 1(失败时不动任何现有文件)。
cf_collect_and_store() {
  local dom="$1" dir="$2" crt key tmpd
  command -v openssl >/dev/null 2>&1 || { warn "$(L "openssl not found" "找不到 openssl")"; return 1; }
  has_tty || { warn "$(L "Pasting a certificate needs an interactive terminal" "粘贴证书需要交互终端")"; return 1; }

  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "CF Origin Certificate" "CF Origin 证书")" "$C_RESET"
  cat <<EOF
$(L "Get one from the Cloudflare dashboard (free, 15 years, only CF trusts it):" "去 Cloudflare 后台签一张(免费,15 年有效,只有 CF 认它):")
  1. SSL/TLS → Origin Server → Create Certificate
  2. $(L "Hostnames: keep the default" "主机名保持默认") ${C_GREEN}$dom, *.$dom${C_RESET}
  3. $(L "Private key type: RSA or ECC, format PEM. You get TWO blocks." "私钥类型 RSA 或 ECC 均可,格式 PEM。会给你【两段】。")
  4. ${C_YELLOW}$(L "The private key is shown ONCE — copy it before closing the page." "私钥只显示这一次,关掉页面就再也拿不到,先复制好。")${C_RESET}

$(L "Also confirm in the dashboard:" "另外后台还要确认:")
  · SSL/TLS → $(L "encryption mode" "加密模式") = ${C_GREEN}Full (Strict)${C_RESET}
  · Security → Bot Fight Mode = ${C_GREEN}Off${C_RESET}  $(L "(it 403s Matrix clients)" "(否则会 403 掉 Matrix 客户端)")
  · Rules → Cache Rules → /_matrix/* $(L and 和) /.well-known/matrix/* = ${C_GREEN}Bypass cache${C_RESET}
EOF
  press_enter "$(L "Ready? Press Enter, then paste the CERTIFICATE… " "准备好了按回车,然后粘贴【证书】… ")"

  echo ""
  echo "$(L "Paste the CERTIFICATE (from -----BEGIN CERTIFICATE----- to -----END CERTIFICATE-----):" "粘贴【证书】(从 -----BEGIN CERTIFICATE----- 到 -----END CERTIFICATE-----):")"
  if [ -t 0 ]; then crt="$(cf_read_pem)"; else crt="$(cf_read_pem < /dev/tty)"; fi
  echo ""
  echo "$(L "Paste the PRIVATE KEY (from -----BEGIN ... PRIVATE KEY----- to -----END ... PRIVATE KEY-----):" "粘贴【私钥】(从 -----BEGIN ... PRIVATE KEY----- 到 -----END ... PRIVATE KEY-----):")"
  if [ -t 0 ]; then key="$(cf_read_pem)"; else key="$(cf_read_pem < /dev/tty)"; fi

  case "$crt" in *CERTIFICATE*) :;; *) warn "$(L "That was not a certificate" "粘进来的不是证书")"; return 1;; esac
  case "$key" in *PRIVATE*KEY*) :;; *) warn "$(L "That was not a private key" "粘进来的不是私钥")"; return 1;; esac
  case "$key" in *CERTIFICATE*) warn "$(L "You pasted the certificate twice — the second block must be the PRIVATE KEY" "两段都粘成证书了 —— 第二段要粘【私钥】")"; return 1;; esac

  tmpd="$dir.tmp.$$"
  ( umask 077; mkdir -p "$tmpd" ) || { warn "$(L "Cannot create $tmpd" "无法创建 $tmpd")"; return 1; }
  printf '%s' "$crt" > "$tmpd/origin.pem"
  printf '%s' "$key" > "$tmpd/origin.key"

  if ! cf_validate "$tmpd/origin.pem" "$tmpd/origin.key" "$dom"; then
    rm -rf "$tmpd"
    warn "$(L "Certificate rejected — nothing on disk was changed." "证书未通过校验 —— 磁盘上什么都没改。")"
    return 1
  fi

  ( umask 077; mkdir -p "$dir" ) || { rm -rf "$tmpd"; return 1; }
  mv -f "$tmpd/origin.pem" "$dir/origin.pem" && mv -f "$tmpd/origin.key" "$dir/origin.key" || { rm -rf "$tmpd"; return 1; }
  rm -rf "$tmpd"
  chmod 700 "$dir" 2>/dev/null || true
  chmod 644 "$dir/origin.pem" 2>/dev/null || true
  chmod 600 "$dir/origin.key" 2>/dev/null || true
  ok "$(L "Certificate validated and saved to $dir" "证书已通过校验,保存在 $dir")"
  return 0
}

# 打印当前证书状态(SAN / 到期时间)。没装返回 1。
cf_cert_status() {
  local dir="${INSTALL_DIR:-/opt/tuwunel}/$CF_DIR_NAME" exp san
  if [ ! -s "$dir/origin.pem" ] || [ ! -s "$dir/origin.key" ]; then
    echo "  $(L "CF Origin cert: not installed" "CF Origin 证书: 未安装")"; return 1
  fi
  san="$(cf_san_of "$dir/origin.pem")"
  exp="$(openssl x509 -in "$dir/origin.pem" -noout -enddate 2>/dev/null | cut -d= -f2)"
  echo "  $(L "Covers" "覆盖"): ${san:-?}"
  echo "  $(L "Expires" "到期"): ${exp:-?}"
  if ! openssl x509 -in "$dir/origin.pem" -noout -checkend 2592000 >/dev/null 2>&1; then
    warn "$(L "Less than 30 days left — re-issue it in the CF dashboard and run: sudo tuwunel cf-cert" "剩余不到 30 天 —— 去 CF 后台重签,然后执行: sudo tuwunel cf-cert")"
  fi
  return 0
}

# 装/换证书:收集 → 落盘 → 写 CF_ORIGIN=1 → 重新生成 Caddyfile 并重启
cf_cert_paste() {
  local dom
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; SELF_BIN="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"
  dom="$(env_saved MATRIX_DOMAIN)"
  [ -n "$dom" ] || { warn "$(L "No deployed config found — install the server first" "未找到已部署配置 —— 请先装服务器")"; return 1; }
  cf_collect_and_store "$dom" "$INSTALL_DIR/$CF_DIR_NAME" || return 1
  px_env_set CF_ORIGIN 1 || warn "$(L "Could not write .env" "写入 .env 失败")"
  px_env_set USE_CDN   1 || true
  echo ""
  echo "$(L "Applying: regenerating Caddyfile and restarting…" "正在应用:重新生成 Caddyfile 并重启…")"
  if [ -f "$SELF_BIN" ]; then
    CF_ORIGIN=1 INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config
  else
    warn "$(L "Script copy missing — run: sudo tuwunel config" "缺少脚本副本 —— 请手动执行: sudo tuwunel config")"
  fi
}

# 关掉全橙云模式,回到 Caddy 自动 HTTPS(证书文件保留,想再开不用重签)
cf_cert_off() {
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; SELF_BIN="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"
  warn "$(L "Switch the records back to grey-cloud (DNS only) FIRST — otherwise Caddy still cannot get a certificate and the site stays down." "先把 DNS 记录改回灰云(仅 DNS)—— 否则 Caddy 照样签不出证书,站点会一直起不来。")"
  ask_opt "$(L "Records already grey-cloud? Continue? [y/N]: " "记录已经改回灰云了?继续吗? [y/N]: ")" "n"
  case "$REPLY" in y|Y) :;; *) echo "$(L Cancelled 已取消)"; return 0;; esac
  px_env_set CF_ORIGIN 0 || true
  if [ -f "$SELF_BIN" ]; then
    CF_ORIGIN=0 INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" config
  else
    warn "$(L "Script copy missing — run: sudo tuwunel config" "缺少脚本副本 —— 请手动执行: sudo tuwunel config")"
  fi
}

menu_cf_cert() {
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  local st
  [ "$(env_saved CF_ORIGIN)" = "1" ] && st="$(L ON 已开启)" || st="$(L OFF 未开启)"
  printf '\n%s%s%s  [%s]\n' "$C_B$C_CYAN" "$(L "CF Origin certificate — full orange-cloud mode" "CF Origin 证书 —— 全橙云模式")" "$C_RESET" "$st"
  cf_cert_status || true
  cat <<EOF

$(L "Behind an orange cloud Caddy can never get its own certificate; this loads a" "橙云后面 Caddy 永远签不出自己的证书;开启后改为加载一张")
$(L "CF-issued Origin Certificate instead (free, 15 years)." "CF 签发的 Origin 证书(免费,15 年)。")
${C_YELLOW}$(L "Cost of full orange-cloud: 100MB upload cap, and voice/video calls will not work." "全橙云的代价:上传上限 100MB,且语音视频通话用不了。")${C_RESET}

  1) $(L "Install / replace the certificate (paste it from the CF dashboard)" "安装 / 更换证书(从 CF 后台粘贴)")
  2) $(L "Turn OFF — back to Caddy automatic HTTPS (grey-cloud / DNS only)" "关闭 —— 回到 Caddy 自动 HTTPS(灰云 / 仅 DNS)")
  0) $(L Back 返回)
EOF
  ask_opt "$(L "Select [0-2]: " "请选择 [0-2]: ")" "0"
  case "$REPLY" in
    1) cf_cert_paste ;;
    2) cf_cert_off ;;
    *) : ;;
  esac
}


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
# 子命令: proxy —— VeilX 专用代理(REALITY)。无参进菜单,也可直接带动作。
if [ "${1:-}" = "proxy" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  case "${2:-}" in
    wizard|setup)    px_wizard ;;
    enable)          px_enable ;;
    disable)         px_disable ;;
    config|settings) px_config ;;
    add|add-client)  px_add_client "${3:-}" "${4:-}" ;;
    list)            px_list ;;
    "")              menu_proxy ;;
    *) die "$(L "Usage: sudo tuwunel proxy [wizard|enable|disable|config|add [label] [uuid]|list]" "用法: sudo tuwunel proxy [wizard|enable|disable|config|add [备注] [uuid]|list]")" ;;
  esac
  exit 0
fi

if [ "${1:-}" = "enable-oprf" ];  then ENABLE_OPRF=1; RECONFIG=1; set --; fi
if [ "${1:-}" = "disable-oprf" ]; then ENABLE_OPRF=0; RECONFIG=1; set --; fi
if [ "${1:-}" = "oprf" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; SELF_BIN="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — install the server first" "找不到 $INSTALL_DIR —— 请先装服务器")"
  menu_oprf; exit 0
fi
if [ "${1:-}" = "oprf-repair" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found" "找不到 $INSTALL_DIR")"
  oprf_repair; exit 0
fi
# 子命令: cf-cert —— CF Origin 证书(全橙云模式)。无参进小菜单。
if [ "${1:-}" = "cf-cert" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; SELF_BIN="${SELF_BIN:-$INSTALL_DIR/tuwunel-installer.sh}"
  [ -d "$INSTALL_DIR" ] || die "$(L "$INSTALL_DIR not found — install the server first" "找不到 $INSTALL_DIR —— 请先装服务器")"
  case "${2:-}" in
    status)        cf_cert_status ;;
    off|disable)   cf_cert_off ;;
    ""|set|paste)  menu_cf_cert ;;
    *) die "$(L "Usage: sudo tuwunel cf-cert [status|off]" "用法: sudo tuwunel cf-cert [status|off]")" ;;
  esac
  exit 0
fi
if [ "${1:-}" = "privacy" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; menu_privacy; exit 0; fi
if [ "${1:-}" = "forget-secrets" ]; then INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"; menu_forget_secrets; exit 0; fi
# 子命令: lang —— 切换脚本界面语言(English / 简体中文),写进 .env 持久化(装好后随时可改)
if [ "${1:-}" = "lang" ]; then
  INSTALL_DIR="${INSTALL_DIR:-/opt/tuwunel}"
  [ -f "$INSTALL_DIR/.env" ] || die "$(L "$INSTALL_DIR/.env not found — is the server deployed?" "找不到 $INSTALL_DIR/.env(服务器是否已部署?)")"
  LCUR="$(env_saved UI_LANG)"; LCUR="${LCUR:-zh}"
  printf '\nLanguage / 语言   (当前 Current: %s)\n  [1] English\n  [2] 中文(简体)\n' "$LCUR"
  ask_opt "→ [1/2]: " ""
  case "$REPLY" in 1) LNEW=en;; 2) LNEW=zh;; *) echo "$(L "Unchanged." "未改动。")"; exit 0;; esac
  if grep -qE '^UI_LANG=' "$INSTALL_DIR/.env" 2>/dev/null; then
    sed -i "s/^UI_LANG=.*/UI_LANG=$LNEW/" "$INSTALL_DIR/.env"
  else
    printf 'UI_LANG=%s\n' "$LNEW" >> "$INSTALL_DIR/.env"
  fi
  UI_LANG="$LNEW"
  ok "$(L "Interface language set to English (menu / prompts / messages)." "界面语言已切换为简体中文(菜单/提示/消息)。")"
  exit 0
fi
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
  3) $(L "Change config (admin panel: VeilX / Ketesa · calls · file size)" "修改配置(管理后台:VeilX自研/Ketesa · 通话 · 文件上限)")
  4) $([ "$(env_saved ENABLE_ADMIN)" = "1" ] && L "Disable Web admin panel" "关闭 Web 管理后台" || L "Enable Web admin panel (VeilX Admin; add to an existing server)" "开启 Web 管理后台(VeilX 自研,老服务器补装)")
  5) $(L "Back up now (config + database + media)" "立即备份(配置 + 数据库 + 媒体)")
  6) $(L "Upgrade service images (docker pull latest)" "升级服务镜像(docker 拉最新)")
  7) $(L "Clean up disk" "清理磁盘")
  8) $(L "Restart all services" "重启所有服务")
  9) $(L "Update script + apply new features (pull latest from GitHub, data untouched)" "更新脚本 + 应用新功能(从 GitHub 拉最新,数据不动)")
 10) $(L "Uninstall completely" "彻底卸载")
  p) $(L "Privacy hardening / metadata cleanup (what can be deleted, clear logs)" "隐私加固 / 元数据清理(看能删什么、清日志)")
  s) $(L "Wipe plaintext credentials file (traceless cleanup: remove on-disk password/token)" "涂销明文凭据文件(无痕清理:去掉磁盘上的明文密码/邀请码)")
  b) $(L "Scheduled encrypted backup (optional: weekly auto, with rotation/skip-if-full)" "自动定时加密备份(可选:开启后每周自动,含轮转/满盘跳过)")
  a) $(L "Change admin panel URL (admin. → another subdomain)" "修改后台网址(admin. → 别的子域)")
  x) $(L "VeilX dedicated proxy (restricted-network connectivity; link + QR for the app)" "VeilX 专用代理(受限网络连接;给 App 出链接+二维码)")$([ "$(env_saved ENABLE_PROXY)" = "1" ] && L "  [ON]" "  [已开启]")
  o) $(L "VeilX hardening: server-assisted PIN (lost offline phones can't be cracked)" "VeilX 加固:服务器辅助 PIN(丢失的离线手机无法破解)")$([ "$(env_saved ENABLE_OPRF)" = "1" ] && L "  [ON]" "  [已开启]")
  c) $(L "CF Origin certificate (full orange-cloud: paste the cert Cloudflare generated)" "CF Origin 证书(全橙云:粘贴 Cloudflare 生成的证书)")$([ "$(env_saved CF_ORIGIN)" = "1" ] && L "  [ON]" "  [已开启]")
  L) $(L "Switch interface language → 中文" "切换界面语言 → English")   (语言 / Language)
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
        x|X) menu_proxy ;;
        o|O) menu_oprf ;;
        c|C) menu_cf_cert ;;
        p|P) menu_privacy ;;
        s|S) menu_forget_secrets ;;
        b|B) menu_autobackup ;;
        a|A) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" admin-url || warn "$(L "script copy missing" "缺少脚本副本")"
             [ -d "$INSTALL_DIR" ] || exit 0 ;;
        l|L) [ -f "$SELF_BIN" ] && INSTALL_DIR="$INSTALL_DIR" bash "$SELF_BIN" lang || warn "$(L "script copy missing" "缺少脚本副本")"
             UI_LANG="$(env_saved UI_LANG)"; [ -n "$UI_LANG" ] || UI_LANG=zh ;;   # 重读,菜单立即用新语言重绘
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
M_HOST="matrix.$DOMAIN"; LK_HOST="livekit.$DOMAIN"; RTC_HOST="matrix-rtc.$DOMAIN"; CALL_HOST="call.$DOMAIN"
# 管理后台子域名(默认 admin;可改成 console/manage 等)。ADMIN_SUB= 预设或安装时选择,存 .env。
_ADMIN_SUB_ENV="${ADMIN_SUB:-}"                                  # 记录是否由环境变量显式传入(用于 EXPLICIT 判定)
ADMIN_SUB="${ADMIN_SUB:-$(env_saved ADMIN_SUB)}"                 # 环境变量 > 旧配置;都没有则留空,下面按后台类型定默认
ADMIN_SUB_SET="$ADMIN_SUB"                                       # 非空 = 已显式指定过子域名(交互里不再强改)
if [ -z "$ADMIN_SUB" ]; then
  # 默认子域名随后台类型:VeilX 自研后台 → veilx.域名;Ketesa → admin.域名。
  case "${ADMIN_UI:-$(env_saved ADMIN_UI)}" in ketesa) ADMIN_SUB="admin";; *) ADMIN_SUB="veilx";; esac
fi
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
EXPLICIT=0; [ -n "${REG_MODE:-}${ENABLE_FEDERATION:-}${ENABLE_CALLS:-}${ENABLE_WEB:-}${ENABLE_ADMIN:-}${ENABLE_ELEMENTX:-}${ENABLE_PRIVACY:-}${PRIVACY:-}${MAX_UPLOAD:-}${_ADMIN_SUB_ENV:-}${ENABLE_OPRF:-}${CF_ORIGIN:-}${VEILX_ONLY:-}" ] && EXPLICIT=1
# ============ VeilX 孤岛姿态:锁死,不再逐项询问 ============
# VeilX = 自建、只服务本团队的孤岛。以下六项是产品定义的一部分,不作为安装选项:
#   REG_MODE=token       仅持邀请码者可注册
#   ENABLE_FEDERATION=0  关联邦,外人无法向成员发消息(攻击面最小)
#   ENABLE_WEB=0         不装 Element Web 第三方网页客户端
#   ENABLE_ELEMENTX=0    关 Element X 自助注册(原生 OIDC)
#   ENABLE_PRIVACY=1     隐私加固/元数据最小化(IP 不入库、关在线状态/正在输入、撤回即焚、关遥测)
#   ENABLE_OPRF=1        服务器辅助 PIN(失窃离线手机无法爆破 PIN)
#   VEILX_ONLY=1         只面向 VeilX 客户端(拒绝 Element 等)
# 向导只再问【功能项】:通话 / 管理后台 / 文件上限。
# 极个别确需破例的,仍可用环境变量显式覆盖(如 ENABLE_FEDERATION=1),但绝不弹交互问题;
# 且刻意【不】读取旧配置里这几项 —— 重跑配置一律回到孤岛默认。
REG_MODE="${REG_MODE:-token}"
ENABLE_FEDERATION="${ENABLE_FEDERATION:-0}"
ENABLE_WEB="${ENABLE_WEB:-0}"
ENABLE_ELEMENTX="${ENABLE_ELEMENTX:-0}"
ENABLE_PRIVACY="${PRIVACY:-${ENABLE_PRIVACY:-1}}"
ENABLE_OPRF="${ENABLE_OPRF:-1}"
VEILX_ONLY="${VEILX_ONLY:-1}"
# —— 以下为仍可按团队需要选择的功能项 ——
ENABLE_CALLS="${ENABLE_CALLS:-$(env_saved ENABLE_CALLS)}"
ENABLE_ADMIN="${ENABLE_ADMIN:-$(env_saved ENABLE_ADMIN)}"   # 自托管 Web 管理后台(admin.你的域名)
ADMIN_UI="${ADMIN_UI:-$(env_saved ADMIN_UI)}"   # 后台用哪个:veilx(自研,默认)/ ketesa(通用 synapse-admin)
USE_CDN="${CDN:-$(env_saved USE_CDN)}"   # 服务器前是否有 Cloudflare/CDN 代理(影响 DNS 预检与提示;不改生成的配置)
CF_ORIGIN="${CF_ORIGIN:-$(env_saved CF_ORIGIN)}"   # 全橙云:用 CF Origin 证书顶替 ACME(会改 Caddyfile:每个站点加 tls 指令)
MAX_UPLOAD="${MAX_UPLOAD:-}"
SAVED_BYTES="$(env_saved MAX_UPLOAD_BYTES)"

DEF_REG=1; DEF_FED=N; DEF_CALL=n; DEF_WEB=Y; DEF_ADMIN=Y; DEF_OPRF=Y; DEF_VONLY=Y
if [ "$RECONFIG" -eq 1 ] && [ "$EXPLICIT" -eq 0 ]; then
  has_tty || die "$(L "config needs an interactive terminal; or use env vars: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config" "config 需交互终端;或用环境变量: ENABLE_CALLS=1 sudo -E bash tuwunel-installer.sh config")"
  [ "$ENABLE_CALLS" = "1" ] && DEF_CALL=Y || DEF_CALL=n
  [ "$ENABLE_ADMIN" = "0" ] && DEF_ADMIN=n || DEF_ADMIN=Y
  echo ""; echo "$(L "Isolation + hardening: VeilX island (fixed) — reg=token, federation=off, VeilX-only, no Element Web, privacy on, OPRF on." "隔离+加固: VeilX 孤岛(固定)—— 注册=令牌、联邦=关、只面向VeilX、不装Element Web、隐私加固开、OPRF开。")"
  echo "$(L "Current (adjustable)" "当前(可调)"): $(L Calls 通话)[$([ "$ENABLE_CALLS" = "1" ] && L on 开 || L off 关)] · $(L Admin 管理后台)[$([ "$ENABLE_ADMIN" = "1" ] && L on 开 || L off 关)] · $(L Big-files 大文件)[$(human "${SAVED_BYTES:-4294967296}")]"
  echo "$(L "Press Enter = keep current value." "直接回车 = 保持当前值。")"
  # 只重问【功能项】;隔离/加固六项已锁死为孤岛默认,不清空、不再问。
  ENABLE_CALLS=""; ENABLE_ADMIN=""
fi

if has_tty && { [ -z "$ENABLE_CALLS" ] || [ -z "$ENABLE_ADMIN" ] || [ -z "$MAX_UPLOAD" ]; }; then
  printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "Install options: unsure? just press Enter for the recommended values. (Isolation + hardening are fixed by VeilX — not asked.)" "安装选项:看不懂就直接回车用推荐值。(隔离与加固已由 VeilX 写死,不再询问。)")" "$C_RESET"

  if [ -z "$ENABLE_CALLS" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 1/3] Voice/video calls (Element Call)" "【选项 1/3】语音/视频通话(Element Call)")" "$C_RESET"
    printf '%s\n' "$(L "  [n] Off (recommended first) — natively supported, but the call path is newer; get chat + big files stable first.
  [Y] On — also installs LiveKit + lk-jwt; needs two extra DNS records (livekit. / matrix-rtc.) and ports 7881/7882." "  [n] 关闭(推荐先关)—— tuwunel 原生支持,但通话链路较新;先跑稳聊天+大文件。
  [Y] 开启 —— 额外装 LiveKit + lk-jwt,需再加 livekit. / matrix-rtc. 两条 DNS 和 7881/7882 端口。")"
    ask_opt "$(L "→ [y/N, Enter=$DEF_CALL]: " "→ [y/N,回车=$DEF_CALL]: ")" "$DEF_CALL"
    case "$REPLY" in y|Y) ENABLE_CALLS=1;; *) ENABLE_CALLS=0;; esac
  fi

  if [ -z "$ENABLE_ADMIN" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 2/3] Web admin panel" "【选项 2/3】Web 管理后台")" "$C_RESET"
    printf '%s\n' "$(L "  [Y] On (recommended) — a graphical admin panel at admin.your-domain: manage users,
       issue/revoke invite codes, deactivate accounts, reset passwords — all in a browser.
       You'll pick WHICH panel next. Needs one extra 'admin.' DNS record. ~20-60MB RAM.
  [n] Off — manage only via the command line (sudo tuwunel menu / admin-room commands)." "  [Y] 开启(推荐)—— 在【admin.你的域名】放一个图形管理后台:浏览器里管理用户、
       发/吊销邀请码、停用账号、改密码,不用敲命令。下一步选【用哪个后台】。
       需再加一条 admin. 的 DNS。多占约 20-60MB 内存。
  [n] 关闭 —— 只用命令行(sudo tuwunel 菜单 / 管理员房间命令)管理。")"
    ask_opt "$(L "→ [Y/n, Enter=$DEF_ADMIN]: " "→ [Y/n,回车=$DEF_ADMIN]: ")" "$DEF_ADMIN"
    case "$REPLY" in n|N) ENABLE_ADMIN=0;; *) ENABLE_ADMIN=1;; esac
    # 选用哪个后台:VeilX 自研(默认)/ Ketesa(通用 synapse-admin)。
    if [ "$ENABLE_ADMIN" = 1 ] && [ -z "$ADMIN_UI" ]; then
      printf '%s\n' "$(L "   Which panel?
     [1] VeilX Admin (recommended) — our own, tailored to tuwunel: only shows features that
         actually work here, VeilX-branded, and (later) VeilX-only powers: reports, remote wipe.
     [2] Ketesa — the general synapse-admin panel; more Synapse pages, but several are broken on
         tuwunel (it targets full Synapse)." "   用哪个后台?
     [1] VeilX 自研(推荐)—— 我们自己写的,贴着 tuwunel:只显示这里真能用的功能,VeilX 品牌,
         并(后续)带 VeilX 专属能力:举报、远程销毁。
     [2] Ketesa —— 通用 synapse-admin 面板;Synapse 页面更多,但不少在 tuwunel 上是坏的
         (它照完整 Synapse 做)。")"
      ask_opt "$(L "   → [1/2, Enter=1]: " "   → [1/2,回车=1]: ")" "1"
      case "$REPLY" in 2) ADMIN_UI=ketesa;; *) ADMIN_UI=veilx;; esac
      # 没显式指定过子域名时,默认跟随后台类型:自研 → veilx.域名;Ketesa → admin.域名。
      if [ -z "$ADMIN_SUB_SET" ]; then
        case "$ADMIN_UI" in ketesa) ADMIN_SUB="admin";; *) ADMIN_SUB="veilx";; esac
        A_HOST="$ADMIN_SUB.$DOMAIN"
      fi
    fi
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
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "[Option 3/3] Max file size (send big files/photos/long videos)" "【选项 3/3】单文件上限(发大文件/大图/长视频)")" "$C_RESET"
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
case "$ADMIN_UI" in ketesa) :;; *) ADMIN_UI=veilx;; esac   # 默认 VeilX 自研后台
ENABLE_OPRF="${ENABLE_OPRF:-1}"; case "$ENABLE_OPRF" in 0) :;; *) ENABLE_OPRF=1;; esac
case "$ENABLE_ELEMENTX" in 0) :;; *) ENABLE_ELEMENTX=1;; esac
case "$ENABLE_PRIVACY" in 0) :;; *) ENABLE_PRIVACY=1;; esac
case "$REG_MODE" in token|open) :;; *) REG_MODE=token;; esac
if [ -n "$MAX_UPLOAD" ]; then MAX_UPLOAD_BYTES="$(to_bytes "$MAX_UPLOAD")"
elif [ -n "$SAVED_BYTES" ]; then MAX_UPLOAD_BYTES="$SAVED_BYTES"
else MAX_UPLOAD_BYTES=4294967296; fi

REQUIRED_HOSTS="$DOMAIN $M_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp"
[ "$ENABLE_ADMIN" = "1" ] && REQUIRED_HOSTS="$REQUIRED_HOSTS $A_HOST"
if [ "$ENABLE_CALLS" = "1" ]; then REQUIRED_HOSTS="$REQUIRED_HOSTS $LK_HOST $RTC_HOST $CALL_HOST"; PORT_LINE="80/tcp 443/tcp 443/udp 7881/tcp 7882/udp"; fi
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
      $RTC_HOST
      $CALL_HOST"
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
  # 全橙云:必须先问清楚。橙云下 Caddy 的 ACME 一定失败,不预先拿到 Origin 证书,
  # 装到最后会卡在"证书签不出→整站 502",而那时候用户已经不知道该回头改哪里了。
  if [ "$USE_CDN" = "1" ] && [ -z "$CF_ORIGIN" ]; then
    printf '\n%s%s%s\n' "$C_B$C_CYAN" "$(L "Full orange-cloud (every record Proxied)?" "要全橙云吗(所有记录都开代理)?")" "$C_RESET"
    printf '%s\n' "$(L "  [n] No (recommended) — matrix./livekit. stay grey-cloud, Caddy gets its own certs.
  [y] Yes — behind the orange cloud Caddy CANNOT get a certificate (TLS-ALPN-01 is
      terminated by CF; HTTP-01 deadlocks under Full (Strict)). You must paste a CF
      Origin Certificate, and this installer will ask you for it in a moment.
      Cost: 100MB upload cap, and voice/video calls will not work." "  [n] 不是(推荐)—— matrix. / livekit. 保持灰云,Caddy 自己签证书。
  [y] 是 —— 橙云后面 Caddy【签不出证书】(TLS-ALPN-01 被 CF 终止;HTTP-01 在
      Full(Strict) 下死锁)。必须粘一张 CF Origin 证书,稍后会让你粘。
      代价:上传上限 100MB,且语音视频通话用不了。")"
    ask_opt "$(L "→ [y/N, Enter=n]: " "→ [y/N,回车=n]: ")" "n"
    case "$REPLY" in y|Y) CF_ORIGIN=1;; *) CF_ORIGIN=0;; esac
  fi
  press_enter "$(L "Done with ① ②? Press Enter to start… (not done? Ctrl+C to quit) " "①② 做好了按回车开始…(没做?Ctrl+C 退出) ")"
fi

# ---------------------------------------------------------------------
# 1. DNS 预检
# ---------------------------------------------------------------------
case "$USE_CDN" in 1) :;; *) USE_CDN=0;; esac
case "$CF_ORIGIN" in 1) :;; *) CF_ORIGIN=0;; esac
# 全橙云 + 通话 = 一定不通(LiveKit 媒体走 UDP 7881/7882,CF 只代理 HTTP;而且
# use_external_ip=true 会把源站 IP 直接塞进 ICE candidate 发给每个通话参与者)。
if [ "$CF_ORIGIN" = "1" ] && [ "$ENABLE_CALLS" = "1" ]; then
  warn "$(L "Full orange-cloud + calls: LiveKit media is UDP and cannot pass through Cloudflare — calls will not work, and the origin IP leaks into ICE candidates anyway." "全橙云 + 通话:LiveKit 媒体走 UDP,过不了 Cloudflare —— 通话一定不通,而且源站 IP 照样会从 ICE candidate 漏出去。")"
fi
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
# 全橙云:证书必须在生成 Caddyfile 之前就位。拿不到就【退回自动 HTTPS】——
# 宁可退回,也不能让 Caddyfile 引用一个不存在的文件(那样 caddy 直接起不来 = 整站下线)。
( umask 077; mkdir -p "$CF_DIR_NAME" ) 2>/dev/null || true
if [ "$CF_ORIGIN" = "1" ] && { [ ! -s "$CF_DIR_NAME/origin.pem" ] || [ ! -s "$CF_DIR_NAME/origin.key" ]; }; then
  if ! cf_collect_and_store "$DOMAIN" "$PWD/$CF_DIR_NAME"; then
    warn "$(L "No usable CF Origin certificate — falling back to Caddy automatic HTTPS. If your records are orange-clouded the certificate will fail; set them to grey-cloud, or run: sudo tuwunel cf-cert" "没拿到可用的 CF Origin 证书 —— 退回 Caddy 自动 HTTPS。若记录是橙云,证书会签不出来;请改灰云,或稍后执行: sudo tuwunel cf-cert")"
    CF_ORIGIN=0
  fi
fi
[ -f .env ] && cp -a .env ".env.bak-$(date +%F-%H%M%S)" 2>/dev/null || true
env_get(){ grep -E "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2- || true; }
REG_TOKEN="$(env_get REG_TOKEN)"; [ -n "$REG_TOKEN" ] || REG_TOKEN="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
# VeilX 专用代理:重跑安装/改配置时保留开关(compose 重新生成后由 px_apply_compose 再注入)
ENABLE_PROXY="$(env_get ENABLE_PROXY)"; case "$ENABLE_PROXY" in 1) :;; *) ENABLE_PROXY=0;; esac
PROXY_PORT="$(env_get PROXY_PORT)"; PROXY_DEST="$(env_get PROXY_DEST)"
PROXY_SNI="$(env_get PROXY_SNI)";   PROXY_FLOW="$(env_get PROXY_FLOW)"
PROXY_FP="$(env_get PROXY_FP)"; PROXY_HOST="$(env_get PROXY_HOST)"
[ -n "${ENABLE_CALLS_KEYS:-}" ] || true
LK_KEY="$(env_get LIVEKIT_API_KEY)"; [ -n "$LK_KEY" ] || LK_KEY="API$(openssl rand -hex 6)"
LK_SECRET="$(env_get LIVEKIT_API_SECRET)"; [ -n "$LK_SECRET" ] || LK_SECRET="$(openssl rand -hex 32)"

# VEILX_ONLY 的连带效果:别家客户端的入口必须一起关掉,否则"只支持 VeilX"只是句空话。
# Element Web 是竞品客户端本身;oidc_native_auth 那条原生 OIDC 就是专门给 Element X
# 自助注册用的 —— 留着它们等于服务器一边挡 Element、一边把 Element 递给用户。
case "$VEILX_ONLY" in
  0|"") VEILX_ONLY="${VEILX_ONLY:-0}" ;;
  strict)
    # strict = 连图形后台都不装。普通档(1)已经没有任何绕过口子了(后台走同源的 admin
    # 主机,只放行它真正要用的十来个端点,里面没有 /sync 也没有 /send),所以 strict
    # 纯粹是"连这十来个端点也不想暴露"的更保守选择,代价是只能用命令行管理。
    ENABLE_WEB=0; ENABLE_ELEMENTX=0
    if [ "$ENABLE_ADMIN" = "1" ]; then
      warn "$(L "VEILX_ONLY=strict: not installing the graphical admin panel. Manage from: sudo tuwunel" "VEILX_ONLY=strict:不安装图形管理后台。请用 sudo tuwunel 命令行菜单管理。")"
    fi
    ENABLE_ADMIN=0 ;;
  *)
    VEILX_ONLY=1; ENABLE_WEB=0; ENABLE_ELEMENTX=0 ;;
esac

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
ADMIN_UI=$ADMIN_UI
ADMIN_SUB=$ADMIN_SUB
ENABLE_ELEMENTX=$ENABLE_ELEMENTX
ENABLE_PRIVACY=$ENABLE_PRIVACY
ENABLE_OPRF=$ENABLE_OPRF
ENABLE_PROXY=$ENABLE_PROXY
PROXY_PORT=$PROXY_PORT
PROXY_DEST=$PROXY_DEST
PROXY_SNI=$PROXY_SNI
PROXY_FLOW=$PROXY_FLOW
PROXY_FP=$PROXY_FP
PROXY_HOST=$PROXY_HOST
USE_CDN=$USE_CDN
CF_ORIGIN=$CF_ORIGIN
VEILX_ONLY=$VEILX_ONLY
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
allow_unlisted_room_search_by_id = false
# 注:show_all_local_users_in_user_directory 与 lockdown_public_room_directory 属于
# 【团队可发现性】,不在这里设 —— 它们由上面 [global] 统一按"团队通讯录"模型放开
# (元数据最小化 ≠ 关掉团队内部的用户/房间发现,两者是两回事)。此处若重复设置会与
# [global] 冲突(同一 key 出现两次),故刻意留在 [global]。

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
# 【团队通讯录】默认 false 时,搜索只返回"和你同过房 / 在公开房间里"的人 —— 一个刚注册、
# 还没进任何房的同事谁都搜不到。VeilX 是团队服务器,设 true 让任何成员都能在搜索里找到
# 本服【全部】用户。这只影响【用户目录】的可见性:私密房间不受影响,外服用户由客户端域名
# 过滤挡在门外。要退回"只显示见过的人"把这行删掉即可。
show_all_local_users_in_user_directory = true
# 【团队通讯录·房间】默认 false=普通成员就能把自己建的公开房发布到目录,别人才搜得到。
# 设 true 会锁成"只有管理员能发布",于是成员建的公开房永远进不了目录、谁都搜不到
# (客户端建公开房时发布被拒,会退回"不发布",房间存在但搜索为空)。VeilX 要成员能自助
# 建可被发现的群,这里必须放开。要收紧成"管理员审核制"就改成 true。
lockdown_public_room_directory = false
# 公开房间目录:不对联邦开放(下行),但本服已登录成员仍可查询 —— 通讯录里的"公开房间/群组"
# 靠的就是它,私密房间不发布就不进目录。
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

# ===== VEILX_ADMIN_FILES (generated by scripts/sync-admin.py — do not edit by hand) =====
# 把自研管理后台静态文件解包到 $1。内容 = index/css/js + logo(gzip tar → base64)。
# 由 scripts/sync-admin.py 从 veilx-admin/ 生成;别手改这段 base64。
veilx_admin_write_files() {
  local dir="${1:?veilx_admin_write_files: missing dir}"; mkdir -p "$dir"
  base64 -d <<'VEILX_ADMIN_B64' | tar xzf - -C "$dir"
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
VEILX_ADMIN_B64
}
# ===== /VEILX_ADMIN_FILES =====

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

  # 自托管通话前端 —— 不再从 call.element.io 拉界面。
  # 媒体本来就走自己的 LiveKit;把这一层也拿回来之后,通话链路【完全在自己服务器上】,
  # 断开外网也能内部通话,element.io 也看不到"谁在什么时候开了通话"这类元数据。
  element-call:
    image: ghcr.io/element-hq/element-call:latest
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    volumes:
      - ./element-call-config.json:/app/config.json:ro
    mem_limit: 128m
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

# 自托管 Web 管理后台。ADMIN_UI=ketesa 时才起 Ketesa 容器;VeilX 自研后台是纯静态,
# 不需要单独容器——由 Caddy 的 file_server 直接托管(见下方 veilx-admin 挂载与 Caddy 配置)。
if [ "$ENABLE_ADMIN" = "1" ] && [ "$ADMIN_UI" = "ketesa" ]; then
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

# VeilX 加固:服务器辅助 PIN(OPRF)。保管每账号的 ristretto255 密钥 k,对客户端盲化点算 k·B。
# 它看不到 PIN、不下发 k;因为解锁必须问它,失窃且离线的手机就无法爆破 PIN。
if [ "$ENABLE_OPRF" = "1" ]; then
  oprf_write_files
cat >> docker-compose.yml <<'EOF'

  oprf:
    build: ./oprf
    restart: unless-stopped
    logging: *log
    security_opt: ["no-new-privileges:true"]
    depends_on: [tuwunel]
    environment:
      HOMESERVER: "http://tuwunel:8008"   # 容器内直连,校验 token 归属(不出网)
      BIND: "0.0.0.0:8787"
      DB: "/data/oprf.db"
      RATE_LIMIT: "30"
      RATE_WINDOW_SECS: "3600"
    volumes:
      - ./data/oprf:/data
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
      - ./cf-origin:/etc/caddy/cf:ro          # 全橙云用的 CF Origin 证书(没开时是空目录,无副作用)
      - ./veilx-admin:/srv/veilx-admin:ro     # VeilX 自研后台静态文件(ADMIN_UI=veilx 时由 file_server 托管;否则是空目录,无副作用)
      - ./data/caddy/data:/data
      - ./data/caddy/config:/config
    mem_limit: 128m
    networks: [internal]

networks:
  internal: { driver: bridge }
EOF

# ---- well-known JSON(开通话则带 rtc_foci)----
if [ "$ENABLE_CALLS" = "1" ]; then
  # 通告自建通话前端(`io.element.call.url`):客户端据此自动指向 call.你的域名,
# 用户不必手动填,也就不会再落回 call.element.io。
CLIENT_WK="{\"m.homeserver\":{\"base_url\":\"https://$M_HOST\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://$RTC_HOST\"}],\"io.element.call.url\":\"https://$CALL_HOST\"}"
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

# ---- 管理后台文件:按 ADMIN_UI 写对应的一份 ----
# veilx-admin 目录始终存在(Caddy 恒挂载它;不用时是空目录,无副作用)。
mkdir -p veilx-admin
if [ "$ENABLE_ADMIN" = "1" ] && [ "$ADMIN_UI" = "veilx" ]; then
  # VeilX 自研后台:纯静态,解包到 veilx-admin/,由 Caddy file_server 托管(见 Caddyfile 的 $A_HOST 块)。
  # 面板同源调用 /_matrix、/_synapse、/oprf —— 都由那块的 handle 反代给 tuwunel / oprf。
  veilx_admin_write_files veilx-admin
  chmod -R a+rX veilx-admin   # Caddy 以非 root 运行,静态文件须可读(无机密)
  rm -f ketesa-config.json 2>/dev/null || true
elif [ "$ENABLE_ADMIN" = "1" ] && [ "$ADMIN_UI" = "ketesa" ]; then
  # Ketesa 配置:restrictBaseUrl 锁死"服务器地址"输入框,指向 admin 主机自己(同源、免 CORS、
  # 无需在 matrix 主机为后台开例外)。wellKnownDiscovery=false = 直连 admin 主机上的 /_matrix 与 /_synapse。
  find veilx-admin -mindepth 1 -delete 2>/dev/null || true   # 清空未用的自研后台文件
  cat > ketesa-config.json <<EOF
{"restrictBaseUrl":"https://$A_HOST","wellKnownDiscovery":false}
EOF
  chmod 644 ketesa-config.json   # Ketesa 以非 root(sws)运行,须可读;无机密(仅指向你的服务器地址)
else
  rm -f ketesa-config.json 2>/dev/null || true
  find veilx-admin -mindepth 1 -delete 2>/dev/null || true
fi

# ---- Caddyfile ----
# 全橙云:显式指定证书 → Caddy 对这些站点完全不启用 ACME(橙云下 ACME 必失败)。
# CF_ORIGIN=0 时 $TLS_LINE 为空串,站点块里只多一个空行,行为和以前完全一致。
if [ "$CF_ORIGIN" = "1" ]; then
  TLS_LINE="	tls /etc/caddy/cf/origin.pem /etc/caddy/cf/origin.key"
else
  TLS_LINE=""
fi
# 只面向 VeilX 客户端:拒绝 User-Agent 不含 VeilX 的 /_matrix/client/* 与
# /_synapse/admin/*。三条刻意的例外,少一条就会打到自己人:
#  · /_matrix/client/versions —— 规范规定它是公开的,而且安装器的就绪检查、
#    菜单的在线检查、客户端的"主服务器加速"验证都在打它(那几处是裸 curl/URLSession)。
#  · 管理后台**不在这里开例外**。Ketesa 改成同源走 admin 主机(见 ketesa-config.json),
#    它需要的那十来个端点在 admin 主机上单独放行 —— 那份清单里没有 /sync、没有
#    /rooms/*/messages、没有 /send,所以就算有人把 Element 指过去也同步不了、发不出。
#    早先版本在这里放行 `Origin: https://admin.<域名>`,那是个人人可用的口子:
#    Origin 同样是请求方自述的,而 admin 子域是公开 DNS —— 加一个请求头即可绕过整道拦截。
#  · /_matrix/federation/* 与 /_matrix/key/* 不在拦截范围内 —— 联邦流量不带 UA 约束,
#    否则一旦开启联邦会整个断掉。
# ⚠️ UA 与 Origin 都是请求方自述的字符串,伪造成本约等于零;已登录的会话也不受影响。
# 这一层挡的是"随手装了个 Element 的同事",不是有心人。
if [ "$VEILX_ONLY" != "0" ]; then
  VEILX_GATE="	@notveilx {
		path /_matrix/client/* /_synapse/admin/*
		not path /_matrix/client/versions
		not header User-Agent *VeilX*
	}
	handle @notveilx {
		header Content-Type application/json
		respond \`{\"errcode\":\"M_FORBIDDEN\",\"error\":\"This homeserver serves VeilX clients only.\"}\` 403
	}
"
else
  VEILX_GATE=""
fi
# OPRF 挂在 matrix.域名/oprf/ 这个路径上:复用现有证书,不需要新域名/新 DNS。
if [ "$ENABLE_OPRF" = "1" ]; then
  OPRF_ROUTE=$'\thandle /oprf/* {\n\t\treverse_proxy oprf:8787\n\t}'
else
  OPRF_ROUTE=""
fi
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
$TLS_LINE
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
$TLS_LINE
$VEILX_GATE$OPRF_ROUTE
	handle {
		reverse_proxy tuwunel:8008
	}
}
EOF
# 管理子域 admin.域名:按 ADMIN_UI 出不同块。两者都把 /_matrix、/_synapse 白名单反代给 tuwunel;
# 区别在"非 API 路径":Ketesa=其静态容器;VeilX 自研=Caddy file_server 直接托管 veilx-admin/。
if [ "$ADMIN_UI" = "ketesa" ]; then
cat >> Caddyfile <<EOF

$A_HOST {
$TLS_LINE
	@opts method OPTIONS
	@ev path /_synapse/admin/v1/event_reports
	@ur path /_synapse/admin/v1/user_reports
	handle @ev {
		route {
			header Content-Type "application/json"
			respond @opts 204
			respond \`{"event_reports":[],"total":0}\` 200
		}
	}
	handle @ur {
		route {
			header Content-Type "application/json"
			respond @opts 204
			respond \`{"user_reports":[],"total":0}\` 200
		}
	}
	@ketesa_api path /_synapse/* /_matrix/media/* /_matrix/client/versions /_matrix/client/v1/* /_matrix/client/unstable/org.matrix.msc2965/auth_metadata /_matrix/client/v3/login /_matrix/client/v3/login/* /_matrix/client/v3/logout /_matrix/client/v3/account/whoami /_matrix/client/v3/profile/* /_matrix/client/v3/publicRooms /_matrix/client/v3/user/* /_matrix/client/v3/directory/*
	handle @ketesa_api {
		reverse_proxy tuwunel:8008
	}
	handle {
		reverse_proxy ketesa:8080
	}
}
EOF
else
cat >> Caddyfile <<EOF

$A_HOST {
$TLS_LINE
$OPRF_ROUTE
	@vxadmin_api path /_synapse/* /_matrix/media/* /_matrix/client/versions /_matrix/client/v1/* /_matrix/client/unstable/org.matrix.msc2965/auth_metadata /_matrix/client/v3/login /_matrix/client/v3/login/* /_matrix/client/v3/logout /_matrix/client/v3/account/whoami /_matrix/client/v3/profile/* /_matrix/client/v3/publicRooms /_matrix/client/v3/user/* /_matrix/client/v3/directory/*
	handle @vxadmin_api {
		reverse_proxy tuwunel:8008
	}
	handle {
		root * /srv/veilx-admin
		file_server
	}
}
EOF
fi
else
cat >> Caddyfile <<EOF

$M_HOST {
$TLS_LINE
$VEILX_GATE$OPRF_ROUTE
	handle {
		reverse_proxy tuwunel:8008
	}
}
EOF
fi
if [ "$ENABLE_CALLS" = "1" ]; then
cat >> Caddyfile <<EOF

$LK_HOST {
$TLS_LINE
	reverse_proxy livekit:7880
}
$RTC_HOST {
$TLS_LINE
	reverse_proxy lk-jwt-service:8080
}
$CALL_HOST {
$TLS_LINE
	reverse_proxy element-call:8080
}
EOF
fi

# ---- element-call-config.json(自托管通话前端)----
# 让前端指向【你自己的】homeserver 与 LiveKit,不引用 element.io 的任何东西。
if [ "$ENABLE_CALLS" = "1" ]; then
cat > element-call-config.json <<EOF
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://$M_HOST",
      "server_name": "$DOMAIN"
    }
  },
  "livekit": {
    "livekit_service_url": "https://$RTC_HOST"
  },
  "features": {
    "feature_use_device_session_member_events": true
  },
  "app_prompt": false
}
EOF
chmod 644 element-call-config.json
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
  # cf-origin 也要挂进来:caddy validate 会走完整 provision,tls 指令引用的证书文件
  # 不存在就会校验失败 —— 不挂的话开了 CF_ORIGIN 会被误判成"语法错"而跳过重启。
  if docker run --rm -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" -v "$PWD/cf-origin:/etc/caddy/cf:ro" caddy:2 \
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
# compose 刚被重新生成,若 VeilX 代理是开启状态,需把 xray 段和 caddy 端口改动重新注入。
if [ "$ENABLE_PROXY" = "1" ]; then px_apply_compose || warn "$(L "Failed to re-apply the VeilX proxy to docker-compose.yml" "重新注入 VeilX 代理到 docker-compose.yml 失败")"; fi
[ "$RECONFIG" -eq 0 ] && docker compose pull -q || true
# OPRF 先单独编译:它是唯一需要本地 build 的服务,失败不能连累整个 Matrix 起不来。
# 编译失败 → 自动退回“未开启”并重生成编排/Caddy,保证聊天服务照常可用。
if [ "$ENABLE_OPRF" = "1" ]; then
  echo "$(L "Building the VeilX hardening service (first time compiles Rust, 2-5 min)…" "编译 VeilX 加固服务(首次编译 Rust,约 2-5 分钟)…")"
  if docker compose build oprf; then
    ok "$(L "VeilX hardening service built" "VeilX 加固服务编译完成")"
  else
    warn "$(L "Build failed — continuing WITHOUT the hardening service so chat still works. Retry later: sudo tuwunel oprf" "编译失败 —— 先不装加固服务,保证聊天正常。稍后可重试: sudo tuwunel oprf")"
    ENABLE_OPRF=0
    sed -i "s/^ENABLE_OPRF=.*/ENABLE_OPRF=0/" .env 2>/dev/null || true
    # 把 oprf 服务段和 Caddy 路由摘掉(否则 up -d 仍会尝试 build 而失败)
    awk '/^  oprf:$/{skip=1} skip && /^  [a-z]/ && !/^  oprf:$/{skip=0} !skip' docker-compose.yml > .dc.tmp && mv .dc.tmp docker-compose.yml
    awk '/^\thandle \/oprf\/\* \{$/{skip=2} skip>0{if(/^\t\}$/)skip=0; next} {print}' Caddyfile > .cf.tmp && mv .cf.tmp Caddyfile
  fi
fi
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
$(L "Registration token:" "注册令牌:")  $REG_TOKEN$([ "$VEILX_ONLY" != "0" ] && L "   (used internally by adduser — do NOT hand this to members: with VeilX-only on, nothing can self-register)" "   (仅供 adduser 内部使用 —— 不要发给成员:开了仅-VeilX 之后没有任何客户端能自助注册)")
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

 ${C_B}${C_YELLOW}$(L "Member signup / login" "成员注册 / 登录")${C_RESET}
$(if [ "$VEILX_ONLY" != "0" ]; then
    printf '   %s\n   %s\n   %s' \
      "$(L "This server serves VeilX only, so members do NOT self-register — you create the account:" "本服务器只面向 VeilX,因此成员【不能自助注册】,由你建号:")" \
      "$(L "  1) ${C_B}sudo tuwunel adduser${C_RESET}  → prints a username + password" "  1) ${C_B}sudo tuwunel adduser${C_RESET}  → 打印用户名和密码")" \
      "$(L "  2) Send the member: server ${C_B}$DOMAIN${C_RESET} + that username/password; they sign in from VeilX." "  2) 把【服务器 ${C_B}$DOMAIN${C_RESET} + 该用户名密码】发给成员,让 TA 在 VeilX 里登录。")"
  else
    [ -n "$WEB_URL" ] && printf '   %s\n' "$(L "Web: open $C_B$C_GREEN$WEB_URL$C_RESET in a browser to register & log in." "网页版:浏览器打开 $C_B$C_GREEN$WEB_URL$C_RESET 直接注册登录。")"
    printf '   %s%s' "$(L "Phone app: install ${C_B}Element X${C_RESET} → server = ${C_B}$DOMAIN${C_RESET} → " "手机 App:装 ${C_B}Element X${C_RESET} → 服务器填 ${C_B}$DOMAIN${C_RESET} → ")" "$([ "$ENABLE_ELEMENTX" = 1 ] && L "register directly (invite token required) or log in." "可【直接注册】(需邀请码)或登录。" || L "log in with username + password (Element X cannot register here)." "用【用户名+密码登录】(此处 Element X 不能注册)。")"
    [ "$REG_MODE" = "token" ] && printf '\n   %s' "$(L "(invite token is in CREDENTIALS.txt)" "(邀请码在 CREDENTIALS.txt)")"
  fi)

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
$([ "$CF_ORIGIN" = "1" ] && printf '   %s\n   %s' "$(L "CF Origin certificate mode is ON — Caddy does not use ACME. Check it with: sudo tuwunel cf-cert status" "已启用 CF Origin 证书模式 —— Caddy 不走 ACME。查看: sudo tuwunel cf-cert status")" "$(L "CF dashboard must be: SSL/TLS = Full (Strict), Bot Fight Mode off, /_matrix/* cache bypassed." "CF 后台务必:SSL/TLS = Full (Strict)、Bot Fight Mode 关、/_matrix/* 设 Bypass cache。")")
   cd $INSTALL_DIR && docker compose ps    # $(L "all containers should be running" "容器都应 running")

 ${C_YELLOW}$(L "⚠️ Cloud security group must allow: $PORT_LINE" "⚠️ 云安全组放行: $PORT_LINE")${C_RESET}
$([ -n "$ADMIN_URL" ] && printf ' %s%s%s' "$C_DIM" "$(L "Note: the Ketesa admin panel relies on tuwunel v1.8.1+ Synapse admin API (newer); if the panel login errors, first run docker compose pull tuwunel. Core features (users/invites/rooms/media) work; reports/rate-limit and other edge pages being unavailable is normal." "提示:管理后台 Ketesa 依赖 tuwunel v1.8.1+ 的 Synapse 管理 API(较新);若面板登录报错,先 docker compose pull tuwunel 拉最新版。核心功能(用户/邀请码/房间/媒体)可用,举报/限速等边角页面不可用属正常。")" "$C_RESET")
${C_GREEN}========================================================${C_RESET}
EOF
