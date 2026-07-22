<div align="center">

# Privater Matrix-Kommunikationsserver · Bereitstellung mit einem Befehl (tuwunel-Edition)

**Ihr Server, Ihre Daten — ein selbstgehosteter Team-Messenger, gebaut für Vertraulichkeit und Datensouveränität.**

Angetrieben von der **tuwunel**-Engine (in Rust, integrierte Datenbank, **kein PostgreSQL**): leichter, stabiler und in der Lage, **große Dateien / Fotos / lange Videos wie Telegram zu versenden**. 2 GB RAM betreiben bequem ein mittelgroßes Team. Ende-zu-Ende-Verschlüsselung, Metadaten-Minimierung und Registrierung nur per Einladung sind **standardmäßig aktiviert**. Bereitstellung mit einem einzigen Befehl — Sie müssen kein Systemadministrator sein; jede Option ist verständlich erklärt.

Empfohlener Client: **Element X**. Ein eigener **VeilX**-Client ist in Entwicklung (schlanker, einfacher, mehr Funktionen; quelloffen und prüfbar; Betriebsteam im Vereinigten Königreich, in Singapur und Japan). Kundendaten, Verträge, interne Diskussionen, Sprach- und Videokonferenzen — all das existiert nur auf Ihrem eigenen Server. Basierend auf dem offenen Protokoll [Matrix](https://matrix.org). Quellcode öffentlich und prüfbar (kostenlos für nicht-kommerzielle Nutzung).

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [粵語](README.zh-HK.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · **Deutsch** · [Italiano](README.it.md) · [Español](README.es.md) · [Bahasa Melayu](README.ms.md) · [فارسی](README.fa.md)

</div>

---

## ✨ Was Sie nach der Installation erhalten

- 💬 Textchats und Gruppenräume (**Ende-zu-Ende-verschlüsselt — weder der Server noch der Hoster können den Nachrichteninhalt lesen**)
- 📁 **Große Dateien / große Fotos / lange Videos senden** (Standardlimit pro Datei **4 GB**, höher konfigurierbar — die Kernfunktion)
- 📞 Einzel- und Gruppen-Sprach-/Videoanrufe (optional)
- 📱 Registrierung vom Smartphone: **Element X** installieren, Ihre Domain eingeben, registrieren und anmelden (ohne Umweg über element.io)
- 🌐 Eigener Web-Client: `https://ihre-domain` im Browser öffnen zum Registrieren/Anmelden, ohne App
- 🖥️ **Grafisches Web-Admin-Panel** (Ketesa): Benutzer verwalten, Einladungscodes ausstellen/widerrufen, Räume und Medien einsehen
- 🔒 **Standardmäßig datenschutzgehärtet**: echte Client-IP wird nie gespeichert, Löschungen sind endgültig, Anwesenheit deaktiviert, Logs speichern keine IPs
- 👥 Nur per Einladung: standardmäßig kann sich nur registrieren, wer einen Einladungscode hat
- ⚡ **Ressourcenschonend**: ein einziger Rust-Prozess, kein PostgreSQL — 2 GB RAM für ~300 Personen

---

## 📋 Vor dem Start (3 Dinge)

| Was | Anforderung | Wo |
|---|---|---|
| **Ein Cloud-Server (VPS)** | Ubuntu 22.04 / 24.04 (oder Debian 11+), eine öffentliche IP. **RAM nach Teamgröße wählen** (siehe unten). **Genug Speicherplatz vorsehen, wenn Sie große Dateien teilen.** | [Hetzner](https://www.hetzner.com/cloud), [netcup](https://www.netcup.com), [OVHcloud](https://www.ovhcloud.com), [Contabo](https://contabo.com) oder ein Anbieter Ihres Vertrauens |
| **Eine Domain** | Beliebige Endung (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [INWX](https://www.inwx.de) |
| **10 Minuten** | Alles per Copy-and-paste; kein Programmieren | — |

> 💡 **RAM nach gleichzeitig aktiven Nutzern wählen** (Föderation aus, Chat + Dateien): **1 GB** ≈ einige Dutzend Personen (Anrufe deaktivieren) · **2 GB** ≈ 300 Personen · **4 GB / 2 vCPU** ≈ 500 Personen. tuwunel ist leichtgewichtig; die CPU ist selten der Engpass.
> 💡 **Der Speicherplatz ist die eigentliche Variable bei großen Dateien.** Medien liegen auf der lokalen Festplatte des Servers und lassen sich wegen der Ende-zu-Ende-Verschlüsselung nicht deduplizieren. Intensive Nutzung kann monatlich Hunderte GB bis TB hinzufügen. Systemplatte ≥ 50–100 GB; bei intensiver Nutzung ein großes Volume oder Objektspeicher vorsehen und den Menüpunkt „Speicher bereinigen“ im Blick behalten.
> 💡 **Für den Datenschutz zählt die Rechtsprechung.** Wählen Sie Anbieter und Land, mit denen Sie sich wohlfühlen — der Host kann prinzipiell zur Kooperation gezwungen werden. E2E-Verschlüsselung schützt in jedem Fall den *Inhalt*, aber Metadaten verbleiben beim Host.
> 💡 Bei der Bestellung stets ein **Ubuntu 22.04 / 24.04**-Image wählen. Bei weniger als 2,5 GB RAM fügt das Skript automatisch Swap hinzu.

---

## Schritt 0 — Betriebssystem vorbereiten (überspringen, wenn richtig bestellt)

Unterstützt wird nur **Ubuntu 22.04 / 24.04** (oder Debian 11+).

- **Neuer Server**: bei der Bestellung im Feld „OS / Image“ **Ubuntu 22.04 x86_64** (oder 24.04) wählen.
- **Falsches OS**: über „Neu installieren / Reinstall / Rebuild“ des Anbieters Ubuntu 22.04 installieren. ⚠️ Das **löscht alle Daten** — vorhandenen Server zuerst sichern.
- Unklar, was läuft? Nach dem Verbinden (Schritt 3) `cat /etc/os-release` ausführen.
- Auf dem falschen OS installiert? Das Skript erkennt es und meldet es klar; nichts geht kaputt.

---

## Schritt 1 — DNS-Einträge hinzufügen (~2 Minuten)

Im DNS-Panel Ihres **Domain-Registrars** **A-Einträge** hinzufügen.

Angenommen die Domain ist `mychat.org` und die Server-IP `1.2.3.4`:

| Typ | Host (Name) | Wert | Zweck |
|---|---|---|---|
| A | `@` (Root-Domain) | `1.2.3.4` | Root-Domain + Web-Client + Delegation |
| A | `matrix` | `1.2.3.4` | Der Heimserver |
| A | `admin` | `1.2.3.4` | Web-Admin-Panel (weglassen, wenn Admin aus) |
| A | `livekit` | `1.2.3.4` | Anrufe (weglassen ohne Anrufe) |
| A | `matrix-rtc` | `1.2.3.4` | Anrufe (weglassen ohne Anrufe) |

> 📌 Das Host-Feld nimmt nur das **Präfix** (`matrix`), nicht die vollständige Domain.
> 📌 Einträge verbreiten sich in 1–10 Minuten; der Installer wartet selbst, falls sie noch nicht aktiv sind.
> 📌 Für nur Chat + Dateien (ohne Anrufe) genügen `@` / `matrix` / `admin`.
> ⚠️ **Nutzen Sie Cloudflare?** Diese Einträge müssen **grau (nur DNS)** sein; **aktivieren Sie nicht die orange Wolke (Proxy)**. Der Proxy ① begrenzt große Dateien auf 100 MB (Free/Pro) ② verhindert die Zertifikatsausstellung ③ blockiert die Anruf-Medien. Der Installer fragt, ob Sie ein CDN nutzen (mit Ja wird die DNS-Prüfung gelockert), aber der Host `matrix` muss grau bleiben.

---

## Schritt 2 — Firewall-Ports öffnen (~1 Minute)

In der „Security Group / Firewall“ Ihres Anbieters freigeben:

| Port | Protokoll | Zweck |
|---|---|---|
| 80 | TCP | HTTPS-Zertifikatsausstellung |
| 443 | TCP + UDP | Web und verschlüsselter Verkehr |
| 7881 | TCP | Ausweichkanal für Anrufe (weglassen ohne Anrufe) |
| **7882** | **UDP** | **Audio/Video von Anrufen (am leichtesten vergessen! Fehlt es = kein Ton, kein Bild)** |

> 📌 Kein „Security Group“-Layer beim Anbieter? Überspringen — das Skript konfiguriert die System-Firewall automatisch.

---

## Schritt 3 — Mit dem Server verbinden (~1 Minute)

Ein Terminal öffnen (macOS: „Terminal“; Windows: „PowerShell“), Folgendes ausführen (IP ersetzen) und bei Aufforderung das Server-Passwort eingeben (**dass beim Tippen des Passworts nichts angezeigt wird, ist normal**):

```bash
ssh root@IHRE_SERVER_IP
```

Bei der ersten Verbindung die Fingerabdruck-Abfrage mit `yes` beantworten.

> 📌 Ist der Standardnutzer nicht root (z. B. `ubuntu`), `ssh ubuntu@IP` verwenden; das Skript erhöht die Rechte selbst.

---

## Schritt 4 — Installer ausführen (~5–10 Minuten, automatisch)

Nach dem Verbinden **die gesamte Zeile kopieren** und ins Terminal einfügen:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Dem Assistenten folgen. Er stellt **6 Optionen + eine CDN-Frage**; jede ist am Bildschirm erklärt, im Zweifel also Enter drücken (die Standardwerte sind die sicherste Kombination):

| Option | Enter (empfohlen) | Hinweise |
|---|---|---|
| 1 Wer darf sich registrieren | **Einladungscode erforderlich** | Nur wer den Code hat, kommt rein; der erste Registrierte wird Admin. (Oder ganz offen — nicht für den geschäftlichen Einsatz.) |
| 2 Föderation | **Aus** | Insel-Modus: von außen kann niemand Ihren Mitgliedern schreiben; minimale Angriffsfläche. |
| 3 Sprach-/Videoanrufe | **Zuerst aus** | Benötigt zwei zusätzliche DNS-Einträge (`livekit`/`matrix-rtc`) und die Ports 7881/7882; zuerst Chat + Dateien stabilisieren. |
| 4 Web-Client | **An** | Mitglieder öffnen `https://ihre-domain` zum Registrieren/Anmelden, ohne App. |
| 5 Admin-Panel | **An** | Ein grafisches Panel (Ketesa) unter `admin.ihre-domain`. |
| 6 Maximale Dateigröße | **4 GB** | Beliebig setzbar (z. B. 10 GB); größer bedeutet mehr Speicher. |
| ＋ Hinter Cloudflare/CDN? | **Nein** | Ja nur, wenn Sie ein CDN nutzen (lockert die DNS-Prüfung); `matrix` bleibt grau. |

> 🔒 **Automatisch aktiviert (nicht abgefragt; sofort nach der Installation wirksam):** ① neue Räume werden **zur E2E-Verschlüsselung gezwungen** ② **Metadaten-Minimierung** (echte IP nicht gespeichert, Löschungen endgültig, Anwesenheit aus, Logging ohne IP) ③ **Selbstregistrierung über Element X** (natives OIDC; die Registrierung erfordert weiterhin einen Einladungscode). Metadaten-Härtung deaktivieren: `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Vollständig unbeaufsichtigt:** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Danach läuft alles automatisch: DNS prüfen → Docker installieren → System optimieren → Firewall → Konfiguration erzeugen → Dienste starten → HTTPS-Zertifikat holen → **Admin automatisch anlegen und Konto/Passwort ausgeben**.

Erfolg sieht so aus:

```
========================================================
 🎉 tuwunel bereitgestellt!  mychat.org
 (Registrierung[token] · Föderation[off] · Anrufe[off] · Web[on] · Admin[on] · Mobil-Registrierung[on] · Große-Dateien[4G] · Engine tuwunel/Rust, ohne Postgres)

 Registrierung / Anmeldung der Mitglieder
   Web (empfohlen): https://mychat.org öffnen zum Registrieren und Anmelden
   Mobil-App: Element X installieren → Server "mychat.org" → Registrieren (Code) oder Anmelden

 Admin (automatisch angelegt)
   Konto: admin    Passwort: xxxxxxxxxxxx
   Web-Panel: https://admin.mychat.org  (mit dem Admin-Konto oben anmelden)

 Tägliche Verwaltung:  sudo tuwunel   (Menü)    sudo tuwunel adduser   (Mitglied hinzufügen)
========================================================
```

> 🔑 **Admin-Konto/Passwort und Einladungscode notieren!** Alles liegt auf dem Server in `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ „Noch nicht bereit“ am Ende bedeutet meist, dass die Cloud-Firewall 80/443 nicht freigibt oder das DNS noch nicht global verbreitet ist. Caddy wiederholt die Zertifikatsausstellung selbst — keine Neuinstallation nötig.

---

## Schritt 5 — Vom Smartphone / Computer anmelden

| Gerät | Client | Download |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Browser (ohne Installation) | Ihr **eigener Web-Client** | `https://ihre-domain` öffnen |

**Melden Sie sich mit dem Server = Ihre Domain an** (z. B. `mychat.org`, **nicht** `matrix.mychat.org`); verwenden Sie das am Ende der Installation angezeigte Konto/Passwort.

> ⚠️ **Keine Verbindung / Element X sagt „couldn't connect to this homeserver“? Zuerst: Prüfen Sie, ob Datum und Uhrzeit des Telefons stimmen!**
> Eine falsche Uhr → die HTTPS-Zertifikatsprüfung schlägt fehl → keine Verbindung möglich (sehr häufig, besonders bei Android).
> Lösung: am Telefon **Einstellungen → Datum und Uhrzeit → „Automatisch“ aktivieren**, dann erneut versuchen.

---

## 👥 Wie Mitglieder beitreten (eine Option wählen)

1. **Admin legt das Konto an (am kontrolliertesten):** `sudo tuwunel adduser` erstellt einen Nutzer und setzt das Passwort in einem Befehl; geben Sie „Domain + Benutzername + Passwort“ weiter. Der Einladungscode verlässt Ihre Hände nicht.
2. **Einladungscode verteilen, Selbstregistrierung per Web:** Code (in `CREDENTIALS.txt`) + `https://ihre-domain` senden; Mitglieder registrieren sich selbst im Browser.
3. **Einladungscode verteilen, Selbstregistrierung über Element X:** Element X installieren → Domain eingeben → Konto erstellen → Einladungscode eingeben.

---

## 🖥️ Grafisches Admin-Panel (Ketesa, empfohlen)

Falls aktiviert (Option 5), stellt der Installer ein **grafisches Web-Admin-Panel** bereit — alles per Maus, ohne Befehle.

**Zugang:** `https://admin.ihre-domain` öffnen → **direkt mit dem Admin-Konto `admin` + Passwort anmelden** (kein separates Gate-Passwort; das Panel ist an Ihren Server gebunden).

**Möglichkeiten:** Nutzer verwalten (anlegen/deaktivieren/Passwort zurücksetzen), **Einladungscodes ausstellen und widerrufen**, Räume/Medien einsehen, Raumverzeichnis, geplante Aufgaben.

> 📌 Die Seiten „Meldungen / Gemeldete Nutzer“ können Fehler zeigen oder leer sein — tuwunel implementiert diese Funktion nicht; das ist **normal** und wird kaum je benötigt.
> 📌 Das Panel benötigt tuwunel v1.8.1+ (das `:latest`-Image enthält es). Bei Login-Fehlern im Panel: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Panel zu einem bestehenden Server hinzufügen: `sudo tuwunel enable-admin` (zuerst den DNS-Eintrag `admin` anlegen).

---

## 🔧 Tägliche Verwaltung: das Menü

Nach der Installation **öffnet `sudo tuwunel` das Verwaltungsmenü** (keine Befehle zu merken):

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  tuwunel-Verwaltungsmenü   ihre-domain        │
└──────────────────────────────────────────────┘
  1) Status                    6) Dienst-Images aktualisieren
  2) Mitglied hinzufügen       7) Speicher bereinigen
  3) Konfiguration ändern      8) Alle Dienste neu starten
  4) Web-Admin an/aus          9) Skript aktualisieren + neue Funktionen
  5) Jetzt sichern            10) Vollständig deinstallieren
  p) Datenschutz-Härtung / Metadaten-Bereinigung
  s) Klartext-Anmeldedatendatei schwärzen (Anti-Forensik)
  b) Automatische geplante verschlüsselte Sicherung
  0) Beenden
```

Oder Befehle direkt nutzen:

```bash
sudo tuwunel adduser          # Mitglied hinzufügen
sudo tuwunel config           # Konfiguration ändern (Enter = beibehalten; Daten/Konten unangetastet)
sudo tuwunel update           # neuestes Skript von GitHub holen und neue Funktionen anwenden (Daten unangetastet)
sudo tuwunel enable-admin     # Web-Admin-Panel zu bestehendem Server hinzufügen
sudo tuwunel enable-elementx  # Selbstregistrierung über Element X aktivieren
sudo tuwunel autobackup       # wöchentliche automatische verschlüsselte Sicherungen aktivieren
sudo tuwunel privacy          # Datenschutz/Metadaten: sehen, was entfernt werden kann, Logs bereinigen
sudo tuwunel forget-secrets   # Anti-Forensik: Klartext-Passwort/Einladungscode auf der Platte schwärzen
sudo tuwunel uninstall        # deinstallieren
```

> 🔄 **Neu konfigurieren ohne Neuinstallation** (Menü 3): fragt die Optionen erneut ab, **Enter = aktuellen Wert beibehalten**, dann Neustart. Konten, Verlauf und Schlüssel bleiben alle erhalten.

---

## 🔒 Datenschutz / Anti-Forensik (der Schwerpunkt dieser Edition)

Dieses System ist auf den Schutz vertraulicher Kommunikation ausgelegt und **minimiert standardmäßig die auf dem Server verbleibenden Spuren**:

- ✅ **Nachrichteninhalte sind Ende-zu-Ende-verschlüsselt** — weder Sie (der Betreiber) noch der Hoster können sie lesen. Das ist die einzige Garantie, die unabhängig von der Qualität des Servers gilt.
- ✅ **Metadaten-Minimierung (standardmäßig an):** echte Client-IP nie gespeichert (`ip_source`), **Löschungen wirklich endgültig** (Original nicht 60 Tage aufbewahrt), Anwesenheit aus, Log-Level zu niedrig, um IPs zu erfassen, Sichtbarkeit von Profilen/Raumverzeichnis eingeschränkt.
- ✅ **Anti-Forensik-Werkzeuge:** `sudo tuwunel forget-secrets` schwärzt Klartext-Passwort/Einladungscode auf der Platte; `sudo tuwunel autobackup` verschlüsselt Sicherungen mit AES-256.

**Die ehrlichen Grenzen (sagen Sie sie Ihren Kunden; versprechen Sie nicht zu viel):**

- ❌ **Nicht entfernbare Metadaten:** Raum-Mitgliedschaften, Ereignis-Zeitleiste, Existenz des Kontos, Raum- / Dateinamen — der Server muss sie zum Funktionieren aufbewahren. E2E schützt den *Inhalt*, **nicht die Metadaten** (wer mit wem, wann, Raumnamen, Dateinamen).
- ❌ **Wird die Platte physisch beschlagnahmt / geklont:** auf einem gewöhnlichen VPS werden Daten im Klartext auf die Platte geschrieben, und Metadaten lassen sich forensisch extrahieren. Diese Ebene erfordert einen vertrauenswürdigen Anbieter/eine vertrauenswürdige Rechtsprechung oder fortgeschrittene Vollverschlüsselung der Platte / einen vorgeschalteten „Schild“-Proxy (nicht automatisch; erfordert Engineering-Aufwand).
- ❌ **Die Server-IP über Cloudflare zu verstecken funktioniert praktisch nicht** (Certificate-Transparency-Logs und grau geschaltete Subdomains verraten sie). Die IP wirklich zu verbergen erfordert einen selbstgehosteten vorgeschalteten WireGuard-Proxy.

> Präzise Formulierung für Kunden: **„Nachrichteninhalte und Anhänge sind Ende-zu-Ende-verschlüsselt; der Betreiber kann sie nicht lesen. Der Server bewahrt jedoch Kommunikations-Metadaten auf (wer in welchem Raum, wann, Dateinamen, Raumnamen), die bei physischer Beschlagnahme des Servers extrahiert werden könnten.“**

---

## 💾 Sicherungen (dringend empfohlen)

Gehen Datenbank oder Schlüssel verloren, gibt es **keine Wiederherstellung**. Diese Edition hat kein PostgreSQL: eine Sicherung ist einfach ein Archiv von `data/tuwunel` (Datenbank + Medien) + `tuwunel.toml` + `.env`.

**Empfohlen: automatische verschlüsselte Sicherungen aktivieren** (wöchentlich, AES-256, mit Rotation, bei fast vollem Speicher automatisch übersprungen):

```bash
sudo tuwunel autobackup     # Ordner / Aufbewahrung / Häufigkeit festlegen; der Schlüssel wird angezeigt — im Passwort-Manager speichern
```

**Oder jetzt sichern** (Menü 5; eine Verschlüsselungs-Passphrase kann gesetzt werden).

**Auf den Computer herunterladen** (auf dem eigenen Rechner ausführen):

```bash
scp root@IHRE_SERVER_IP:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Sichern Sie den Backup-Schlüssel.** Ohne ihn lässt sich eine verschlüsselte Sicherung nie öffnen. Der Schlüssel existiert nur auf dem Server: ist der Server weg und der Schlüssel nicht notiert, sind die Sicherungen wertlos.
> 💡 Der lokale Ordner `backups/` verschwindet mit dem Server. Kopieren Sie die `.enc`-Dateien regelmäßig woandershin oder verweisen Sie den Backup-Ordner auf ein eingebundenes externes Volume / Objektspeicher.

---

## ❓ Häufige Fragen

| Problem | Ursache & Lösung |
|---|---|
| **Element X am Telefon verbindet nicht / „couldn't connect to this homeserver“** | **Zuerst Datum und Uhrzeit des Telefons prüfen** (Einstellungen → Datum und Uhrzeit → „Automatisch“): eine falsche Uhr lässt die Zertifikatsprüfung scheitern; häufigste Ursache (besonders Android). Dann: anderes Netz probieren, prüfen, ob `https://ihre-domain/.well-known/matrix/client` im Telefon-Browser lädt, und Element X aktualisieren. |
| **Element X sagt „muss aktualisiert werden, um den Authentifizierungsdienst zu unterstützen“** | Das betrifft die Registrierung. Prüfen, ob die Mobil-Registrierung aktiv ist (`sudo tuwunel enable-elementx`) und tuwunel aktuell ist (`docker compose pull tuwunel`). Oder per Web / `adduser` registrieren und Mitglieder in Element X **per Passwort anmelden** lassen. |
| **Große Dateien werden nicht hochgeladen** | Größenlimit prüfen (`MAX_UPLOAD=10G sudo -E tuwunel config`); mit Cloudflare muss der Host **`matrix` grau sein** (das 100-MB-Limit der orangen Wolke killt große Dateien). |
| **Panel `admin.domain` öffnet nicht / Login-Fehler** | Meist fehlt der DNS-Eintrag `admin` oder das Zertifikat ist noch nicht bereit — Eintrag hinzufügen und ein paar Minuten warten. Bei Login-Fehlern: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Admin-Passwort vergessen | `cat /opt/tuwunel/CREDENTIALS.txt`; oder `sudo tuwunel adduser` für einen neuen Admin. |
| Konfiguration ändern (Anrufe, Registrierung, Dateigröße, Admin) | Ohne Neuinstallation: `sudo tuwunel config` — Enter behält Werte, Daten/Konten unangetastet. |
| Anrufe verbinden, aber ohne Ton/Bild | In 99 % der Fälle ist Port **7882/UDP** nicht freigegeben — in der Anbieter-Firewall ergänzen. |
| Speicher wird voll | Menü 7 „Speicher bereinigen“; bei intensiver Nutzung ein großes Volume oder Objektspeicher vorsehen. |
| „Kann nicht entschlüsselt werden“ bei alten Nachrichten in verschlüsseltem Raum | Normal: ein neues Gerät hat keine historischen Schlüssel. Die neue Sitzung von einem alten Gerät aus verifizieren. |
| Deinstallieren / neu installieren | `sudo tuwunel uninstall` (doppelte Bestätigung vor dem Löschen); neu installieren = deinstallieren und den Installationsbefehl erneut ausführen. |

---

## 📦 Serverseitige Komponenten

Nach der Installation laufen diese Komponenten, alle mit Docker orchestriert, quelloffen und prüfbar:

```
Caddy (automatisches HTTPS) + tuwunel (Rust, integriertes RocksDB, ohne PostgreSQL)
  + Element Web (Ihr eigener Web-Client, optional)
  + Ketesa (grafisches Admin-Panel, optional)
  + LiveKit + lk-jwt-service (Anrufe, optional)
```

Installationsverzeichnis `/opt/tuwunel`. Die gesamte Logik steckt in einem einzigen Skript `matrix-tuwunel-installer.sh`, das Sie selbst prüfen können.

---

## 🆚 tuwunel-Edition vs. Synapse

Das Repository enthält auch eine Synapse-Edition (`matrix-installer.sh`). Kurz:

- **tuwunel-Edition (dieses Dokument):** Rust, ohne PostgreSQL, **effizienter, stärker bei großen Dateien**, 2 GB für ~300 Personen. Ideal für die meisten Teams, besonders bei intensiver Nutzung großer Dateien.
- **Synapse-Edition:** Python + PostgreSQL, das reifste Ökosystem und die reifsten Admin-Werkzeuge, aber RAM-hungriger und schwächer bei großen Dateien.

**Für neue Bereitstellungen wird die tuwunel-Edition empfohlen.**

---

## 📄 Lizenz (Hinweis: nur nicht-kommerziell)

Dieses Projekt steht unter der Lizenz [PolyForm Noncommercial 1.0.0](LICENSE):

- ✅ **Kostenlos für private / interne Team- / Forschungs- / Non-Profit-Nutzung** — frei ändern und weiterverteilen (Urheberrechtshinweis beibehalten)
- ❌ **Jegliche kommerzielle Nutzung ist untersagt** (Verkauf, Integration in ein kommerzielles Produkt, Angebot als kostenpflichtiger Dienst usw.)
- 🚫 **Weiterverkauf auf jeglichem Marktplatz sowie kostenpflichtige „Installations-/Bereitstellungs“-Dienste sind untersagt** — dieses Projekt ist kostenlos; wer es verkauft, betreibt unbefugten Weiterverkauf
- 💼 Benötigen Sie eine ordentliche kommerzielle Lizenz? Öffnen Sie ein [Issue](../../issues), um den Autor zu kontaktieren.

Vergeben Sie einen Star ⭐, wenn es nützlich ist.

---

<div align="center">
Mit ❤️ gebaut · damit jeder seinen eigenen privaten Kommunikationsserver haben kann
</div>
