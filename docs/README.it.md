<div align="center">

# Server di comunicazione Matrix privato · Distribuzione con un comando (edizione tuwunel)

**Il tuo server, i tuoi dati — un messenger di squadra self-hosted, costruito per la riservatezza e la sovranità dei dati.**

Basato sul motore **tuwunel** (in Rust, database integrato, **senza PostgreSQL**): più leggero, più stabile e capace di **inviare file di grandi dimensioni / foto / video lunghi come Telegram**. Con 2 GB di RAM gestisce comodamente un team di medie dimensioni. Crittografia end-to-end, minimizzazione dei metadati e registrazione solo su invito sono **attivi per impostazione predefinita**. Un solo comando per la distribuzione — non serve essere amministratori di sistema; ogni opzione è spiegata in modo semplice.

Client consigliato: **Element X**. È in sviluppo un client **VeilX** dedicato (più curato, più semplice, con più funzioni; open source e verificabile; team operativo nel Regno Unito, a Singapore e in Giappone). Documenti dei clienti, contratti, discussioni interne, riunioni audio e video — tutto esiste solo sul tuo server. Costruito sul protocollo aperto [Matrix](https://matrix.org). Codice sorgente pubblico e verificabile (gratuito per uso non commerciale).

[English](../README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Italiano** · [Español](README.es.md) · [Bahasa Melayu](README.ms.md) · [فارسی](README.fa.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [粵語](README.zh-HK.md)

</div>

---

## ✨ Cosa ottieni dopo l'installazione

- 💬 Chat testuali e stanze di gruppo (**crittografia end-to-end — né il server né il provider di hosting possono leggere il contenuto dei messaggi**)
- 📁 **Invio di file grandi / foto grandi / video lunghi** (limite per file **4 GB** di default, configurabile oltre — la funzione di punta)
- 📞 Chiamate audio / video individuali e di gruppo (opzionale)
- 📱 Registrazione dal telefono: installa **Element X**, inserisci il tuo dominio, registrati e accedi (senza passare da element.io)
- 🌐 Il tuo client web: apri `https://il-tuo-dominio` nel browser per registrarti/accedere, senza app
- 🖥️ **Pannello di amministrazione web grafico** (Ketesa): gestisci utenti, emetti/revoca codici di invito, controlla stanze e media
- 🔒 **Rafforzamento della privacy per impostazione predefinita**: l'IP reale del client non viene mai memorizzato, le eliminazioni sono definitive, presenza disattivata, i log non registrano gli IP
- 👥 Solo su invito: per impostazione predefinita può registrarsi solo chi ha un codice di invito
- ⚡ **Efficiente nelle risorse**: un unico processo Rust, senza PostgreSQL — 2 GB di RAM per ~300 persone

---

## 📋 Prima di iniziare (3 cose)

| Cosa | Requisito | Dove |
|---|---|---|
| **Un server cloud (VPS)** | Ubuntu 22.04 / 24.04 (o Debian 11+), un IP pubblico. **Scegli la RAM in base alla dimensione del team** (vedi sotto). **Prevedi disco a sufficienza se condividi file grandi.** | [Hetzner](https://www.hetzner.com/cloud), [OVHcloud](https://www.ovhcloud.com), [Netcup](https://www.netcup.com), [Aruba](https://www.arubacloud.com) o un provider di cui ti fidi |
| **Un dominio** | Qualsiasi estensione (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [Gandi](https://www.gandi.net) |
| **10 minuti** | Tutto con copia-incolla; nessuna programmazione | — |

> 💡 **Scegli la RAM in base agli utenti attivi in contemporanea** (federazione disattivata, chat + file): **1 GB** ≈ qualche decina di persone (disattiva le chiamate) · **2 GB** ≈ 300 persone · **4 GB / 2 vCPU** ≈ 500 persone. tuwunel è leggero; la CPU raramente è il collo di bottiglia.
> 💡 **Il disco è la vera variabile per i file grandi.** I media sono salvati sul disco locale del server e, essendo crittografati end-to-end, non possono essere deduplicati. Un uso intenso può aggiungere da centinaia di GB a TB al mese. Disco di sistema ≥ 50–100 GB; per un uso intenso prevedi un volume grande o object storage, e tieni d'occhio l'opzione «Pulisci disco».
> 💡 **La giurisdizione conta per la privacy.** Scegli provider e paese con cui ti trovi a tuo agio — l'host può in linea di principio essere costretto a collaborare. La crittografia E2E protegge comunque il *contenuto*, ma i metadati restano sull'host.
> 💡 In fase d'ordine scegli sempre un'immagine **Ubuntu 22.04 / 24.04**. Se la RAM è inferiore a 2,5 GB, lo script aggiunge automaticamente lo swap.

---

## Passo 0 — Prepara il sistema operativo (salta se ordinato correttamente)

È supportato solo **Ubuntu 22.04 / 24.04** (o Debian 11+).

- **Nuovo server**: al momento dell'ordine seleziona **Ubuntu 22.04 x86_64** (o 24.04) nel campo «OS / Image».
- **OS sbagliato**: usa «Reinstalla / Reinstall / Rebuild» del provider per installare Ubuntu 22.04. ⚠️ Questo **cancella tutti i dati** — fai prima un backup di un server esistente.
- Non sai cosa gira? Dopo la connessione (Passo 3) esegui `cat /etc/os-release`.
- Se installi sull'OS sbagliato, lo script lo rileva e te lo dice chiaramente; non rompe nulla.

---

## Passo 1 — Aggiungi i record DNS (~2 minuti)

Nel pannello DNS del tuo **registrar di dominio**, aggiungi **record A**.

Ipotizzando dominio `mychat.org` e IP del server `1.2.3.4`:

| Tipo | Host (nome) | Valore | Uso |
|---|---|---|---|
| A | `@` (dominio radice) | `1.2.3.4` | Dominio radice + client web + delega |
| A | `matrix` | `1.2.3.4` | Il server di casa |
| A | `admin` | `1.2.3.4` | Pannello di amministrazione (salta se admin disattivato) |
| A | `livekit` | `1.2.3.4` | Chiamate (salta senza chiamate) |
| A | `matrix-rtc` | `1.2.3.4` | Chiamate (salta senza chiamate) |

> 📌 Il campo host prende solo il **prefisso** (`matrix`), non il dominio completo.
> 📌 I record si propagano in 1–10 minuti; l'installer attende da solo se non sono ancora attivi.
> 📌 Per solo chat + file (senza chiamate) bastano `@` / `matrix` / `admin`.
> ⚠️ **Usi Cloudflare?** Questi record devono essere in **nuvola grigia (solo DNS)**; **non attivare la nuvola arancione (proxy)**. Il proxy ① limita i file grandi a 100 MB (Free/Pro) ② impedisce l'emissione del certificato ③ blocca il media delle chiamate. L'installer chiede se usi un CDN (rispondi sì per allentare il controllo DNS), ma l'host `matrix` deve restare in nuvola grigia.

---

## Passo 2 — Apri le porte del firewall (~1 minuto)

Nel «Security Group / Firewall» del tuo provider, consenti:

| Porta | Protocollo | Uso |
|---|---|---|
| 80 | TCP | Emissione del certificato HTTPS |
| 443 | TCP + UDP | Web e traffico crittografato |
| 7881 | TCP | Canale di riserva per le chiamate (salta senza chiamate) |
| **7882** | **UDP** | **Audio/video delle chiamate (il più facile da dimenticare! Manca = niente audio né video)** |

> 📌 Il provider non ha questo livello «security group»? Salta: lo script configura il firewall di sistema automaticamente.

---

## Passo 3 — Connettiti al server (~1 minuto)

Apri un terminale (macOS: «Terminale»; Windows: «PowerShell»), esegui quanto segue (sostituisci l'IP) e inserisci la password del server quando richiesta (**è normale che lo schermo non mostri alcun carattere mentre digiti la password**):

```bash
ssh root@IP_DEL_TUO_SERVER
```

Alla prima connessione, rispondi `yes` alla richiesta dell'impronta.

> 📌 Se l'utente predefinito non è root (es. `ubuntu`), usa `ssh ubuntu@IP`; lo script eleva i privilegi da solo.

---

## Passo 4 — Esegui l'installer (~5–10 minuti, automatico)

Una volta connesso, **copia l'intera riga** e incollala nel terminale:

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Segui la procedura guidata. Pone **6 opzioni + una domanda sul CDN**; ognuna è spiegata a schermo, quindi nel dubbio premi Invio (i valori predefiniti sono la combinazione più sicura):

| Opzione | Invio (consigliato) | Note |
|---|---|---|
| 1 Chi può registrarsi | **Richiede codice di invito** | Entra solo chi ha il codice; il primo registrato diventa admin. (Oppure completamente aperto — non per uso aziendale.) |
| 2 Federazione | **Disattivata** | Modalità isola: nessuno dall'esterno può scrivere ai tuoi membri; superficie d'attacco minima. |
| 3 Chiamate audio/video | **Prima disattivale** | Richiedono due record DNS extra (`livekit`/`matrix-rtc`) e le porte 7881/7882; stabilizza prima chat + file. |
| 4 Client web | **Attivo** | I membri aprono `https://il-tuo-dominio` per registrarsi/accedere, senza app. |
| 5 Pannello di amministrazione | **Attivo** | Un pannello grafico (Ketesa) su `admin.il-tuo-dominio`. |
| 6 Dimensione massima file | **4 GB** | Imposta quel che vuoi (es. 10 GB); più è grande, più disco consuma. |
| ＋ Dietro Cloudflare/CDN? | **No** | Rispondi sì solo se usi un CDN (allenta il controllo DNS); `matrix` resta in nuvola grigia. |

> 🔒 **Attivato automaticamente (non chiesto; attivo appena installato):** ① le nuove stanze sono **forzate alla crittografia E2E** ② **minimizzazione dei metadati** (IP reale non memorizzato, eliminazioni definitive, presenza disattivata, logging senza IP) ③ **auto-registrazione via Element X** (OIDC nativo; la registrazione richiede comunque un codice di invito). Per disattivare il rafforzamento dei metadati: `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Installazione completamente automatica:** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Poi tutto è automatico: verifica DNS → installa Docker → ottimizza il sistema → firewall → genera la configurazione → avvia i servizi → ottiene il certificato HTTPS → **crea l'admin e stampa account/password**.

Il successo appare così:

```
========================================================
 🎉 tuwunel distribuito!  mychat.org
 (registrazione[token] · federazione[off] · chiamate[off] · web[on] · admin[on] · registrazione-mobile[on] · file-grandi[4G] · motore tuwunel/Rust, senza Postgres)

 Registrazione / accesso dei membri
   Web (consigliato): apri https://mychat.org per registrarti e accedere
   App mobile: installa Element X → server "mychat.org" → registrati (codice) o accedi

 Admin (creato automaticamente)
   account: admin    password: xxxxxxxxxxxx
   Pannello web: https://admin.mychat.org  (accedi con l'account admin qui sopra)

 Gestione quotidiana:  sudo tuwunel   (menu)    sudo tuwunel adduser   (aggiungi un membro)
========================================================
```

> 🔑 **Annota account/password admin e codice di invito!** Sono tutti sul server in `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ Un «non ancora pronto» alla fine di solito significa che il firewall cloud non consente 80/443, o che il DNS non si è propagato globalmente. Caddy riprova il certificato da solo — nessuna reinstallazione.

---

## Passo 5 — Accedi da telefono / computer

| Dispositivo | Client | Download |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Browser (senza installazione) | Il tuo **client web** | Apri `https://il-tuo-dominio` |

**Accedi con il server = il tuo dominio** (es. `mychat.org`, **non** `matrix.mychat.org`); usa account/password mostrati alla fine dell'installazione.

> ⚠️ **Non si connette / Element X dice «couldn't connect to this homeserver»? Per prima cosa: verifica che data e ora del telefono siano corrette!**
> Un orologio sbagliato → la verifica del certificato HTTPS fallisce → impossibile connettersi (molto comune, soprattutto su Android).
> Soluzione: sul telefono **Impostazioni → Data e ora → attiva «Automatica»**, poi riprova.

---

## 👥 Come si uniscono i membri (scegline uno)

1. **L'admin crea l'account (massimo controllo):** `sudo tuwunel adduser` crea un utente e imposta una password in un comando; consegna «dominio + nome utente + password». Il codice di invito non lascia le tue mani.
2. **Distribuisci un codice di invito, auto-registrazione web:** invia il codice (in `CREDENTIALS.txt`) + `https://il-tuo-dominio`; i membri si registrano da soli nel browser.
3. **Distribuisci un codice, auto-registrazione via Element X:** installano Element X → inseriscono il dominio → creano l'account → inseriscono il codice di invito.

---

## 🖥️ Pannello di amministrazione grafico (Ketesa, consigliato)

Se attivato (opzione 5), l'installer distribuisce un **pannello di amministrazione web grafico** — tutto con il mouse, senza comandi.

**Come entrare:** vai su `https://admin.il-tuo-dominio` → **accedi direttamente con l'account admin `admin` + password** (nessuna password di gate separata; il pannello è vincolato al tuo server).

**Cosa puoi fare:** gestire utenti (creare/disattivare/reimpostare password), **emettere e revocare codici di invito**, controllare stanze/media, elenco stanze, attività pianificate.

> 📌 Le pagine «Segnalazioni / Utenti segnalati» possono dare errore o risultare vuote: tuwunel non implementa quella funzione; è **normale** e non servirà quasi mai.
> 📌 Il pannello richiede tuwunel v1.8.1+ (l'immagine `:latest` lo include). Se l'accesso al pannello dà errore: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Aggiungere il pannello a un server esistente: `sudo tuwunel enable-admin` (aggiungi prima il record DNS `admin`).

---

## 🔧 Gestione quotidiana: il menu

Dopo l'installazione, **eseguire `sudo tuwunel` apre il menu di gestione** (nessun comando da memorizzare):

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  menu di gestione tuwunel   il-tuo-dominio    │
└──────────────────────────────────────────────┘
  1) Stato                     6) Aggiorna immagini servizi
  2) Aggiungi un membro        7) Pulisci disco
  3) Modifica configurazione   8) Riavvia i servizi
  4) Attiva/disattiva admin    9) Aggiorna script + nuove funzioni
  5) Backup adesso            10) Disinstalla completamente
  p) Rafforzamento privacy / pulizia metadati
  s) Oscura il file delle credenziali in chiaro (anti-forense)
  b) Backup crittografato automatico pianificato
  0) Esci
```

Oppure usa i comandi direttamente:

```bash
sudo tuwunel adduser          # aggiungi un membro
sudo tuwunel config           # modifica la configurazione (Invio = mantieni; dati/account intatti)
sudo tuwunel update           # scarica l'ultimo script da GitHub e applica le nuove funzioni (dati intatti)
sudo tuwunel enable-admin     # aggiungi il pannello di amministrazione a un server esistente
sudo tuwunel enable-elementx  # attiva l'auto-registrazione via Element X
sudo tuwunel autobackup       # attiva i backup crittografati settimanali automatici
sudo tuwunel privacy          # privacy/metadati: vedi cosa si può rimuovere, pulisci i log
sudo tuwunel forget-secrets   # anti-forense: oscura password/codice di invito in chiaro sul disco
sudo tuwunel uninstall        # disinstalla
```

> 🔄 **Riconfigura senza reinstallare** (menu 3): richiede di nuovo le opzioni, **Invio = mantieni il valore attuale**, poi riavvia. Account, cronologia e chiavi vengono tutti preservati.

---

## 🔒 Privacy / anti-forense (il focus di questa edizione)

Questo sistema è progettato per proteggere le comunicazioni riservate e **minimizza per impostazione predefinita le tracce lasciate sul server**:

- ✅ **Il contenuto dei messaggi è crittografato end-to-end** — né tu (l'operatore) né il provider di hosting potete leggerlo. È l'unica garanzia che regge a prescindere da quanto sia buono o cattivo il server.
- ✅ **Minimizzazione dei metadati (attiva di default):** IP reale del client mai memorizzato (`ip_source`), **eliminazioni davvero definitive** (l'originale non viene conservato 60 giorni), presenza disattivata, livello di log troppo basso per registrare gli IP, esposizione di profili/elenco stanze ristretta.
- ✅ **Strumenti anti-forensi:** `sudo tuwunel forget-secrets` oscura password/codice di invito in chiaro sul disco; `sudo tuwunel autobackup` cifra i backup con AES-256.

**I limiti onesti (dilli ai tuoi clienti; non promettere troppo):**

- ❌ **Metadati non eliminabili:** appartenenza alle stanze, cronologia degli eventi, esistenza dell'account, nomi di stanze / file — il server deve conservarli per funzionare. L'E2E protegge il *contenuto*, **non i metadati** (chi parla con chi, quando, nomi di stanze, nomi di file).
- ❌ **Se il disco viene sequestrato / clonato fisicamente:** su un VPS comune i dati sono scritti in chiaro sul disco e i metadati sono estraibili con l'analisi forense. Difendere questo livello richiede un provider/una giurisdizione affidabile, o crittografia dell'intero disco avanzata / un proxy «scudo» frontale (non automatico; richiede lavoro ingegneristico).
- ❌ **Nascondere l'IP del server tramite Cloudflare praticamente non funziona** (i log di trasparenza dei certificati e i sottodomini in nuvola grigia lo rivelano). Nascondere davvero l'IP richiede un proxy WireGuard frontale self-hosted.

> Formulazione precisa per i clienti: **«Il contenuto dei messaggi e gli allegati sono crittografati end-to-end; l'operatore non può leggerli. Tuttavia il server conserva i metadati di comunicazione (chi è in quale stanza, quando, nomi dei file, nomi delle stanze), che potrebbero essere estratti in caso di sequestro fisico del server.»**

---

## 💾 Backup (fortemente consigliato)

Se perdi il database o le chiavi **non c'è recupero**. Questa edizione non ha PostgreSQL: un backup è semplicemente un archivio di `data/tuwunel` (database + media) + `tuwunel.toml` + `.env`.

**Consigliato: attiva i backup crittografati automatici** (settimanali, AES-256, con rotazione, saltati se il disco è quasi pieno):

```bash
sudo tuwunel autobackup     # imposta cartella / conservazione / frequenza; la chiave viene mostrata — salvala in un gestore di password
```

**Oppure fai un backup adesso** (menu 5; puoi impostare una passphrase di cifratura).

**Scarica sul tuo computer** (esegui sulla tua macchina):

```bash
scp root@IP_DEL_TUO_SERVER:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Salva la chiave di backup.** Senza di essa un backup crittografato non si può aprire mai. La chiave esiste solo sul server: se il server sparisce e non l'hai annotata, i backup sono inutili.
> 💡 La cartella locale `backups/` muore con il server. Copia i file `.enc` altrove regolarmente, o punta la cartella dei backup a un volume esterno montato / object storage.

---

## ❓ Domande frequenti

| Problema | Causa e soluzione |
|---|---|
| **Element X sul telefono non si connette / «couldn't connect to this homeserver»** | **Per prima cosa, verifica data e ora del telefono** (Impostazioni → Data e ora → «Automatica»): un orologio sbagliato fa fallire la verifica del certificato; è la causa più comune (soprattutto Android). Poi: prova un'altra rete, verifica che `https://il-tuo-dominio/.well-known/matrix/client` si apra nel browser del telefono, e aggiorna Element X. |
| **Element X dice «deve essere aggiornato per supportare il servizio di autenticazione»** | Riguarda la registrazione. Verifica che la registrazione da mobile sia attiva (`sudo tuwunel enable-elementx`) e che tuwunel sia aggiornato (`docker compose pull tuwunel`). Oppure registra via web / `adduser` e fai **accedere i membri con la password** in Element X. |
| **I file grandi non si caricano** | Controlla il limite (`MAX_UPLOAD=10G sudo -E tuwunel config`); con Cloudflare l'host **`matrix` deve essere in nuvola grigia** (il limite di 100 MB della nuvola arancione uccide i file grandi). |
| **Il pannello `admin.dominio` non si apre / errori di accesso** | Di solito manca il record DNS `admin` o il certificato non è pronto — aggiungilo e attendi qualche minuto. Per errori di accesso: `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Password admin dimenticata | `cat /opt/tuwunel/CREDENTIALS.txt`; oppure `sudo tuwunel adduser` per creare un nuovo admin. |
| Modificare la configurazione (chiamate, registrazione, dimensione file, admin) | Senza reinstallare: `sudo tuwunel config` — Invio mantiene i valori, dati/account intatti. |
| Le chiamate si connettono ma senza audio/video | Nel 99% dei casi la porta **7882/UDP** non è consentita — aggiungila nel firewall del provider. |
| Il disco si riempie | Menu 7 «Pulisci disco»; per un uso intenso prevedi un volume grande o object storage. |
| «Impossibile decifrare» vecchi messaggi in una stanza crittografata | Normale: un nuovo dispositivo non ha le chiavi storiche. Verifica la nuova sessione da un vecchio dispositivo. |
| Disinstallare / reinstallare | `sudo tuwunel uninstall` (doppia conferma prima di eliminare); reinstallare = disinstallare e rilanciare il comando di installazione. |

---

## 📦 Componenti lato server

Dopo l'installazione, questi componenti sono in esecuzione, tutti orchestrati con Docker, open source e verificabili:

```
Caddy (HTTPS automatico) + tuwunel (Rust, RocksDB integrato, senza PostgreSQL)
  + Element Web (il tuo client web, opzionale)
  + Ketesa (pannello di amministrazione grafico, opzionale)
  + LiveKit + lk-jwt-service (chiamate, opzionale)
```

Directory di installazione `/opt/tuwunel`. Tutta la logica è in un unico script `matrix-tuwunel-installer.sh`, che puoi verificare tu stesso.

---

## 🆚 Edizione tuwunel vs Synapse

Il repository include anche un'edizione Synapse (`matrix-installer.sh`). In breve:

- **Edizione tuwunel (questo documento):** Rust, senza PostgreSQL, **più efficiente, più forte con i file grandi**, 2 GB per ~300 persone. Ideale per la maggior parte dei team, soprattutto con uso intenso di file grandi.
- **Edizione Synapse:** Python + PostgreSQL, l'ecosistema e gli strumenti di amministrazione più maturi, ma più esigente in RAM e più debole con i file grandi.

**Per nuove distribuzioni si consiglia l'edizione tuwunel.**

---

## 📄 Licenza (nota: solo uso non commerciale)

Questo progetto è rilasciato sotto licenza [PolyForm Noncommercial 1.0.0](LICENSE):

- ✅ **Gratuito per uso personale / interno al team / ricerca / organizzazioni non profit** — modifica e ridistribuisci liberamente (mantieni l'avviso di copyright)
- ❌ **Ogni uso commerciale è vietato** (venderlo, integrarlo in un prodotto commerciale, offrirlo come servizio a pagamento, ecc.)
- 🚫 **La rivendita su qualsiasi marketplace e i servizi a pagamento di «installazione/distribuzione» sono vietati** — questo progetto è gratuito; se qualcuno lo vende, è rivendita non autorizzata
- 💼 Ti serve una licenza commerciale regolare? Apri una [Issue](../../issues) per contattare l'autore.

Metti una Star ⭐ se ti è utile.

---

<div align="center">
Fatto con ❤️ · perché tutti possano avere il proprio server di comunicazione privato
</div>
