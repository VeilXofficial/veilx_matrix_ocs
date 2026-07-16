<div align="center">

# Matrix一键脚本
**你的服务器,你的数据 —— 为商业机密保护而生的自托管团队通讯系统**
**推荐使用ElementX客户端 VeilX客户端正在开发中，VeilX相比ElementX外观更加美观，整体更加易用，支持功能更多，修改Bug更快，代码开源可审计，运维团队设立在英国、新加坡、日本等地区。**

<div align="center">


客户资料、报价合同、内部讨论、语音视频会议 —— 全部只存在于你自己的服务器上。
一行命令部署,默认全封闭配置,不懂网络技术也能用:每个选择都有大白话说明。
基于 [Matrix](https://matrix.org) 开放协议,端到端加密,开源可审计。

</div>

---

## ✨ 装完你能得到什么

- 💬 文字聊天、群聊(端到端加密,服务器也看不到内容)
- 🖼️ 图片、视频、文件互传(单文件最大 100MB)
- 📞 一对一 / 多人群组语音、视频通话
- 🔒 数据 100% 在你自己的服务器上,没有广告、没有审查、没有"第三人"
- 📱 手机 / 电脑全平台可用(兼容 Element X 等所有 Matrix 客户端)
- 👥 团队成员由你创建账号,外人无法注册

---

## 📋 开始前的准备清单(3 样)

| 需要什么 | 具体要求 | 去哪儿弄 |
|---|---|---|
| **一台海外云服务器** | Ubuntu 22.04 或 24.04 系统,内存 ≥2GB,有公网 IP | 推荐 **CN2 GIA 线路**商家:[搬瓦工 BandwagonHost](https://bandwagonhost.com)、[DMIT](https://www.dmit.io)、HostDare、GigsGigsCloud 等 |
| **一个域名** | 任意后缀都行(.com / .org / .net…) | [Namecheap](https://www.namecheap.com)、[Cloudflare](https://www.cloudflare.com/products/registrar/)、[Porkbun](https://porkbun.com) 等海外注册商,一年几十元 |
| **10 分钟** | 全程复制粘贴,不需要会编程 | — |

> 💡 **为什么选 CN2 GIA 线路?** 这是中国电信的高级国际线路,从国内访问延迟低、不绕路、晚高峰不卡,聊天秒发、通话流畅。普通便宜 VPS(Vultr/RackNerd 等)也能用,但国内连接质量看运气。
> 💡 **为什么选海外商家?** 无需实名认证、无需备案,服务器和域名都不受国内监管约束——这正是自托管的意义。
> 💡 买服务器时系统镜像务必选 **Ubuntu 22.04** 或 **24.04**。2GB 内存即可流畅供小团队使用(脚本会自动加虚拟内存优化)。

---

## 第 1 步:给域名添加 4 条解析记录(约 2 分钟)

登录你**买域名的网站**,找到「域名解析 / DNS 解析 / DNS Records」,添加 **4 条 A 记录**。

假设你的域名是 `mychat.org`,服务器公网 IP 是 `1.2.3.4`,就这样填:

| 记录类型 | 主机记录(名称) | 记录值(指向) |
|---|---|---|
| A | `@`(代表主域名) | `1.2.3.4` |
| A | `matrix` | `1.2.3.4` |
| A | `livekit` | `1.2.3.4` |
| A | `matrix-rtc` | `1.2.3.4` |

> 📌 主机记录只填 `matrix` 这样的**前缀**,不要填完整的 `matrix.mychat.org`(面板会自动补全)。
> 📌 服务器公网 IP 在你买服务器的控制台首页能看到。
> 📌 添加后一般 1~10 分钟生效;没生效也没关系,安装脚本会自动等待。
> ⚠️ **用 Cloudflare 管理域名的注意**:这 4 条记录的"代理状态"必须是**灰色云(仅 DNS)**,不能开橙色云(代理)——橙色云会挡住通话流量。点一下那朵云就能切换。

## 第 2 步:放行端口(约 1 分钟)

登录你**买服务器的网站**控制台,找到「安全组 / 防火墙 / Firewall」,放行:

| 端口 | 协议 | 用途 |
|---|---|---|
| 80 | TCP | 申请 HTTPS 证书 |
| 443 | TCP + UDP | 网页与加密通信 |
| 7881 | TCP | 通话备用通道 |
| **7882** | **UDP** | **通话音视频(最容易漏!漏了 = 通话没声音没画面)** |

> 📌 有的服务商没有"安全组"这一层设置,那这步直接跳过——脚本会自动配置系统防火墙。

## 第 3 步:连接你的服务器(约 1 分钟)

打开终端:

- **Mac**:启动台搜索「终端 / Terminal」
- **Windows 10/11**:开始菜单搜索「PowerShell」

输入(IP 换成你的服务器 IP),回车后输入服务器密码——**输密码时屏幕不显示任何字符是正常的**,输完回车:

```bash
ssh root@你的服务器IP
```

第一次连接会问 `Are you sure you want to continue connecting?`,输 `yes` 回车。

> 📌 服务器密码在服务商控制台查看/重置。有的服务商默认用户不是 root(比如 `ubuntu`),就写 `ssh ubuntu@IP`,脚本会自动提权。

## 第 4 步:运行安装命令(约 5-10 分钟,全自动)

连上服务器后,把下面两行**整体复制**粘贴进终端,回车:

```bash
wget -O matrix.sh https://raw.githubusercontent.com/VeilXofficial/veilx/main/server/matrix-installer.sh
sudo bash matrix.sh
```

接下来跟着**中文向导**走:

1. 向导问你的**域名** → 直接输入(如 `mychat.org`),填错会重新问,不会退出
2. 向导问 **3 个安装选项** —— 每个选项屏幕上都有"作用 / 好处 / 风险"的大白话说明,看不懂就一路回车(推荐值即商业保密最安全组合):

   | 选项 | 直接回车(推荐) | 好处 | 其他选择及风险 |
   |---|---|---|---|
   | 注册方式 | **关闭注册** | 外人连注册入口都没有;员工账号由管理员统一发放,离职即删 | 邀请码注册(码泄露=陌生人可进);完全开放(垃圾账号灌爆,商用勿选) |
   | 语音视频通话 | **开启** | 团队开会不再依赖腾讯会议/Zoom,会议内容不出你的服务器 | 关闭:适合 1GB 小内存机器,DNS 也只需前 2 条记录 |
   | 联邦互通 | **关闭** | 服务器成为孤岛,外部任何人无法向成员发消息,零骚扰零钓鱼 | 开启:可与 matrix.org 等外部用户互聊,但暴露面变大 |

3. 向导列出第 1、2 步的检查清单 → 确认做过了就按回车
4. 之后全自动:检测 DNS(没生效自动等)→ 装 Docker → 生成所有密码密钥 → 启动服务 → 申请 HTTPS 证书 → 创建管理员

> 🤖 进阶:想跳过询问全自动安装?用环境变量预设,例如
> `REG_MODE=token ENABLE_CALLS=1 ENABLE_FEDERATION=0 sudo -E bash matrix.sh mychat.org`

看到这个就是成功:

```
========================================================
 🎉 部署完成!  mychat.org

 手机装 Element X,登录:
   服务器:  mychat.org
   账号:    admin
   密码:    xxxxxxxxxxxx
========================================================
```

> 🔑 **把账号密码抄下来!** 它也永久保存在服务器 `/opt/matrix/CREDENTIALS.txt`(随时 `cat /opt/matrix/CREDENTIALS.txt` 查看)。
> ⚠️ 如果结尾显示"部分完成",按屏幕中文提示处理;脚本可放心重复运行,不会弄坏已装好的部分。

## 第 5 步:手机 / 电脑登录使用

1. 安装客户端(当前推荐 **Element X**,我们的自研客户端 **VeilX 即将上线**,敬请期待):
   - 手机:**Element X**([iOS](https://apps.apple.com/app/element-x/id1631335820) / [Android](https://play.google.com/store/apps/details?id=io.element.android.x))
   - 电脑:[Element 桌面版](https://element.io/download) 或网页版 [app.element.io](https://app.element.io)
2. 登录:
   - **服务器地址**:填你的域名(如 `mychat.org`,**不是** matrix.mychat.org)
   - **账号 / 密码**:安装完成时显示的 `admin` 和密码
3. 用起来:➕ 建房间拉人 = 群聊;房间里 📞 / 🎥 = 语音/视频通话;📎 = 发图片视频文件

---

## 👥 添加团队成员

SSH 连上服务器后:

```bash
cd /opt/matrix && sudo bash matrix-installer.sh adduser
```

按提示输入新成员用户名、密码;问到 `Make admin` 时普通成员直接回车,管理员输 `yes`。然后把「你的域名 + 用户名 + 密码」发给成员登录即可。

> 🖱️ 喜欢图形界面?浏览器打开 [admin.etke.cc](https://admin.etke.cc),Homeserver URL 填 `https://matrix.你的域名`,用 admin 登录,即可点鼠标管理用户(建号/改密/封禁)。

## 🔧 日常维护(SSH 到服务器后执行)

```bash
cd /opt/matrix && docker compose ps                              # 服务状态(5 个都应 running)
cd /opt/matrix && docker compose logs -f synapse                 # 看日志(Ctrl+C 退出)
cd /opt/matrix && docker compose up -d                           # 重启 / 应用配置
cd /opt/matrix && docker compose pull && docker compose up -d    # 升级到最新版
```

## 💾 备份(建议每周一次)

密钥和数据库丢了就**无法恢复**,定期打包下载到本地:

```bash
# ① 在服务器上打包
cd /opt/matrix
docker compose exec -T postgres pg_dump -U synapse synapse | gzip > db-backup.sql.gz
tar czf veilx-backup-$(date +%F).tar.gz .env CREDENTIALS.txt db-backup.sql.gz \
    data/synapse/*.signing.key data/synapse/homeserver.yaml

# ② 在你自己电脑的终端执行:下载备份
scp root@你的服务器IP:/opt/matrix/veilx-backup-*.tar.gz ~/Desktop/
```

聊天里的图片视频在 `data/synapse/media_store/`,体积较大,按需另行备份。

## ❓ 常见问题

| 问题 | 原因与解决 |
|---|---|
| 粘贴命令报 `wget: command not found` 或 `sudo 不是内部命令` | 命令贴错地方了——要先完成**第 3 步 `ssh` 连上服务器**,在服务器的终端里粘贴,不是在自己电脑本地 |
| 登录提示"这不是 Matrix 服务器" | HTTPS 证书还没就绪。多等几分钟;确认第 1 步 4 条解析都指对了 IP,再 `cd /opt/matrix && docker compose restart caddy` |
| 通话能接通,但没声音没画面 | 99% 是第 2 步的 **7882/UDP** 没放行,去服务商安全组补上 |
| 安装时一直"DNS 还没生效" | 检查解析:类型是不是 **A**、主机记录是不是只填**前缀**、IP 有没有抄错 |
| 忘记 admin 密码 | `cat /opt/matrix/CREDENTIALS.txt`;或重跑 adduser 建个新管理员 |
| 加密房间老消息"无法解密" | 正常:新设备没有历史密钥。在旧设备上对新设备做"验证会话"即可 |
| 想彻底重装 | **先备份!**然后 `cd /opt/matrix && docker compose down`,`rm -rf /opt/matrix`,重跑安装命令 |

## 📦 项目结构

```
veilx/
├── server/     一键服务器安装器(进阶文档:server/README.md)
├── client/     VeilX 自研客户端(Telegram 风格,🚧 开发中即将上线,当前请先用 Element X)
└── docs/       架构说明(docs/ARCHITECTURE.md)
```

**服务端组件**:Caddy(自动 HTTPS)+ Synapse + PostgreSQL + LiveKit + lk-jwt-service,全部 Docker 编排,开源可审计。

## 📄 许可

[MIT](LICENSE) —— 随便用,欢迎 Star ⭐

---

<div align="center">
用 ❤️ 打造 · 让每个人都能拥有自己的私密通讯服务器
</div>
