# Matrix 服务器安装器

一键自托管的私密团队通讯:加密聊天、群聊、图片/视频/文件互传、一对一及群组语音视频通话,数据全在你自己的服务器。一行命令部署 Matrix 服务端(Synapse + Element Call + LiveKit),配套网页/桌面/移动多端客户端。Self-hosted encrypted team chat with group voice & video calls — one-command Matrix server installer + cross-platform client.


## 组件

Caddy(自动 HTTPS)+ Synapse(Matrix 家庭服务器)+ PostgreSQL + LiveKit(通话媒体)+ lk-jwt-service(通话授权),全部由 Docker 编排。

## 前提

1. 一台 **Ubuntu 22.04/24.04**(或 Debian 11+)服务器,有公网 IP
2. 一个域名,添加 **4 条 A 记录**全部指向服务器 IP:
   ```
   你的域名.com
   matrix.你的域名.com
   livekit.你的域名.com
   matrix-rtc.你的域名.com
   ```
3. 服务器商安全组放行端口:`80/tcp 443/tcp 443/udp 7881/tcp 7882/udp`

## 安装

```bash
wget -O matrix.sh https://raw.githubusercontent.com/VeilXofficial/veilx/main/server/matrix-installer.sh
sudo bash matrix.sh
```

脚本会自动:检测 DNS → 装 Docker → 配置内存/防火墙 → 生成全部密钥 → 启动服务 → 申请 HTTPS 证书 → 创建管理员账号。全程中文向导。

安装完成后,凭据保存在 `/opt/matrix/CREDENTIALS.txt`。

## 常用命令

```bash
# 添加团队成员
cd /opt/matrix && sudo bash matrix-installer.sh adduser

# 查看状态 / 日志
cd /opt/matrix && docker compose ps
cd /opt/matrix && docker compose logs -f synapse

# 重启(修改配置后)
cd /opt/matrix && docker compose up -d
```

## 特性

- **幂等**:可安全重复运行。已完成的部署只重启;半途失败的部署自动续装(密钥复用)。
- **健壮**:自动探测 SSH 端口防锁死、swap/防火墙失败不中断、DNS 未生效时自动等待重试、装完验收证书才报成功。
- **省心**:所有密钥自动生成,2G/4G/8G 内存自动分档调优。

## 备份(重要)

必须定期备份(缺一不可恢复):
- `/opt/matrix/data/synapse/你的域名.signing.key` (服务器签名密钥)
- `/opt/matrix/.env` 和 `data/synapse/homeserver.yaml` (全部密钥)
- 数据库:`docker compose exec -T postgres pg_dump -U synapse synapse | gzip > backup.sql.gz`
- `/opt/matrix/data/synapse/media_store/` (聊天里的图片视频文件)
