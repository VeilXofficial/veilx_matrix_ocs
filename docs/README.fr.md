<div align="center">

# Serveur de communication Matrix privé · Déploiement en une commande (édition tuwunel)

**Votre serveur, vos données — une messagerie d'équipe auto-hébergée, conçue pour la confidentialité et la souveraineté des données.**

Propulsée par le moteur **tuwunel** (en Rust, base de données intégrée, **sans PostgreSQL**) : plus légère, plus stable et capable d'**envoyer de gros fichiers / photos / longues vidéos comme Telegram**. 2 Go de RAM font tourner confortablement une équipe de taille moyenne. Chiffrement de bout en bout, minimisation des métadonnées et inscription sur invitation uniquement sont **activés par défaut**. Une seule commande pour déployer — pas besoin d'être administrateur système ; chaque option est expliquée simplement.

Client recommandé : **Element X**. Un client **VeilX** dédié est en développement (plus soigné, plus simple, plus de fonctions ; open source et auditable ; équipe d'exploitation au Royaume-Uni, à Singapour et au Japon). Dossiers clients, contrats, discussions internes, réunions audio et vidéo — tout cela n'existe que sur votre propre serveur. Bâti sur le protocole ouvert [Matrix](https://matrix.org). Code source public et auditable (gratuit pour un usage non commercial).

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · [粵語](README.zh-HK.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Русский](README.ru.md) · **Français** · [Deutsch](README.de.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Bahasa Melayu](README.ms.md) · [فارسی](README.fa.md)

</div>

---

## ✨ Ce que vous obtenez après l'installation

- 💬 Discussions textuelles et salons de groupe (**chiffrement de bout en bout — ni le serveur ni l'hébergeur ne peuvent lire le contenu des messages**)
- 📁 **Envoi de gros fichiers / grandes photos / longues vidéos** (limite par fichier de **4 Go** par défaut, configurable au-delà — la fonction phare)
- 📞 Appels audio / vidéo individuels et de groupe (optionnel)
- 📱 Inscription depuis le téléphone : installez **Element X**, saisissez votre domaine, inscrivez-vous et connectez-vous (sans passer par element.io)
- 🌐 Votre propre client web : ouvrez `https://votre-domaine` dans un navigateur pour vous inscrire/vous connecter, sans application
- 🖥️ **Panneau d'administration web graphique** (Ketesa) : gérer les utilisateurs, émettre/révoquer des codes d'invitation, consulter salons et médias
- 🔒 **Renforcement de la confidentialité par défaut** : l'IP réelle du client n'est jamais stockée, les suppressions sont définitives, présence désactivée, les journaux n'enregistrent pas les IP
- 👥 Sur invitation uniquement : par défaut, seul le détenteur d'un code d'invitation peut s'inscrire
- ⚡ **Économe en ressources** : un seul processus Rust, sans PostgreSQL — 2 Go de RAM pour ~300 personnes

---

## 📋 Avant de commencer (3 choses)

| Quoi | Exigence | Où |
|---|---|---|
| **Un serveur cloud (VPS)** | Ubuntu 22.04 / 24.04 (ou Debian 11+), une IP publique. **Choisissez la RAM selon la taille de l'équipe** (voir ci-dessous). **Prévoyez un disque suffisant si vous partagez de gros fichiers.** | [Vultr](https://www.vultr.com), [DigitalOcean](https://www.digitalocean.com), [Hetzner](https://www.hetzner.com/cloud), [OVHcloud](https://www.ovhcloud.com) ou un hébergeur de confiance |
| **Un nom de domaine** | N'importe quelle extension (.com / .org / .net…) | [Namecheap](https://www.namecheap.com), [Porkbun](https://porkbun.com), [Gandi](https://www.gandi.net) |
| **10 minutes** | Tout se fait par copier-coller ; aucune programmation | — |

> 💡 **Choisissez la RAM selon le nombre d'utilisateurs actifs simultanés** (fédération désactivée, chat + fichiers) : **1 Go** ≈ quelques dizaines de personnes (désactivez les appels) · **2 Go** ≈ 300 personnes · **4 Go / 2 vCPU** ≈ 500 personnes. tuwunel est léger ; le CPU est rarement le goulot d'étranglement.
> 💡 **Le disque est la vraie variable pour les gros fichiers.** Les médias sont stockés sur le disque local du serveur et, étant chiffrés de bout en bout, ne peuvent pas être dédupliqués. Un usage intensif peut ajouter de plusieurs centaines de Go à plusieurs To par mois. Disque système ≥ 50–100 Go ; pour un usage intensif, prévoyez un grand volume ou du stockage objet, et surveillez l'option « Nettoyer le disque ».
> 💡 **La juridiction compte pour la confidentialité.** Choisissez un hébergeur et un pays qui vous conviennent — l'hôte peut en principe être contraint de coopérer. Le chiffrement E2E protège le *contenu* dans tous les cas, mais les métadonnées restent chez l'hôte.
> 💡 À la commande, choisissez toujours une image **Ubuntu 22.04 / 24.04**. Si la RAM est inférieure à 2,5 Go, le script ajoute du swap automatiquement.

---

## Étape 0 — Préparer le système d'exploitation (à ignorer si déjà bien commandé)

Seul **Ubuntu 22.04 / 24.04** (ou Debian 11+) est pris en charge.

- **Nouveau serveur** : choisissez **Ubuntu 22.04 x86_64** (ou 24.04) dans le champ « OS / Image » à la commande.
- **Mauvais OS** : utilisez « Réinstaller / Reinstall / Rebuild » de l'hébergeur pour installer Ubuntu 22.04. ⚠️ Cela **efface toutes les données** — sauvegardez d'abord un serveur existant.
- Vous ne savez pas ce qui tourne ? Après connexion (Étape 3), lancez `cat /etc/os-release`.
- Installé sur le mauvais OS ? Le script le détecte et vous prévient clairement ; rien n'est cassé.

---

## Étape 1 — Ajouter les enregistrements DNS (~2 minutes)

Dans le panneau DNS de votre **registraire de domaine**, ajoutez des **enregistrements A**.

Supposons le domaine `mychat.org` et l'IP du serveur `1.2.3.4` :

| Type | Hôte (nom) | Valeur | Rôle |
|---|---|---|---|
| A | `@` (domaine racine) | `1.2.3.4` | Domaine racine + client web + délégation |
| A | `matrix` | `1.2.3.4` | Le serveur d'accueil |
| A | `admin` | `1.2.3.4` | Panneau d'administration (à ignorer si admin désactivé) |
| A | `livekit` | `1.2.3.4` | Appels (à ignorer sans appels) |
| A | `matrix-rtc` | `1.2.3.4` | Appels (à ignorer sans appels) |

> 📌 Le champ hôte ne prend que le **préfixe** (`matrix`), pas le domaine complet.
> 📌 Les enregistrements se propagent en 1 à 10 minutes ; l'installateur attend seul s'ils ne sont pas encore actifs.
> 📌 Pour chat + fichiers uniquement (sans appels), seuls `@` / `matrix` / `admin` sont nécessaires.
> ⚠️ **Vous utilisez Cloudflare ?** Ces enregistrements doivent être en **nuage gris (DNS uniquement)** ; **n'activez pas le nuage orange (proxy)**. Le proxy ① limite les gros fichiers à 100 Mo (Free/Pro) ② empêche l'émission du certificat ③ bloque le média des appels. L'installateur demande si vous utilisez un CDN (répondez oui pour assouplir la vérification DNS), mais l'hôte `matrix` doit rester en nuage gris.

---

## Étape 2 — Ouvrir les ports du pare-feu (~1 minute)

Dans le « Security Group / Firewall » de votre hébergeur, autorisez :

| Port | Protocole | Rôle |
|---|---|---|
| 80 | TCP | Émission du certificat HTTPS |
| 443 | TCP + UDP | Web et trafic chiffré |
| 7881 | TCP | Canal de secours des appels (à ignorer sans appels) |
| **7882** | **UDP** | **Audio/vidéo des appels (le plus souvent oublié ! Absent = ni son ni image)** |

> 📌 Votre hébergeur n'a pas cette couche « security group » ? Ignorez : le script configure le pare-feu système automatiquement.

---

## Étape 3 — Se connecter au serveur (~1 minute)

Ouvrez un terminal (macOS : « Terminal » ; Windows : « PowerShell »), lancez ceci (remplacez l'IP) et saisissez le mot de passe du serveur quand il est demandé (**il est normal que l'écran n'affiche aucun caractère pendant la saisie du mot de passe**) :

```bash
ssh root@IP_DE_VOTRE_SERVEUR
```

À la première connexion, répondez `yes` à l'invite d'empreinte.

> 📌 Si l'utilisateur par défaut n'est pas root (ex. `ubuntu`), utilisez `ssh ubuntu@IP` ; le script élève les privilèges seul.

---

## Étape 4 — Lancer l'installateur (~5–10 minutes, automatique)

Une fois connecté, **copiez la ligne entière** et collez-la dans le terminal :

```bash
sudo apt-get update && sudo apt-get install -y wget && wget -O tuwunel.sh https://raw.githubusercontent.com/VeilXofficial/veilx_matrix_ocs/main/matrix-tuwunel-installer.sh && sudo bash tuwunel.sh
```

Suivez l'assistant. Il pose **6 options + une question CDN** ; chacune est expliquée à l'écran, donc en cas de doute, appuyez sur Entrée (les valeurs par défaut sont la combinaison la plus sûre) :

| Option | Entrée (recommandé) | Notes |
|---|---|---|
| 1 Qui peut s'inscrire | **Code d'invitation requis** | Seul le détenteur du code entre ; le premier inscrit devient admin. (Ou totalement ouvert — pas pour un usage professionnel.) |
| 2 Fédération | **Désactivée** | Mode îlot : personne de l'extérieur ne peut écrire à vos membres ; surface d'attaque minimale. |
| 3 Appels audio/vidéo | **Désactivés d'abord** | Nécessitent deux enregistrements DNS (`livekit`/`matrix-rtc`) et les ports 7881/7882 ; stabilisez d'abord chat + fichiers. |
| 4 Client web | **Activé** | Les membres ouvrent `https://votre-domaine` pour s'inscrire/se connecter, sans application. |
| 5 Panneau d'administration | **Activé** | Un panneau graphique (Ketesa) sur `admin.votre-domaine`. |
| 6 Taille maximale de fichier | **4 Go** | Mettez ce que vous voulez (ex. 10 Go) ; plus c'est grand, plus ça consomme de disque. |
| ＋ Derrière Cloudflare/CDN ? | **Non** | Répondez oui seulement si vous utilisez un CDN (assouplit la vérif DNS) ; `matrix` reste en nuage gris. |

> 🔒 **Activé automatiquement (non demandé ; actif dès l'installation) :** ① les nouveaux salons sont **forcés au chiffrement E2E** ② **minimisation des métadonnées** (IP réelle non stockée, suppressions définitives, présence désactivée, journalisation sans IP) ③ **auto-inscription via Element X** (OIDC natif ; l'inscription requiert toujours un code d'invitation). Pour désactiver le renforcement des métadonnées : `PRIVACY=0 sudo -E tuwunel config`.
> 🤖 **Installation totalement automatique :** `REG_MODE=token ENABLE_CALLS=1 ENABLE_ADMIN=1 sudo -E bash tuwunel.sh mychat.org`

Ensuite, tout est automatique : vérification DNS → installation de Docker → réglage système → pare-feu → génération de la configuration → démarrage des services → obtention du certificat HTTPS → **création de l'admin et affichage du compte/mot de passe**.

Le succès ressemble à ceci :

```
========================================================
 🎉 tuwunel déployé !  mychat.org
 (inscription[token] · fédération[off] · appels[off] · web[on] · admin[on] · inscription-mobile[on] · gros-fichiers[4G] · moteur tuwunel/Rust, sans Postgres)

 Inscription / connexion des membres
   Web (recommandé) : ouvrez https://mychat.org pour vous inscrire et vous connecter
   Application mobile : installez Element X → serveur "mychat.org" → inscription (code) ou connexion

 Admin (créé automatiquement)
   compte : admin    mot de passe : xxxxxxxxxxxx
   Panneau web : https://admin.mychat.org  (connectez-vous avec le compte admin ci-dessus)

 Gestion quotidienne :  sudo tuwunel   (menu)    sudo tuwunel adduser   (ajouter un membre)
========================================================
```

> 🔑 **Notez le compte/mot de passe admin et le code d'invitation !** Tout est sur le serveur dans `/opt/tuwunel/CREDENTIALS.txt` (`cat /opt/tuwunel/CREDENTIALS.txt`).
> ⚠️ Un « pas encore prêt » à la fin signifie généralement que le pare-feu cloud n'autorise pas 80/443, ou que le DNS ne s'est pas propagé mondialement. Caddy retente le certificat seul — pas de réinstallation.

---

## Étape 5 — Se connecter depuis le téléphone / l'ordinateur

| Appareil | Client | Téléchargement |
|---|---|---|
| iPhone / iPad | **Element X** | [App Store](https://apps.apple.com/app/element-x/id1631335820) |
| Android | **Element X** | [Google Play](https://play.google.com/store/apps/details?id=io.element.android.x) |
| Windows / macOS / Linux | **Element Desktop** | [element.io/download](https://element.io/download) |
| Navigateur (sans installation) | Votre **propre client web** | Ouvrez `https://votre-domaine` |

**Connectez-vous avec le serveur = votre domaine** (ex. `mychat.org`, **pas** `matrix.mychat.org`) ; utilisez le compte/mot de passe affiché à la fin de l'installation.

> ⚠️ **Pas de connexion / Element X dit « couldn't connect to this homeserver » ? D'abord : vérifiez que la date et l'heure du téléphone sont correctes !**
> Une horloge fausse → la validation du certificat HTTPS échoue → impossible de se connecter (très fréquent, surtout sur Android).
> Solution : sur le téléphone, **Réglages → Date et heure → activez « Automatique »**, puis réessayez.

---

## 👥 Comment les membres rejoignent (au choix)

1. **L'admin crée le compte (le plus contrôlé) :** `sudo tuwunel adduser` crée un utilisateur et définit un mot de passe en une commande ; transmettez « domaine + identifiant + mot de passe ». Le code d'invitation ne quitte pas vos mains.
2. **Distribuer un code d'invitation, auto-inscription web :** envoyez le code (dans `CREDENTIALS.txt`) + `https://votre-domaine` ; les membres s'inscrivent seuls dans le navigateur.
3. **Distribuer un code, auto-inscription via Element X :** installez Element X → saisissez le domaine → créez le compte → entrez le code d'invitation.

---

## 🖥️ Panneau d'administration graphique (Ketesa, recommandé)

Si activé (option 5), l'installateur déploie un **panneau d'administration web graphique** : tout se gère à la souris, sans commandes.

**Comment entrer :** allez sur `https://admin.votre-domaine` → **connectez-vous directement avec le compte admin `admin` + mot de passe** (pas de mot de passe de portail séparé ; le panneau est verrouillé sur votre serveur).

**Ce que vous pouvez faire :** gérer les utilisateurs (créer/désactiver/réinitialiser le mot de passe), **émettre et révoquer des codes d'invitation**, consulter salons/médias, annuaire des salons, tâches planifiées.

> 📌 Les pages « Signalements / Utilisateurs signalés » peuvent afficher une erreur ou être vides : tuwunel n'implémente pas cette fonction ; c'est **normal** et vous n'en aurez presque jamais besoin.
> 📌 Le panneau nécessite tuwunel v1.8.1+ (l'image `:latest` l'inclut). Si la connexion au panneau échoue : `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`.
> 📌 Ajouter le panneau à un serveur existant : `sudo tuwunel enable-admin` (ajoutez d'abord l'enregistrement DNS `admin`).

---

## 🔧 Gestion au quotidien : le menu

Après l'installation, **exécuter `sudo tuwunel` ouvre le menu de gestion** (aucune commande à mémoriser) :

```bash
sudo tuwunel
```

```
┌──────────────────────────────────────────────┐
│  menu de gestion tuwunel   votre-domaine      │
└──────────────────────────────────────────────┘
  1) État                      6) Mettre à jour les images
  2) Ajouter un membre         7) Nettoyer le disque
  3) Modifier la config        8) Redémarrer les services
  4) Activer/désactiver admin  9) Mettre à jour le script + nouvelles fonctions
  5) Sauvegarder maintenant   10) Désinstaller entièrement
  p) Renforcement confidentialité / nettoyage métadonnées
  s) Caviarder le fichier d'identifiants en clair (anti-forensique)
  b) Sauvegarde chiffrée automatique planifiée
  0) Quitter
```

Ou utilisez les commandes directement :

```bash
sudo tuwunel adduser          # ajouter un membre
sudo tuwunel config           # modifier la config (Entrée = conserver ; données/comptes intacts)
sudo tuwunel update           # récupérer le dernier script depuis GitHub et appliquer les nouveautés (données intactes)
sudo tuwunel enable-admin     # ajouter le panneau d'administration à un serveur existant
sudo tuwunel enable-elementx  # activer l'auto-inscription via Element X
sudo tuwunel autobackup       # activer les sauvegardes chiffrées hebdomadaires automatiques
sudo tuwunel privacy          # confidentialité/métadonnées : voir ce qui peut être retiré, nettoyer les journaux
sudo tuwunel forget-secrets   # anti-forensique : caviarder le mot de passe/code en clair sur le disque
sudo tuwunel uninstall        # désinstaller
```

> 🔄 **Reconfigurer sans réinstaller** (menu 3) : repose les options, **Entrée = conserver la valeur actuelle**, puis redémarre. Comptes, historique et clés sont tous préservés.

---

## 🔒 Confidentialité / anti-forensique (l'accent de cette édition)

Ce système est conçu pour protéger les communications confidentielles et **minimise par défaut les traces laissées sur le serveur** :

- ✅ **Le contenu des messages est chiffré de bout en bout** — ni vous (l'opérateur) ni l'hébergeur ne pouvez le lire. C'est la seule garantie qui tient quelle que soit la qualité du serveur.
- ✅ **Minimisation des métadonnées (activée par défaut) :** IP réelle du client jamais stockée (`ip_source`), **suppressions réellement définitives** (l'original n'est pas conservé 60 jours), présence désactivée, niveau de journal trop bas pour enregistrer les IP, exposition des profils/annuaire des salons restreinte.
- ✅ **Outils anti-forensiques :** `sudo tuwunel forget-secrets` caviarde le mot de passe/code en clair sur le disque ; `sudo tuwunel autobackup` chiffre les sauvegardes en AES-256.

**Les limites honnêtes (dites-les à vos clients ; ne promettez pas trop) :**

- ❌ **Métadonnées impossibles à supprimer :** appartenance aux salons, chronologie des événements, existence du compte, noms des salons / fichiers — le serveur doit les conserver pour fonctionner. L'E2E protège le *contenu*, **pas les métadonnées** (qui parle à qui, quand, noms des salons, noms des fichiers).
- ❌ **Si le disque est saisi / cloné physiquement :** sur un VPS ordinaire, les données sont écrites en clair sur le disque et les métadonnées peuvent être extraites par analyse forensique. Défendre cette couche exige un hébergeur/une juridiction de confiance, ou un chiffrement intégral du disque avancé / un proxy « bouclier » en frontal (pas automatique ; travail d'ingénierie nécessaire).
- ❌ **Masquer l'IP du serveur via Cloudflare ne fonctionne pas vraiment** (les journaux de transparence des certificats et les sous-domaines en nuage gris la révèlent). Masquer réellement l'IP exige un proxy WireGuard auto-hébergé en frontal.

> Formulation précise pour les clients : **« Le contenu des messages et les pièces jointes sont chiffrés de bout en bout ; l'opérateur ne peut pas les lire. Toutefois le serveur conserve des métadonnées de communication (qui est dans quel salon, quand, noms de fichiers, noms de salons), qui pourraient être extraites en cas de saisie physique du serveur. »**

---

## 💾 Sauvegardes (fortement recommandé)

Perdre la base de données ou les clés signifie **aucune récupération**. Cette édition n'a pas de PostgreSQL : une sauvegarde est simplement une archive de `data/tuwunel` (base + médias) + `tuwunel.toml` + `.env`.

**Recommandé : activez les sauvegardes chiffrées automatiques** (hebdomadaires, AES-256, avec rotation, ignorées si le disque est presque plein) :

```bash
sudo tuwunel autobackup     # définissez dossier / rétention / fréquence ; la clé est affichée — enregistrez-la dans un gestionnaire de mots de passe
```

**Ou sauvegardez maintenant** (menu 5 ; vous pouvez définir une phrase de chiffrement).

**Télécharger sur votre ordinateur** (à exécuter sur votre propre machine) :

```bash
scp root@IP_DE_VOTRE_SERVEUR:/opt/tuwunel/backups/*.enc ~/Desktop/
```

> 🔑 **Enregistrez la clé de sauvegarde.** Sans elle, une sauvegarde chiffrée ne pourra jamais être ouverte. La clé n'existe que sur le serveur : si le serveur disparaît et que vous ne l'avez pas notée, les sauvegardes sont inutiles.
> 💡 Le dossier local `backups/` disparaît avec le serveur. Copiez régulièrement les fichiers `.enc` ailleurs, ou pointez le dossier de sauvegarde vers un volume externe monté / du stockage objet.

---

## ❓ FAQ

| Problème | Cause et solution |
|---|---|
| **Element X sur le téléphone ne se connecte pas / « couldn't connect to this homeserver »** | **D'abord, vérifiez la date et l'heure du téléphone** (Réglages → Date et heure → « Automatique ») : une horloge fausse fait échouer la validation du certificat ; c'est la cause la plus fréquente (surtout Android). Ensuite : essayez un autre réseau, vérifiez que `https://votre-domaine/.well-known/matrix/client` s'ouvre dans le navigateur du téléphone, et mettez Element X à jour. |
| **Element X dit « doit être mis à niveau pour prendre en charge le service d'authentification »** | Cela concerne l'inscription. Vérifiez que l'inscription mobile est activée (`sudo tuwunel enable-elementx`) et que tuwunel est à jour (`docker compose pull tuwunel`). Ou inscrivez via le web / `adduser` et laissez les membres **se connecter par mot de passe** dans Element X. |
| **Les gros fichiers ne s'envoient pas** | Vérifiez la limite (`MAX_UPLOAD=10G sudo -E tuwunel config`) ; avec Cloudflare, l'hôte **`matrix` doit être en nuage gris** (la limite de 100 Mo du nuage orange tue les gros fichiers). |
| **Le panneau `admin.domaine` ne s'ouvre pas / erreurs de connexion** | Généralement l'enregistrement DNS `admin` manque ou le certificat n'est pas prêt — ajoutez-le et attendez quelques minutes. Pour les erreurs de connexion : `cd /opt/tuwunel && docker compose pull tuwunel && docker compose up -d`. |
| Mot de passe admin oublié | `cat /opt/tuwunel/CREDENTIALS.txt` ; ou `sudo tuwunel adduser` pour créer un nouvel admin. |
| Modifier la config (appels, inscription, taille des fichiers, admin) | Sans réinstaller : `sudo tuwunel config` — Entrée conserve les valeurs, données/comptes intacts. |
| Les appels se connectent mais sans son/image | 99 % du temps, le port **7882/UDP** n'est pas autorisé — ajoutez-le dans le pare-feu de l'hébergeur. |
| Le disque se remplit | Menu 7 « Nettoyer le disque » ; pour un usage intensif, prévoyez un grand volume ou du stockage objet. |
| « Impossible de déchiffrer » d'anciens messages dans un salon chiffré | Normal : un nouvel appareil n'a pas les clés historiques. Vérifiez la nouvelle session depuis un ancien appareil. |
| Désinstaller / réinstaller | `sudo tuwunel uninstall` (double confirmation avant suppression) ; réinstaller = désinstaller puis relancer la commande d'installation. |

---

## 📦 Composants côté serveur

Après l'installation, ces composants tournent, tous orchestrés avec Docker, open source et auditables :

```
Caddy (HTTPS automatique) + tuwunel (Rust, RocksDB intégré, sans PostgreSQL)
  + Element Web (votre propre client web, optionnel)
  + Ketesa (panneau d'administration graphique, optionnel)
  + LiveKit + lk-jwt-service (appels, optionnel)
```

Répertoire d'installation `/opt/tuwunel`. Toute la logique tient dans un unique script `matrix-tuwunel-installer.sh`, que vous pouvez auditer vous-même.

---

## 🆚 Édition tuwunel vs Synapse

Le dépôt fournit aussi une édition Synapse (`matrix-installer.sh`). En bref :

- **Édition tuwunel (ce document) :** Rust, sans PostgreSQL, **plus efficace, meilleure avec les gros fichiers**, 2 Go pour ~300 personnes. Idéale pour la plupart des équipes, surtout un usage intensif de gros fichiers.
- **Édition Synapse :** Python + PostgreSQL, l'écosystème et les outils d'administration les plus matures, mais plus gourmande en RAM et plus faible avec les gros fichiers.

**Pour de nouveaux déploiements, l'édition tuwunel est recommandée.**

---

## 📄 Licence (à noter : usage non commercial uniquement)

Ce projet est sous licence [PolyForm Noncommercial 1.0.0](LICENSE) :

- ✅ **Gratuit pour un usage personnel / interne d'équipe / recherche / organisations à but non lucratif** — modifiez et redistribuez librement (conservez l'avis de droit d'auteur)
- ❌ **Tout usage commercial est interdit** (le vendre, l'intégrer dans un produit commercial, le proposer comme service payant, etc.)
- 🚫 **La revente sur toute place de marché et les services payants d'« installation/déploiement » sont interdits** — ce projet est gratuit ; si quelqu'un le vend, c'est une revente non autorisée
- 💼 Besoin d'une licence commerciale en règle ? Ouvrez une [Issue](../../issues) pour contacter l'auteur.

Mettez une Star ⭐ si c'est utile.

---

<div align="center">
Fait avec ❤️ · pour que chacun puisse avoir son propre serveur de communication privé
</div>
