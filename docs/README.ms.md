<div align="center">

# Pelayan Komunikasi Matrix Persendirian · Pasang dengan Satu Arahan (edisi tuwunel)

**Pelayan anda, data anda — pemesej pasukan hos-sendiri, dibina untuk kerahsiaan dan kedaulatan data.**

Dikuasakan oleh enjin **tuwunel** (Rust, pangkalan data terbina, **tanpa PostgreSQL**): lebih ringan, lebih stabil, dan mampu **menghantar fail besar / foto / video panjang seperti Telegram**. RAM 2GB selesa untuk pasukan sederhana. Penyulitan hujung-ke-hujung, peminimuman metadata dan pendaftaran hanya melalui jemputan **dihidupkan secara lalai**. Satu arahan untuk memasang — anda tak perlu jadi pentadbir sistem; setiap pilihan disertakan penerangan mudah.

Klien disyorkan: **Element X**. Klien **VeilX** tersendiri sedang dibangunkan (lebih kemas, lebih mudah, lebih banyak ciri; sumber terbuka dan boleh diaudit; pasukan operasi di UK, Singapura dan Jepun). Fail pelanggan, kontrak, perbincangan dalaman, mesyuarat suara & video — semuanya hanya wujud pada pelayan anda sendiri. Dibina atas protokol terbuka [Matrix](https://matrix.org). Kod sumber terbuka dan boleh diaudit (percuma untuk kegunaan bukan komersial).

[English](../README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · [Español](README.es.md) · **Bahasa Melayu** · [فارسی](README.fa.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [粵語](README.zh-HK.md)

</div>

---

## ✨ Apa yang anda dapat selepas pasang

- 💬 Sembang teks dan bilik kumpulan (**penyulitan hujung-ke-hujung — pelayan dan penyedia hosting pun tak boleh baca kandungan mesej**)
- 📁 **Hantar fail besar / foto besar / video panjang** (had setiap fail **4GB** secara lalai, boleh ditetapkan lebih besar — ciri utama)
- 📞 Panggilan suara / video satu-lawan-satu dan berkumpulan (pilihan)
- 📱 Daftar sendiri dari telefon: pasang **Element X**, masukkan domain anda, daftar dan log masuk (tanpa perlu ke element.io)
- 🌐 Klien web domain sendiri: buka `https://domain-anda` dalam pelayar untuk daftar/log masuk, tanpa apl
- 🖥️ **Panel pentadbir web bergrafik** (Ketesa): urus pengguna, keluar/batal kod jemputan, semak bilik dan media
- 🔒 **Diperkuat privasi secara lalai**: IP sebenar klien tak disimpan, pemadaman kekal, kehadiran dimatikan, log tak merekod IP
- 👥 Hanya melalui jemputan: secara lalai hanya pemegang kod jemputan boleh daftar
- ⚡ **Jimat sumber**: satu proses Rust, tanpa PostgreSQL — RAM 2GB untuk ~300 orang

---

## 📋 Sebelum mula (3 perkara)

| Apa | Keperluan | Di mana |
|---|---|---|
| **Pelayan awan (VPS)** | Ubuntu 22.04 / 24.04 (atau Debian 11+), IP awam. **Pilih RAM ikut saiz pasukan** (lihat bawah). **Sediakan cakera mencukupi jika berkongsi fail besar.** | [Vultr](https://www.vultr.com), [DigitalOcean](https://www.digitalocean.com), [Hetzner](https://www.hetzner.com/cloud), [OVHcloud](https://www.ovhcloud.com) atau penyedia yang anda percaya |
| **Satu domain** | Apa-apa hujung (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) |
| **10 minit** | Semua salin-tampal; tak perlu memprogram | — |

> 💡 **Pilih RAM ikut pengguna aktif serentak** (federasi mati, sembang + fail): **1GB** ≈ beberapa puluh orang (matikan panggilan) · **2GB** ≈ 300 orang · **4GB / 2 vCPU** ≈ 500 orang. tuwunel ringan; CPU jarang jadi halangan.
> 💡 **Cakera ialah pembolehubah sebenar untuk fail besar.** Media disimpan pada cakera tempatan pelayan dan, kerana disulit hujung-ke-hujung, tak boleh dinyahduplikasi. Penggunaan berat boleh menambah ratusan GB hingga TB sebulan. Cakera sistem ≥ 50–100GB; pengguna berat perlu sediakan volum besar atau storan objek, dan perhati pilihan menu "Bersihkan cakera".
> 💡 **Bidang kuasa penting untuk privasi.** Pilih penyedia dan negara yang anda selesa — hos, pada prinsipnya, boleh dipaksa bekerjasama. Penyulitan E2E tetap melindungi *kandungan*, tetapi metadata kekal pada hos.
> 💡 Semasa memesan, sentiasa pilih imej **Ubuntu 22.04 / 24.04**. Jika RAM kurang 2.5GB, skrip tambah swap secara automatik.

---

## Langkah 0 — Sediakan OS (langkau jika sudah pesan betul)

Hanya **Ubuntu 22.04 / 24.04** (atau Debian 11+) disokong.

- **Pelayan baharu**: pilih **Ubuntu 22.04 x86_64** (atau 24.04) di ruang "OS / Image" semasa memesan.
- **OS salah**: guna "Pasang semula / Reinstall / Rebuild" penyedia untuk pasang Ubuntu 22.04. ⚠️ Ini **memadam semua data** — sandarkan pelayan sedia ada dahulu.
- Tak pasti apa yang berjalan? Selepas sambung (Langkah 3), jalankan `cat /etc/os-release`.
- Jika pasang atas OS salah, skrip akan kesan dan beritahu dengan jelas; tiada apa rosak.

---

## Langkah 1 — Tambah rekod DNS (~2 minit)

Dalam panel DNS **pendaftar domain** anda, tambah **rekod A**.

Andaikan domain `mychat.org`, IP pelayan `1.2.3.4`:

| Jenis | Hos (nama) | Nilai | Kegunaan |
|---|---|---|---|
| A | `@` (domain akar) | `1.2.3.4` | Domain akar + klien web + delegasi |
| A | `matrix` | `1.2.3.4` | Pelayan rumah |
| A | `admin` | `1.2.3.4` | Panel pentadbir web (langkau jika pentadbir mati) |
| A | `livekit` | `1.2.3.4` | Panggilan (langkau jika panggilan mati) |
| A | `matrix-rtc` | `1.2.3.4` | Panggilan (langkau jika panggilan mati) |

> 📌 Ruang hos hanya **awalan** (`matrix`), bukan domain penuh.
> 📌 Rekod merebak dalam 1–10 minit; pemasang menunggu sendiri jika belum aktif.
> 📌 Untuk sembang + fail sahaja (tanpa panggilan), hanya perlu `@` / `matrix` / `admin`.
> ⚠️ **Guna Cloudflare?** Rekod ini mesti **awan kelabu (DNS sahaja)**; **jangan hidupkan awan jingga (proksi)**. Proksi akan ① hadkan fail besar kepada 100MB (Free/Pro) ② halang pengeluaran sijil ③ sekat media panggilan. Pemasang tanya jika anda guna CDN (jawab ya untuk longgarkan semakan DNS), tetapi hos `matrix` mesti kekal awan kelabu.

---

## Langkah 2 — Buka port firewall (~1 minit)

Dalam "Security Group / Firewall" penyedia anda, benarkan:

| Port | Protokol | Kegunaan |
|---|---|---|
| 80 | TCP | Pengeluaran sijil HTTPS |
| 443 | TCP + UDP | Web dan trafik disulit |
| 7881 | TCP | Saluran sandaran panggilan (langkau tanpa panggilan) |
| **7882** | **UDP** | **Audio/video panggilan (paling mudah terlupa! Tiada = tiada bunyi & gambar)** |

> 📌 Jika penyedia tiada lapisan "security group", langkau — skrip konfigurasi firewall sistem secara automatik.

---

## Langkah 3 — Sambung ke pelayan (~1 minit)

Buka terminal (macOS: "Terminal"; Windows: "PowerShell"), jalankan berikut (tukar IP), dan masukkan kata laluan pelayan bila diminta (**adalah normal skrin tak papar sebarang aksara semasa menaip kata laluan**):

```bash
ssh root@IP_PELAYAN_ANDA
```

Pada sambungan pertama, jawab `yes` pada gesaan cap jari.

> 📌 Jika pengguna lalai bukan root (cth. `ubuntu`), guna `ssh ubuntu@IP`; skrip naikkan keistimewaan sendiri.

---

## Langkah 4 — Jalankan pemasang (~5–10 minit, automatik)

Selepas sambung, **salin keseluruhan baris** dan tampal ke terminal:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Ikut wizard. Ia tanya **6 pilihan + soalan CDN**; setiap satu ada penerangan di skrin, jadi jika ragu, tekan Enter (nilai lalai ialah gabungan paling selamat):

| Pilihan | Enter (disyorkan) | Nota |
|---|---|---|
| 1 Siapa boleh daftar | **Perlu kod jemputan** | Hanya pemegang kod masuk; pendaftar pertama jadi pentadbir. (Atau terbuka sepenuhnya — bukan untuk perniagaan.) |
| 2 Federasi | **Mati** | Mod pulau: orang luar tak boleh mesej ahli anda; permukaan serangan paling kecil. |
| 3 Panggilan suara/video | **Matikan dahulu** | Perlu dua rekod DNS tambahan (`livekit`/`matrix-rtc`) dan port 7881/7882; stabilkan sembang + fail dahulu. |
| 4 Klien web | **Hidup** | Ahli buka `https://domain-anda` untuk daftar/log masuk, tanpa apl. |
| 5 Panel pentadbir | **Hidup** | Panel bergrafik (Ketesa) di `admin.domain-anda`. |
| 6 Saiz fail maksimum | **4G** | Tetapkan apa saja (cth. 10G); makin besar makin banyak cakera. |
| ＋ Di belakang Cloudflare/CDN? | **Tidak** | Jawab ya hanya jika guna CDN (longgarkan semakan DNS); `matrix` mesti kekal awan kelabu. |

> 🔒 **Dihidupkan automatik (tak ditanya; aktif sebaik dipasang):** ① bilik baharu **dipaksa penyulitan E2E** ② **peminimuman metadata** (IP sebenar tak disimpan, pemadaman kekal, kehadiran mati, log tanpa IP) ③ **daftar sendiri Element X** (OIDC asli; pendaftaran masih perlu kod jemputan). Untuk matikan pengukuhan metadata: `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Pemasangan tanpa pengawasan penuh:** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Selepas itu semua automatik: semak DNS → pasang Docker → tala sistem → firewall → jana konfigurasi → mula servis → dapatkan sijil HTTPS → **cipta pentadbir automatik dan papar akaun/kata laluan**.

Kejayaan kelihatan begini:

```
========================================================
 🎉 tuwunel dipasang!  mychat.org
 (daftar[token] · federasi[off] · panggilan[off] · web[on] · pentadbir[on] · daftar-mudah-alih[on] · fail-besar[4G] · enjin tuwunel/Rust, tanpa Postgres)

 Daftar / log masuk ahli
   Web (disyorkan): buka https://mychat.org untuk daftar & log masuk
   Apl mudah alih: pasang Element X → pelayan "mychat.org" → daftar (kod) atau log masuk

 Pentadbir (dicipta automatik)
   akaun: admin    kata laluan: xxxxxxxxxxxx
   Panel web: https://admin.mychat.org  (log masuk dengan akaun pentadbir di atas)

 Pengurusan harian:  sudo tuwunel   (menu)    sudo tuwunel adduser   (tambah ahli)
========================================================
```

> 🔑 **Catat akaun/kata laluan pentadbir + kod jemputan!** Semua tersimpan pada pelayan di `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ "Belum sedia" di penghujung biasanya bermakna firewall awan tak benarkan 80/443, atau DNS belum merebak global. Caddy cuba semula sijil sendiri — tak perlu pasang semula.

---

## Langkah 5 — Log masuk dari telefon / komputer

| Peranti | Klien | Muat turun |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Pelayar (tanpa pasang) | Klien web **anda sendiri** | Buka `https://domain-anda` |

**Log masuk dengan pelayan = domain anda** (cth. `mychat.org`, **bukan** `matrix.mychat.org`); guna akaun/kata laluan yang dipapar di penghujung pemasangan.

> ⚠️ **Tak boleh sambung / Element X kata "couldn't connect to this homeserver"? Perkara pertama: semak sama ada tarikh & masa telefon betul!**
> Jam salah → pengesahan sijil HTTPS gagal → langsung tak boleh sambung (sangat lazim, terutama Android).
> Penyelesaian: pada telefon **Tetapan → Tarikh & masa → hidupkan "Automatik"**, kemudian cuba semula.

---

## 👥 Cara ahli menyertai (pilih satu)

1. **Pentadbir cipta akaun (paling terkawal):** `sudo tuwunel adduser` cipta pengguna dan tetapkan kata laluan dalam satu arahan; beri mereka "domain + nama pengguna + kata laluan". Kod jemputan tak keluar dari tangan anda.
2. **Edar kod jemputan, daftar sendiri web:** hantar kod (dalam `CREDENTIALS.txt`) + `https://domain-anda`; ahli daftar sendiri dalam pelayar.
3. **Edar kod, daftar sendiri Element X:** pasang Element X → masukkan domain → cipta akaun → masukkan kod jemputan.

---

## 🖥️ Panel pentadbir bergrafik (Ketesa, disyorkan)

Jika dihidupkan (pilihan 5), pemasang gerakkan sebuah **panel pentadbir web bergrafik** — urus semua dengan tetikus, tanpa arahan.

**Cara masuk:** layari `https://admin.domain-anda` → **log masuk terus dengan akaun pentadbir `admin` + kata laluan** (tiada kata laluan pintu berasingan; panel dikunci kepada pelayan anda).

**Apa boleh dibuat:** urus pengguna (cipta/nyahaktif/set semula kata laluan), **keluar dan batal kod jemputan**, semak bilik/media, direktori bilik, tugas berjadual.

> 📌 Halaman "Laporan / Pengguna dilaporkan" mungkin ralat atau kosong — tuwunel tak laksanakan ciri itu; ini **normal** dan jarang diperlukan.
> 📌 Panel perlukan tuwunel v1.8.1+ (imej `:latest` sudah ada). Jika log masuk panel ralat: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Tambah panel pada pelayan sedia ada: `sudo tuwunel enable-admin` (tambah rekod DNS `admin` dahulu).

---

## 🔧 Pengurusan harian: menu

Selepas pasang, **jalankan `sudo tuwunel` untuk buka menu pengurusan** (tiada arahan untuk dihafal):

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  menu pengurusan tuwunel   domain-anda        │
└──────────────────────────────────────────────┘
  1) Status                    6) Naik taraf imej servis
  2) Tambah ahli               7) Bersihkan cakera
  3) Ubah konfigurasi          8) Mula semula servis
  4) Hidup/mati panel web      9) Kemas kini skrip + ciri baharu
  5) Sandar sekarang          10) Nyahpasang sepenuhnya
  p) Pengukuhan privasi / pembersihan metadata
  s) Redaksi fail kelayakan teks biasa (anti-forensik)
  b) Sandaran disulit automatik berjadual
  0) Keluar
```

Atau guna arahan terus:

```bash
sudo tuwunel adduser          # tambah ahli
sudo tuwunel config           # ubah konfigurasi (Enter = kekal; data/akaun tak diusik)
sudo tuwunel update           # tarik skrip terkini dari GitHub & guna ciri baharu (data tak diusik)
sudo tuwunel enable-admin     # tambah panel pentadbir web pada pelayan sedia ada
sudo tuwunel enable-elementx  # hidupkan daftar sendiri Element X
sudo tuwunel autobackup       # hidupkan sandaran disulit automatik mingguan
sudo tuwunel privacy          # privasi/metadata: lihat apa boleh dibuang, bersihkan log
sudo tuwunel forget-secrets   # anti-forensik: redaksi kata laluan/kod jemputan teks biasa pada cakera
sudo tuwunel uninstall        # nyahpasang
```

> 🔄 **Konfigur semula tanpa pasang semula** (menu 3): tanya semula pilihan, **Enter = kekal nilai semasa**, kemudian mula semula. Akaun, sejarah dan kunci semuanya terpelihara.

---

## 🔒 Privasi / anti-forensik (fokus edisi ini)

Sistem ini dibina untuk melindungi komunikasi sulit dan **secara lalai meminimumkan jejak yang tinggal pada pelayan**:

- ✅ **Kandungan mesej disulit hujung-ke-hujung** — anda (operator) mahupun penyedia hosting tak boleh membacanya. Ini satu-satunya jaminan yang kekal tanpa mengira baik-buruk pelayan.
- ✅ **Peminimuman metadata (lalai hidup):** IP sebenar klien tak disimpan (`ip_source`), **pemadaman benar-benar kekal** (asal tak disimpan 60 hari), kehadiran mati, tahap log terlalu rendah untuk rekod IP, pendedahan profil/direktori bilik diperketat.
- ✅ **Alat anti-forensik:** `sudo tuwunel forget-secrets` redaksi kata laluan/kod jemputan teks biasa pada cakera; `sudo tuwunel autobackup` sulitkan sandaran dengan AES-256.

**Had jujur (beritahu pelanggan; jangan janji berlebihan):**

- ❌ **Metadata yang tak boleh dibuang:** keahlian bilik, garis masa peristiwa, kewujudan akaun, nama bilik / nama fail — pelayan mesti simpan untuk berfungsi. E2E lindungi *kandungan*, **bukan metadata** (siapa dengan siapa, bila, nama bilik, nama fail).
- ❌ **Jika cakera dirampas / diklon secara fizikal:** pada VPS biasa data ditulis teks biasa pada cakera dan metadata boleh diekstrak secara forensik. Pertahanan lapisan ini perlukan penyedia/bidang kuasa dipercayai, atau penyulitan cakera penuh lanjutan / proksi "perisai" di hadapan (bukan automatik; perlu kerja kejuruteraan).
- ❌ **Menyembunyikan IP pelayan melalui Cloudflare hampir tak berkesan** (log ketelusan sijil dan subdomain awan kelabu mendedahkannya). Untuk benar-benar sembunyikan IP, perlukan proksi WireGuard hos-sendiri di hadapan.

> Ayat tepat untuk pelanggan: **"Kandungan mesej dan lampiran disulit hujung-ke-hujung; operator tak boleh membacanya. Namun pelayan menyimpan metadata komunikasi (siapa dalam bilik mana, bila, nama fail, nama bilik), yang boleh diekstrak jika pelayan dirampas secara fizikal."**

---

## 💾 Sandaran (amat disyorkan)

Kehilangan pangkalan data atau kunci bermakna **tiada pemulihan**. Edisi ini tiada PostgreSQL: sandaran hanyalah arkib `data/tuwunel` (pangkalan data + media) + `tuwunel.toml` + `.env`.

**Disyorkan: hidupkan sandaran disulit automatik** (mingguan, AES-256, giliran automatik, dilangkau jika cakera hampir penuh):

```bash
sudo tuwunel autobackup     # tetapkan folder / bilangan simpanan / kekerapan; kunci akan dipapar — simpan dalam pengurus kata laluan
```

**Atau sandar sekarang** (menu 5; boleh tetapkan frasa laluan penyulitan).

**Muat turun ke komputer** (jalankan pada mesin anda sendiri):

```bash
scp root@IP_PELAYAN_ANDA:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Simpan kunci sandaran.** Tanpanya, sandaran disulit tak akan boleh dibuka selamanya. Kunci hanya ada pada pelayan: jika pelayan hilang dan anda tak simpan kunci, sandaran tak berguna.
> 💡 Folder tempatan `backups/` mati bersama pelayan. Salin fail `.enc` ke tempat lain secara berkala, atau tuju folder sandaran ke volum luar terpasang / storan objek.

---

## ❓ Soalan lazim

| Masalah | Punca & penyelesaian |
|---|---|
| **Element X telefon tak sambung / "couldn't connect to this homeserver"** | **Mula-mula, semak tarikh & masa telefon** (Tetapan → Tarikh & masa → "Automatik"): jam salah gagalkan pengesahan sijil; punca paling lazim (terutama Android). Kemudian: cuba rangkaian lain, pastikan `https://domain-anda/.well-known/matrix/client` boleh dibuka dalam pelayar telefon, dan kemas kini Element X. |
| **Element X kata "perlu naik taraf untuk sokong perkhidmatan pengesahan"** | Ini berkenaan pendaftaran. Pastikan pendaftaran mudah alih hidup (`sudo tuwunel enable-elementx`) dan tuwunel terkini (`docker compose pull tuwunel`). Atau daftar melalui web / `adduser` dan biar ahli **log masuk dengan kata laluan** dalam Element X. |
| **Fail besar tak boleh dimuat naik** | Semak had saiz (`MAX_UPLOAD=10G sudo -E tuwunel config`); jika guna Cloudflare, hos **`matrix` mesti awan kelabu** (had 100MB awan jingga membunuh fail besar). |
| **Panel admin.domain tak buka / ralat log masuk** | Biasanya rekod DNS `admin` tiada atau sijil belum sedia — tambah rekod dan tunggu beberapa minit. Untuk ralat log masuk: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Lupa kata laluan pentadbir | `cat /opt/tuwunel/CREDENTIALS.txt`; atau `sudo tuwunel adduser` untuk cipta pentadbir baharu. |
| Ubah konfigurasi (panggilan, pendaftaran, saiz fail, pentadbir) | Tanpa pasang semula: `sudo tuwunel config` — Enter kekalkan nilai, data/akaun tak diusik. |
| Panggilan sambung tapi tiada bunyi/gambar | 99% kes port **7882/UDP** tak dibenarkan — tambah dalam firewall penyedia. |
| Cakera penuh | Menu 7 "Bersihkan cakera"; pengguna berat sediakan volum besar atau storan objek. |
| "Tak boleh nyahsulit" mesej lama dalam bilik disulit | Normal: peranti baharu tiada kunci sejarah. Sahkan sesi baharu dari peranti lama. |
| Nyahpasang / pasang semula | `sudo tuwunel uninstall` (pengesahan dua kali sebelum padam); pasang semula = nyahpasang dan jalankan semula arahan pemasangan. |

---

## 📦 Komponen sebelah pelayan

Selepas pasang, komponen ini berjalan, semua diorkestra dengan Docker, sumber terbuka dan boleh diaudit:

```
Caddy (HTTPS automatik) + tuwunel (Rust, RocksDB terbina, tanpa PostgreSQL)
  + Element Web (klien web anda sendiri, pilihan)
  + Ketesa (panel pentadbir bergrafik, pilihan)
  + LiveKit + lk-jwt-service (panggilan, pilihan)
```

Direktori pemasangan `/opt/tuwunel`. Semua logik ada dalam satu skrip `matrix-tuwunel-installer.sh`, yang boleh anda audit sendiri.

---

## 🆚 Edisi tuwunel vs Synapse

Repositori turut menyertakan edisi Synapse (`matrix-installer.sh`). Ringkasnya:

- **Edisi tuwunel (dokumen ini):** Rust, tanpa PostgreSQL, **lebih cekap, lebih kuat untuk fail besar**, 2GB untuk ~300 orang. Sesuai untuk kebanyakan pasukan, terutama penggunaan fail besar yang berat.
- **Edisi Synapse:** Python + PostgreSQL, ekosistem dan alat pentadbiran paling matang, tetapi lebih berat pada RAM dan lebih lemah untuk fail besar.

**Untuk pemasangan baharu, edisi tuwunel disyorkan.**

---

## 📄 Lesen (nota: bukan komersial sahaja)

Projek ini dilesenkan di bawah [PolyForm Noncommercial 1.0.0](LICENSE):

- ✅ **Percuma untuk kegunaan peribadi / dalaman pasukan / penyelidikan / organisasi bukan untung** — ubah suai dan edar bebas (kekalkan notis hak cipta)
- ❌ **Segala penggunaan komersial dilarang** (menjual, menyepadukan ke produk komersial, menawarkannya sebagai perkhidmatan berbayar, dll.)
- 🚫 **Menjual semula di mana-mana pasaran, dan perkhidmatan "pemasangan/pengedaran" berbayar, dilarang** — projek ini percuma; jika anda nampak seseorang menjualnya, itu jualan semula tanpa izin
- 💼 Mahu lesen komersial rasmi? Buka [Issue](../../issues) untuk hubungi pengarang.

Beri Star ⭐ jika berguna.

---

<div align="center">
Dibina dengan ❤️ · supaya semua orang boleh miliki pelayan komunikasi peribadi sendiri
</div>
