<div align="center">

# 私有 Matrix 通訊伺服器 · 一鍵部署（tuwunel 版）

**你的伺服器、你的資料 —— 為機密性與資料主權而生的自架團隊通訊系統。**

本版採用 **tuwunel**（Rust 引擎、內建資料庫、**免 PostgreSQL**）：更省資源、更穩定，**能像 Telegram 一樣傳大檔案／大圖／長影片**。2GB 記憶體即可撐起中型團隊。端對端加密、中繼資料最小化、邀請制註冊皆為**預設開啟**。一行指令部署 —— 不必是工程師，每個選項都有白話說明。

推薦用戶端：**Element X**。專屬的 **VeilX** 用戶端正在開發中（更美觀易用、功能更多、開源可稽核；營運團隊設於英國、新加坡、日本等地）。客戶資料、合約報價、內部討論、語音視訊會議 —— 全部只存在於你自己的伺服器上。基於開放的 [Matrix](https://matrix.org) 協定，原始碼公開可稽核（非商業免費）。

[English](../README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Bahasa Melayu](README.ms.md) · [فارسی](README.fa.md) · [简体中文](README.zh-CN.md) · **繁體中文** · [粵語](README.zh-HK.md)

</div>

---

## ✨ 裝完你能得到什麼

- 💬 文字聊天、群組（**端對端加密 —— 伺服器和主機商都看不到訊息內容**）
- 📁 **傳大檔案／大圖／長影片**（預設單檔上限 **4GB**，可自訂更大 —— 這是本版核心賣點）
- 📞 一對一／多人語音、視訊通話（可選）
- 📱 手機自助註冊：安裝 **Element X**、填入你的網域即可註冊登入，不必去 element.io
- 🌐 自家網域網頁版：瀏覽器打開 `https://你的網域` 直接註冊／登入，免安裝 App
- 🖥️ **圖形化網頁管理後台**（Ketesa）：管理使用者、發放／撤銷邀請碼、檢視房間與媒體
- 🔒 **預設隱私加固**：真實 IP 不入庫、撤回即真刪、關閉在線狀態、日誌不記 IP
- 👥 邀請制：預設只有拿到邀請碼的人能註冊，外人進不來
- ⚡ **省資源**：Rust 單一行程、無 PostgreSQL —— 2GB 記憶體撐 300 人

---

## 📋 開始前的準備（3 樣）

| 需要什麼 | 要求 | 去哪裡 |
|---|---|---|
| **一台雲端主機（VPS）** | Ubuntu 22.04／24.04（或 Debian 11+），有公網 IP。**依團隊人數選記憶體**（見下）。**要傳大檔案請預留足夠磁碟。** | [Vultr](https://www.vultr.com)、[Linode（Akamai）](https://www.linode.com)、[DigitalOcean](https://www.digitalocean.com)、[Hetzner](https://www.hetzner.com/cloud) 等你信任的商家 |
| **一個網域** | 任意結尾（.com／.org／.net…） | [Namecheap](https://www.namecheap.com)、[Porkbun](https://porkbun.com)、[Gandi](https://www.gandi.net) 等 |
| **10 分鐘** | 全程複製貼上，不用寫程式 | — |

> 💡 **依同時在線人數選記憶體**（同時活躍、關聯邦、純聊天＋檔案）：**1GB** ≈ 數十人（建議關通話）· **2GB** ≈ 300 人 · **4GB／2 vCPU** ≈ 500 人。tuwunel 很省，算力通常不是瓶頸。
> 💡 **磁碟才是大檔案的真變數。** 媒體存在伺服器本機磁碟，且因端對端加密無法去重，重度傳大檔案每月可增加數百 GB～TB。系統碟建議 ≥ 50–100GB，重度使用者請另備大容量磁碟或物件儲存，並留意選單裡的「清理磁碟」。
> 💡 **管轄地對隱私有影響。** 選一個你放心的商家與國家 —— 主機商原則上可被強制配合。端對端加密無論如何都保護訊息「內容」，但中繼資料存在主機上。
> 💡 下單時務必選 **Ubuntu 22.04／24.04** 映像檔。記憶體低於 2.5GB 時腳本會自動加虛擬記憶體（swap）。

---

## 第 0 步：準備作業系統（買對了就跳過）

僅支援 **Ubuntu 22.04／24.04**（或 Debian 11+）。

- **新主機**：下單時「作業系統／OS／Image」選 **Ubuntu 22.04 x86_64**（或 24.04）—— 這步就完成了。
- **系統不對**：用商家控制台的「重灌／Reinstall／Rebuild」安裝 Ubuntu 22.04。⚠️ 這會**清空所有資料**，舊主機請先備份。
- 不確定目前系統？連上後（第 3 步）執行 `cat /etc/os-release`。
- 裝錯也不怕：腳本偵測到不支援的系統會用中文明確告訴你，不會亂裝。

---

## 第 1 步：新增 DNS 記錄（約 2 分鐘）

登入你**買網域的網站**的 DNS 設定，新增 **A 記錄**。

假設網域 `mychat.org`、主機公網 IP `1.2.3.4`：

| 類型 | 主機（名稱） | 值 | 用途 |
|---|---|---|---|
| A | `@`（主網域） | `1.2.3.4` | 主網域＋網頁版＋委派 |
| A | `matrix` | `1.2.3.4` | 聊天伺服器 |
| A | `admin` | `1.2.3.4` | 網頁管理後台（關後台可省） |
| A | `livekit` | `1.2.3.4` | 通話（關通話可省） |
| A | `matrix-rtc` | `1.2.3.4` | 通話（關通話可省） |

> 📌 主機欄只填 `matrix` 這種**前綴**，不要填完整網域。
> 📌 記錄 1～10 分鐘生效；沒生效也沒關係，安裝程式會自動等待。
> 📌 只用聊天＋檔案（關通話）時，只需 `@`／`matrix`／`admin` 三條。
> ⚠️ **用 Cloudflare 的注意**：這幾條記錄必須是**灰色雲（僅 DNS）**，**不能開橙色雲（代理）**。橙色雲會 ① 把大檔案卡在 100MB 上限（免費／Pro）② 讓憑證簽不出 ③ 擋住通話。安裝時腳本會問是否使用 CDN（用了就選是，放寬檢查），但 `matrix` 主機務必保持灰色雲。

---

## 第 2 步：開放防火牆連接埠（約 1 分鐘）

在商家控制台的「安全群組／防火牆」開放：

| 連接埠 | 協定 | 用途 |
|---|---|---|
| 80 | TCP | 申請 HTTPS 憑證 |
| 443 | TCP + UDP | 網頁與加密通訊 |
| 7881 | TCP | 通話備用通道（關通話可省） |
| **7882** | **UDP** | **通話音訊視訊（最容易漏！漏了 = 通話沒聲音沒畫面）** |

> 📌 沒有「安全群組」這層設定的商家直接跳過 —— 腳本會自動設定系統防火牆。

---

## 第 3 步：連線到你的主機（約 1 分鐘）

打開終端機（macOS：「終端機」；Windows：「PowerShell」），輸入以下指令（IP 換成你的），回車後輸入主機密碼（**輸入密碼時螢幕不顯示任何字元是正常的**）：

```bash
ssh root@你的主機IP
```

第一次連線問 `Are you sure...` 時輸入 `yes` 回車。

> 📌 預設使用者不是 root（例如 `ubuntu`）就寫 `ssh ubuntu@IP`，腳本會自動提權。

---

## 第 4 步：執行安裝指令（約 5–10 分鐘，全自動）

連上後，**整段複製**貼進終端機回車：

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

跟著中文精靈走。會問 **6 個選項＋是否使用 CDN**，每個都有白話說明，看不懂就一路回車（預設值即最安全組合）：

| 選項 | 回車（推薦） | 說明 |
|---|---|---|
| 1 誰能註冊 | **需邀請碼** | 只有拿到你發的碼的人能註冊；首位註冊者＝管理員。（另可選完全開放，商用勿選） |
| 2 聯邦互通 | **關閉** | 孤島模式，外人無法對成員發訊息，攻擊面最小。 |
| 3 語音視訊通話 | **先關** | 需再加 `livekit`／`matrix-rtc` 兩條 DNS 和 7881／7882 連接埠；先跑穩聊天＋大檔案。 |
| 4 網頁用戶端 | **開啟** | 成員打開 `https://你的網域` 直接註冊登入，免安裝 App。 |
| 5 網頁管理後台 | **開啟** | 在 `admin.你的網域` 放一個圖形管理後台 Ketesa。 |
| 6 單檔上限 | **4G** | 設多大都行（如 10G）；越大越占磁碟。 |
| ＋ 是否使用 Cloudflare／CDN | **否** | 用了才選是（放寬 DNS 檢查）；`matrix` 仍須灰色雲。 |

> 🔒 **自動開啟（不會問你，裝完即有）**：① 新房間**強制端對端加密** ② **中繼資料最小化**（真實 IP 不入庫、撤回即真刪、關在線狀態、日誌不記 IP） ③ **Element X 手機自助註冊**（原生 OIDC，註冊仍需邀請碼）。要關中繼資料加固：`PRIVACY=0 sudo -E tuwunel config`。
> 🤖 **全自動不詢問**：`REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

之後全自動：偵測 DNS → 安裝 Docker → 系統調校 → 防火牆 → 產生設定 → 啟動服務 → 申請 HTTPS 憑證 → **自動建立管理員並印出帳號密碼**。

看到這個就是成功：

```
========================================================
 🎉 tuwunel 部署完成!  mychat.org
 (註冊[token] · 聯邦[關] · 通話[關] · 網頁[開] · 後台[開] · 手機註冊[開] · 大檔案[4G] · 引擎 tuwunel/Rust)

 成員註冊 / 登入
   網頁版(推薦):瀏覽器打開 https://mychat.org 直接註冊登入
   手機 App:裝 Element X → 伺服器填 mychat.org → 可註冊(需邀請碼)或登入

 管理員(已自動建立)
   帳號: admin    密碼: xxxxxxxxxxxx
   網頁管理後台: https://admin.mychat.org  (用上面的管理員帳號密碼登入)

 日常管理:  sudo tuwunel   (選單)    sudo tuwunel adduser   (加成員)
========================================================
```

> 🔑 **把管理員帳號密碼＋邀請碼抄下來！** 全部存在主機的 `/opt/tuwunel/CREDENTIALS.txt`（`cat /opt/tuwunel/CREDENTIALS.txt` 查看）。
> ⚠️ 結尾顯示「還沒就緒」多半是雲端安全群組沒放行 80／443，或 DNS 尚未全球生效。Caddy 會自動重試憑證，不需重裝。

---

## 第 5 步：手機／電腦登入使用

| 裝置 | 用戶端 | 下載 |
|---|---|---|
| iPhone／iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows／macOS／Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| 瀏覽器（免安裝） | 你的**自家網頁版** | 打開 `https://你的網域` |

**登入時伺服器填你的網域**（如 `mychat.org`，**不是** `matrix.mychat.org`），帳號密碼用安裝完成時顯示的。

> ⚠️ **連不上／Element X 顯示「無法連線至此家伺服器」？第一件事:檢查手機日期時間是否正確！**
> 手機時間不準 → HTTPS 憑證驗證失敗 → 直接連不上（很常見，尤其 Android）。
> 解法：手機 **設定 → 日期與時間 → 打開「自動設定」**，再重試。

---

## 👥 成員如何加入（三選一）

1. **管理員建帳號（最可控）**：`sudo tuwunel adduser` 一條指令建帳號並設密碼，把「網域＋使用者名稱＋密碼」發給成員。邀請碼全程不外流。
2. **發邀請碼，網頁自助註冊**：把邀請碼（在 `CREDENTIALS.txt`）＋ `https://你的網域` 發給成員，他們在瀏覽器自助註冊。
3. **發邀請碼，Element X 自助註冊**：成員裝 Element X → 伺服器填你的網域 → 建立帳號 → 輸入邀請碼。

---

## 🖥️ 圖形化管理後台（Ketesa，推薦）

安裝時（選項 5 開啟）會自動部署一個**圖形化網頁管理後台**，用滑鼠點就能管，不必打指令。

**怎麼進：** 瀏覽器打開 `https://admin.你的網域` → **直接用管理員帳號 `admin` ＋密碼登入**（不需額外門禁密碼，後台已鎖定到你的伺服器）。

**能做：** 管理使用者（建號／停用／改密碼）、**發放與撤銷邀請碼**、檢視房間／媒體、房間目錄、排程工作。

> 📌 後台裡「檢舉事件／被檢舉使用者」兩頁可能報錯或空白 —— 這是 tuwunel 未實作該功能，**正常**，你幾乎用不到。
> 📌 後台需要 tuwunel v1.8.1+（`:latest` 映像已含）。若後台登入報錯，先 `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`。
> 📌 舊伺服器補裝後台：`sudo tuwunel enable-admin`（需先加 `admin` 的 DNS）。

---

## 🔧 日常維護:管理選單

裝好後，**再次執行 `sudo tuwunel` = 打開中文管理選單**，什麼指令都不用記：

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  tuwunel 管理選單   你的網域                   │
└──────────────────────────────────────────────┘
  1) 檢視執行狀態          6) 升級服務映像
  2) 新增團隊成員          7) 清理磁碟
  3) 修改設定              8) 重啟所有服務
  4) 開/關 網頁管理後台    9) 更新腳本 + 套用新功能
  5) 立即備份             10) 徹底解除安裝
  p) 隱私加固 / 中繼資料清理
  s) 塗銷明文憑證檔(抗鑑識)
  b) 自動定時加密備份
  0) 離開
```

也可直接用指令：

```bash
sudo tuwunel adduser          # 加成員
sudo tuwunel config           # 改設定(回車=保持,資料帳號不動)
sudo tuwunel update           # 從 GitHub 拉最新腳本並套用新功能(資料不動)
sudo tuwunel enable-admin     # 舊伺服器補裝網頁管理後台
sudo tuwunel enable-elementx  # 開 Element X 手機自助註冊
sudo tuwunel autobackup       # 開啟每週自動加密備份
sudo tuwunel privacy          # 隱私/中繼資料:看能刪什麼、清日誌
sudo tuwunel forget-secrets   # 抗鑑識:塗銷磁碟上的明文密碼/邀請碼
sudo tuwunel uninstall        # 解除安裝
```

> 🔄 **改設定不用重裝**（選單 3）：重問選項，**回車＝保持目前值**，改完自動重啟，帳號／記錄／金鑰全不動。

---

## 🔒 隱私 / 抗鑑識（本版重點）

本系統為保護機密通訊而設計，**預設就把伺服器上的痕跡壓到最小**：

- ✅ **訊息內容端對端加密** —— 連你（營運方）和主機商都讀不到。這是唯一與「伺服器好壞」無關的硬保證。
- ✅ **中繼資料最小化（預設開）**：真實用戶端 IP 不入庫（`ip_source`）、**撤回即真刪**（不再預設保留 60 天原文）、關在線狀態、日誌等級低到不記 IP、收緊個人資料／房間目錄的曝露面。
- ✅ **抗鑑識工具**：`sudo tuwunel forget-secrets` 塗銷磁碟上的明文密碼／邀請碼；`sudo tuwunel autobackup` 備份採 AES-256 加密。

**誠實的邊界（務必對客戶如實說明，別過度承諾）：**

- ❌ **刪不掉的中繼資料**：房間成員關係、事件時間軸、帳號存在性、房間名稱／檔案名稱 —— 伺服器要運作就必須保留這些。端對端加密保護「內容」，**不保護中繼資料**（誰跟誰、何時、房間名、檔名）。
- ❌ **磁碟被實體取得／鏡像**：普通 VPS 上資料是明文落盤的，被鑑識可提取中繼資料。防這一層需選可信商家／管轄地，或進階的全碟加密／前置盾機（非自動，需技術投入）。
- ❌ **用 Cloudflare 藏伺服器 IP 基本無效**（憑證透明度日誌、灰色雲子網域會洩漏）。真要藏 IP 需自架 WireGuard 前置盾機。

> 給客戶的準確說法：**「聊天內容與附件端對端加密，營運方也無法讀取；伺服器會保留通訊中繼資料（誰在哪個房間、何時、檔名、房間名），這部分在伺服器被實體取得時可能被提取。」**

---

## 💾 備份（強烈建議）

資料庫與金鑰遺失就**無法還原**。本版無 PostgreSQL，備份就是打包 `data/tuwunel`（資料庫＋媒體）＋ `tuwunel.toml` ＋ `.env`。

**推薦:開啟自動加密備份**（每週自動、AES-256、自動輪替、磁碟將滿時自動略過）：

```bash
sudo tuwunel autobackup     # 依提示設目錄/保留數/頻率;開啟時會顯示金鑰,務必抄進密碼管理器
```

**或立即備份**（選單選 5，可設加密密語）。

**下載到本機**（在你自己電腦執行）：

```bash
scp root@你的主機IP:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **備份金鑰務必抄走**：沒有金鑰，加密備份永久打不開。金鑰只存在伺服器上，伺服器沒了又沒抄下 = 備份全廢。
> 💡 本機 `backups/` 會隨伺服器一起消失 —— 請定期把 `.enc` 複製到別處，或把備份目錄設成掛載的外接磁碟／物件儲存。

---

## ❓ 常見問題

| 問題 | 原因與解決 |
|---|---|
| **手機 Element X 連不上／「無法連線至此家伺服器」** | **先檢查手機日期時間是否正確**（設定→日期與時間→打開「自動」）—— 時間不對會導致憑證驗證失敗，這是最常見原因（尤其 Android）。其次：換個網路、確認能在手機瀏覽器打開 `https://你的網域/.well-known/matrix/client`、更新 Element X 到最新版。 |
| **Element X 說「需要升級以支援認證服務」** | 那是在說註冊。確認已開手機註冊（`sudo tuwunel enable-elementx`）且 tuwunel 是最新版（`docker compose pull tuwunel`）。或改用網頁註冊／管理員 `adduser` 建帳號，成員用 Element X **密碼登入**。 |
| **大檔案傳不上** | 檢查單檔上限（`MAX_UPLOAD=10G sudo -E tuwunel config`）；用 Cloudflare 的話 **`matrix` 主機必須灰色雲**（橙色雲 100MB 上限會卡死大檔案）。 |
| **網頁後台 admin.網域 打不開／登入報錯** | 多半是沒加 `admin` 的 DNS，或憑證還沒簽好；補記錄等幾分鐘。登入報錯先 `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`。 |
| 忘記 admin 密碼 | `cat /opt/tuwunel/CREDENTIALS.txt`；或 `sudo tuwunel adduser` 建個新管理員。 |
| 想改設定（通話、註冊方式、大檔案、後台） | 不用重裝：`sudo tuwunel config`，回車＝保持，資料帳號全不動。 |
| 通話接通但沒聲音沒畫面 | 99% 是 **7882/UDP** 沒放行，去商家安全群組補上。 |
| 磁碟快滿了 | 選單選 7「清理磁碟」；大檔案使用者請另備大容量磁碟或物件儲存。 |
| 加密房間舊訊息「無法解密」 | 正常：新裝置沒有歷史金鑰。在舊裝置上對新裝置做「驗證工作階段」即可。 |
| 想徹底解除安裝／重裝 | `sudo tuwunel uninstall`（雙重確認後才刪）；重裝 = 解除安裝後重跑安裝指令。 |

---

## 📦 伺服器端組件

裝好後執行以下組件，全部以 Docker 編排、開源可稽核：

```
Caddy(自動 HTTPS) + tuwunel(Rust,內建 RocksDB,免 PostgreSQL)
  + Element Web(自家網頁用戶端,可選)
  + Ketesa(圖形管理後台,可選)
  + LiveKit + lk-jwt-service(通話,可選)
```

安裝目錄 `/opt/tuwunel`，全部邏輯都在單一腳本 `matrix-tuwunel-installer.sh` 裡，可自行稽核。

---

## 🆚 tuwunel 版 vs Synapse 版

倉庫裡還有一個 Synapse 版（`matrix-installer.sh`）。簡單說：

- **tuwunel 版（本文）**：Rust、免 PostgreSQL、**更省資源、大檔案更強**、2GB 撐 300 人。適合大多數團隊、尤其重度傳大檔案的場景。
- **Synapse 版**：Python + PostgreSQL，生態最成熟、管理面板最老牌，但更吃記憶體、大檔案不如 tuwunel。

**新部署推薦 tuwunel 版。**

---

## 📄 授權（注意:禁止商用）

本專案採用 [PolyForm Noncommercial 1.0.0](LICENSE) 授權：

- ✅ **個人／團隊內部／學習研究／公益組織使用:免費**，可自由修改散布（保留版權聲明）
- ❌ **商業用途一律禁止**（賣錢、整合進商業產品、提供收費服務等）
- 🚫 **禁止在任何平台轉售、收費代裝／代部署** —— 本專案免費，看到有人賣就是未授權轉售
- 💼 想正規商用？在本倉庫開 [Issue](../../issues) 聯絡作者取得商業授權。

歡迎 Star ⭐

---

<div align="center">
用 ❤️ 打造 · 讓每個人都能擁有自己的私密通訊伺服器
</div>
