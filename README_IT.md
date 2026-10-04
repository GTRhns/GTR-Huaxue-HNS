# 🎮 GTR HNS Sistema di plugin per match · Huaxue Edition

<p align="center">
  <img src="assets/banner.jpg" alt="华雪版封面" width="480">
</p>

<div align="center">

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.10-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![Version](https://img.shields.io/badge/Version-v1.19-green)]()
[![Storage](https://img.shields.io/badge/Storage-PDS_%2B_MySQL-9cf)]()
[![Language](https://img.shields.io/badge/Language-4_Languages-ff69b4)]()
[![License](https://img.shields.io/badge/License-GPLv3-success)]()

</div>

**🌐 Language / 语言:** [简体中文](README.md) · [繁體中文](README_ZH-TW.md) · [English](README_EN.md) · [Deutsch](README_DE.md) · [Русский](README_RU.md) · [Italiano](README_IT.md) · [Türkçe](README_TR.md) · [Français](README_FR.md)

> **Sviluppato a partire dal motore di match OpenHNS, integrato con numerose funzioni sviluppate dal team GTR**
> Compatibilità: CS 1.6 / ReHLDS / AMX Mod X 1.10
> Versione attuale: **Huaxue Edition v1.19** (tag: `huaxue-v1.19`) · release del 2026-10-01

---

## 📌 Indice

- [1. Panoramica del progetto](#1-panoramica-del-progetto)
- [2. Nuova versione vs vecchia: cosa cambia](#2-nuova-versione-vs-vecchia-cosa-cambia)
- [3. Novità della Huaxue Edition v1.19](#3-novita-della-huaxue-edition-v118)
- [4. Elenco dei plugin](#4-elenco-dei-plugin)
- [5. Struttura del repository](#5-struttura-del-repository)
- [6. Distribuzione rapida](#6-distribuzione-rapida)
- [7. Stack tecnologico](#7-stack-tecnologico)
- [8. Note sul copyright](#8-note-sul-copyright)
- [9. Versioni multilingue](#9-versioni-multilingue)

---

## 1. Panoramica del progetto

Si tratta di un sistema completo di plugin per server di match CS 1.6 HNS (Hide 'n' Seek, nascondino).

La base proviene dal progetto open source **OpenHNS** (HnsMatchSystem 2.0.5 e il suo set ufficiale di plugin);
su di essa il team GTR ha iniettato una grande quantità di codice proprietario lungo l'intero flusso «**registrazione → formazione squadre → scelta di modalità/mappa → avvio del match → calcolo dei risultati**»,
dando vita a un motore di match indipendente: il **motore proprietario GTR**.

---

## 2. Nuova versione vs vecchia: cosa cambia

### 2.1 Problemi della vecchia versione (la radice dei problemi risolti in questo repository)

| # | Problema della vecchia versione | Cosa accadeva realmente agli utenti |
|---|---|---|
| 1 | Menu AI con cinese hardcoded | Dopo aver cambiato `/lang` in inglese, il menu di iscrizione AI restava in cinese |
| 2 | Processo di avvio forzato difettoso | L'avvio forzato mandava i giocatori in spec e poi "spariva": mappa/modalità non selezionate |
| 3 | Entrata in campo con il comando `jointeam` | Intercettata da `blockCmd`, i giocatori restavano bloccati in spec nella modalità LOBBY |
| 4 | Partecipanti non marcati prima dell'avvio | `forceUnmatchedToSpec` in `mix_start()` rimandava in spec chi era appena entrato in campo |
| 5 | Stato completamente perso al cambio mappa | Dopo il changelevel con mappa scelta dall'AI, iscrizioni/modalità perse, il match non partiva mai |
| 6 | Anche il cambio mappa normale avviava il match | L'admin cambia mappa e il server avvia da solo l'iscrizione; dopo 2 minuti raccoglie le squadre |
| 7 | Nessuna registrazione dello sponsor nei match sponsorizzati | Match sponsorizzato avviato ma nessuno può dire al sistema "chi è lo sponsor" |
| 8 | Voce 7 del menu mix anomala | La voce 7 (modalità HNS) "non si clicca": la stringa di lingua non ha `^n` e sembra una voce morta |
| 9 | Barra del contatore di iscrizione | In chat/HUD compariva `012345[6]78910`, gli utenti ne avevano chiesto la rimozione |
| 10 | Il menu di iscrizione si chiudeva dopo un clic | Si voleva continuare a operare sul menu ma si chiudeva da solo |

### 2.2 Miglioramenti corrispondenti nella nuova versione (Huaxue Edition v1.19)

| # | Miglioramento | Come è stato implementato |
|---|---|---|
| 1 | **Menu AI completamente multilingue** | Tutto passa da `HnsLang_Get(id, key)`, supporto di 4 lingue (cinese semplificato/tradizionale, inglese, russo), sincronizzato in tempo reale con `/lang` |
| 2 | **Processo di iscrizione ristrutturato** | Macchina a stati `SIGNUP_STATE`: iscrizione → raccolta squadre (tutti in spec + 1 giocatore in campo al secondo) → scelta modalità/mappa → avvio match |
| 3 | **Entrata in campo sicura via ReAPI** | Si usa `rg_set_user_team` (ReAPI) al posto di `jointeam`; consentito in LOBBY/TRAINING, niente più blocchi in spec |
| 4 | **Pre-marcatura per l'avvio esterno** | Il nuovo native `hns_begin_external_match` marca T/CT come partecipanti prima dell'avvio, risolvendo la seconda causa radice del "tutti in spec all'avvio" |
| 5 | **Recupero PDS tra le mappe** | Dopo la scelta della mappa `PDS_SetCell("ai_pending_start",1)`; al ritorno dopo il cambio mappa il match riprende automaticamente dopo 5 secondi (`taskPendingResume`) |
| 6 | **Il cambio mappa normale non avvia più il match** | Cambio mappa non-pending: iscrizioni azzerate, server in attesa, avvio manuale da parte dell'admin |
| 7 | **Registrazione dello sponsor** | Dopo la scelta della mappa, il primo VIP/admin online digita il nome dello sponsor in chat; timeout 30 secondi o `/取消` per saltare |
| 8 | **Numerazione fissa del menu mix** | La voce 7 è sempre ICGB (grigia e non cliccabile senza match sponsorizzato), la voce 8 è sempre il menu admin |
| 9 | **Rimossa la barra numerica UI** | Eliminata `buildSignupBar()`, l'HUD mostra solo `报名: n/12` |
| 10 | **Il menu non si chiude dopo il clic** | Dopo un'azione nel menu di iscrizione si torna al menu principale per operazioni consecutive |
| 11 | **Vincitore determinato dalla squadra logica** | Nuovo native `hns_get_player_match_team`; la liquidazione wintime assegna i punti alla squadra giusta (v1.19) |
| 12 | **Permessi del menu ristretti** | Dimensioni squadra / nuova divisione / avvio forzato visibili e cliccabili solo per VIP/admin (v1.19) |
| 13 | **Stato della modalità unico** | AI e MatchSystem condividono un'unica modalità; dopo il cambio mappa viene ripristinata insieme al resto, niente più divergenze (v1.19) |

### 2.3 Cronologia delle versioni (plugin principale HnsAISignup)

| Versione | Ora | Stato | Descrizione |
|---|---|---|---|
| v1.3 | 09-27 19:12 | Backup storico | Versione prima del fix squadre (teamfix) |
| v1.5 | 09-27 19:55 | Backup storico | Versione con fix admin (adminfix) |
| v1.5 | 09-27 20:00 | Backup storico | Backup prima del secondo fix |
| v1.9 | 09-27 22:07 | Backup storico | Prima delle modifiche su larga scala (prima della ristrutturazione del processo di iscrizione) |
| **v1.17** | 09-30 23:00 | **Versione precedente** | Release ufficiale della Huaxue Edition, tutti i miglioramenti applicati |
| v1.17+ | 10-01 02:13 | In sviluppo | Aggiunto `taskRestorePendingRules` (ripristino ritardato della modalità dopo il cambio mappa), non distribuito |
| **v1.19** | 10-01 | **Versione attualmente in produzione** | Fix determinazione vincitore wintime + ripristino modalità dopo il cambio mappa + permessi del menu ristretti + stato della modalità unico |

> Cronologia completa delle versioni in `02_各插件历史版本/`, ogni versione ha una cartella dedicata + descrizione.

---

## 3. Novità della Huaxue Edition v1.19

- 🤖 **Sistema di iscrizione AI v1.19**: `/signup` iscrizione con un clic, raccolta e formazione squadre, match amichevoli/sponsorizzati, voto su modalità e mappa,
  avvio forzato (testabile anche con 1 giocatore), ripresa del match dopo il cambio mappa, contatore iscrizioni su HUD.
- 🎨 **Sistema skin (MySQL)**: skin personalizzabili dal giocatore, acquisto con monete / noleggio / upgrade permanente,
  suoni di morte casuali, gestione dal menu admin `/cpm`.
- 💳 **Sponsorizzazioni / sistema monete ICGB**: nei match sponsorizzati lo sponsor viene registrato automaticamente, le monete sono collegate alle skin.
- 🗂 **Persistenza tra le mappe (PDS)**: il cambio mappa non perde lo stato del match, dopo la scelta della mappa da parte dell'AI il match riparte automaticamente.
- 🌐 **Localizzazione in 4 lingue**: cinese semplificato / tradizionale / English / Русский, menu AI e menu match unificati.
- 🧠 **Bot AI per i match**: si può testare il match anche da soli (1 giocatore), senza restare bloccati in spec.
- 🛡 **Ordine di caricamento stabile**: in `plugins.ini` l'ordine è già pronto: HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin.
- 🎯 **Fix della determinazione del vincitore**: la liquidazione wintime assegna i punti in base alla squadra logica di match; dopo cambio lato/mappa non vengono più accreditati giocatori sbagliati.
- 🔐 **Permessi ristretti**: le azioni di gestione (dimensioni squadra / nuova divisione / avvio forzato) visibili e cliccabili solo per VIP/admin.

---

## 4. Elenco dei plugin

| Plugin | Versione | Funzione |
|---|---|---|
| HnsAISignup | v1.19 | Sistema di iscrizione AI (sviluppo proprietario principale) |
| HnsMatchSystem | 2.0.5+ | Macchina a stati del match (base OpenHNS + 2 nuovi native: `hns_get_player_match_team` / `hns_get_match_team_cs`) |
| HnsMatchBans | 1.1 | Gestione ban |
| HnsMatchMaps | 4.0.4 | Gestione mappe |
| HnsMatchStats | 1.1.1 | Statistiche |
| HnsMatchPts | 1.1 | Punti |
| HnsMatchQuery | 1.0.0 | Query di match `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | Impostazioni admin `/adminmenu` |
| HnsMatchSkin | 1.0 | Sistema skin (MySQL) |
| HnsMatchSql | 1.1 | Gestione unificata MySQL |
| HnsLanguage | 1.3.0 | Core linguistico a 4 lingue |
| HnsPersistentDataStorage | 1.0 | Persistenza tra le mappe |
| HnsSponsorLocal | 1.0 | Sponsor / monete ICGB |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | Supporto al match |

---

## 5. Struttura del repository

```
01_当前版本_核心源码/       sorgenti dei plugin core della versione in produzione + include + compiled
02_各插件历史版本/          ogni versione dei plugin in una cartella separata, contrassegnata per versione
03_开发工作区_scripting/    area di lavoro di sviluppo locale + compilatore AMXX
04_服务器部署_cstrike/      struttura completa di distribuzione (addons/amxmodx + classificazione plugin di terze parti)
05_皮肤系统_v1.0完整版/     pacchetto di installazione completo del sistema skin MySQL
06_Beta测试插件包/          5 piccoli plugin indipendenti
07_第三方插件包/            SEM / semiclip / rtv_rus (dream-x.ru)
08_资源文件_asd/            modelli skin / suoni / texture
10_交接与文档/              registro modifiche, note di consegna, changelog
```

---

## 6. Distribuzione rapida

1. Vai su **Release** e scarica l'ultimo pacchetto di distribuzione della **Huaxue Edition**: `gtr_deploy_package_v1.19.zip`
2. Estrai `addons/` e copia sopra la directory `cstrike/` del server
3. Configura MySQL seguendo `部署说明.txt` (per il database skin servono tabelle da creare al primo avvio)
4. Riavvia il server / cambia mappa, verifica con `amxx plugins` in console che non ci siano failed
5. Dopo l'ingresso del giocatore, il titolo del menu principale `/menu` deve mostrare **Hide'And'Seek**

> Per la distribuzione dettagliata vedi `10_交接与文档/` e le note della Release.

---

## 7. Stack tecnologico

| Componente | Descrizione |
|---|---|
| Motore | CS 1.6 / ReHLDS / ReGameDLL |
| Piattaforma | AMX Mod X 1.10 (amxxpc 1.10.0.5479) |
| Base | OpenHNS Match System 2.0.5 |
| Database | MySQL (HnsMatchSql) + nvault (fallback offline) |
| Estensioni | ReAPI, HamSandwich, MixSystem |
| Sviluppo proprietario | Iscrizione AI / sponsor / gestione skin / persistenza tra mappe / 4 lingue |

---

## 8. Note sul copyright

- **Plugin della famiglia OpenHNS** (HnsMatchSystem / Bans / Maps / Stats ecc.): copyright degli autori originali
  (OpenHNS / Garey / Cultura ecc.), licenza open source tipo MIT.
- **Estensioni proprietarie GTR** (iscrizione AI, sponsor, gestione skin, storage tra le mappe, localizzazione ecc.): sviluppate come estensione del motore sopra citato.
- **Pacchetti di plugin di terze parti** (SEM / rtv / FreshBans ecc.): copyright dei rispettivi autori, fonte: sito russo dream-x.ru.
- **Materiali delle skin** (models / sounds / texture): copyright non dichiarato, verifica autonomamente prima dell'uso commerciale.
- Benvenuti Fork / PR / Issue, basta citare la fonte.

---

## 9. Versioni multilingue

- [简体中文](README.md)
- [繁體中文](README_ZH-TW.md)
- [English](README_EN.md)
- [Deutsch](README_DE.md)
- [Русский](README_RU.md)
- [Italiano](README_IT.md)
- [Türkçe](README_TR.md)
- [Français](README_FR.md)

---

<div align="center">

![声明](https://img.shields.io/badge/declaration-%E4%B8%80%E5%88%87%E8%A7%A3%E9%87%8A%E6%9D%83%E5%BD%92%20LINNA%20%E6%89%80%E6%9C%89%EF%BC%8CGTRhns%20%E5%B0%86%E6%9C%8D%E5%8A%A1%E4%BA%8E%E6%AF%8F%E4%B8%80%E4%B8%AA%E4%BA%BA%E3%80%82-red)

<b>Tutti i diritti di interpretazione appartengono a LINNA. GTRhns servirà tutti.</b>

</div>
