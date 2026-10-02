# 🎮 GTR HNS Match-Plugin-System · Huaxue Edition

<p align="center">
  <img src="assets/banner.jpg" alt="华雪版封面" width="480">
</p>

<div align="center">

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.10-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![Version](https://img.shields.io/badge/Version-v1.17-green)]()
[![Storage](https://img.shields.io/badge/Storage-PDS_%2B_MySQL-9cf)]()
[![Language](https://img.shields.io/badge/Language-4_Languages-ff69b4)]()
[![License](https://img.shields.io/badge/License-GPLv3-success)]()

</div>

**🌐 Language / 语言:** [简体中文](README.md) · [繁體中文](README_ZH-TW.md) · [English](README_EN.md) · [Deutsch](README_DE.md) · [Русский](README_RU.md) · [Italiano](README_IT.md) · [Türkçe](README_TR.md) · [Français](README_FR.md)

> **Basierend auf der OpenHNS-Match-Engine weiterentwickelt, mit vielen selbst entwickelten Funktionen des GTR-Teams**
> Geeignet für: CS 1.6 / ReHLDS / AMX Mod X 1.10
> Aktuelle Version: **Huaxue Edition v1.17** (Tag: `huaxue-v1.17`)

---

## 📌 Inhaltsverzeichnis

- [1. Projektübersicht](#1-projektübersicht)
- [2. Neu vs. Alt: Was hat sich geändert](#2-neu-vs-alt-was-hat-sich-geändert)
- [3. Highlights der Huaxue Edition v1.17](#3-highlights-der-huaxue-edition-v117)
- [4. Plugin-Übersicht](#4-plugin-übersicht)
- [5. Repository-Struktur](#5-repository-struktur)
- [6. Schnelle Bereitstellung](#6-schnelle-bereitstellung)
- [7. Technologie-Stack](#7-technologie-stack)
- [8. Urheberrechtshinweis](#8-urheberrechtshinweis)
- [9. Mehrsprachige Versionen](#9-mehrsprachige-versionen)

---

## 1. Projektübersicht

Dies ist ein vollständiges Plugin-System für CS 1.6 HNS (Hide 'n' Seek, Verstecken und Suchen) Match-Server.

Die Basis stammt aus dem Open-Source-Projekt **OpenHNS** (HnsMatchSystem 2.0.5 und dessen offizielles Plugin-Paket).
Das GTR-Team hat darauf rund um den gesamten Ablauf „**Anmeldung → Gruppierung → Wahl von Modus/Karte → Matchstart → Abrechnung**" umfangreichen eigenen Code eingebracht und so eine unabhängige **GTR-Match-Engine** geschaffen.

---

## 2. Neu vs. Alt: Was hat sich geändert

### 2.1 Probleme der alten Version (Ursprung der hier behobenen Fehler)

| # | Problem der alten Version | Vom Benutzer tatsächlich beobachtetes Verhalten |
|---|---|---|
| 1 | AI-Menü mit fest verdrahtetem Chinesisch | Nachdem `/lang` auf Englisch umgestellt wurde, ist das AI-Anmeldemenü immer noch Chinesisch |
| 2 | Der Ablauf des erzwungenen Matchstarts ist fehlerhaft | Der erzwungene Matchstart schickt die Spieler in die Zuschauerrolle und „verschwindet" dann; Karte/Modus wird nicht gewählt |
| 3 | Einsteigen per `jointeam`-Befehl | Wird von `blockCmd` abgefangen; im LOBBY-Modus bleiben die Spieler in der Zuschauerrolle hängen |
| 4 | Teilnehmer werden vor dem Matchstart nicht markiert | `forceUnmatchedToSpec` in `mix_start()` schickt alle gerade eingestiegenen Spieler zurück in die Zuschauerrolle |
| 5 | Zustand geht beim Kartenwechsel komplett verloren | Nach dem changelevel der von der KI gewählten Karte gehen Anmeldung/Modus komplett verloren; das Match lässt sich nie starten |
| 6 | Automatischer Matchstart auch bei normalem Kartenwechsel | Wechselt der Admin die Karte, startet der Server selbst die Anmeldung und schließt die Gruppe nach 2 Minuten automatisch |
| 7 | Keine Erfassung des Sponsors bei Sponsoring-Runden | In einer Sponsoring-Runde kann niemand dem System mitteilen, „wer der Sponsor ist" |
| 8 | Fehlerhafter Eintrag 7 im mix-Menü | Eintrag 7 (HNS-Modus) lässt sich „nicht anklicken"; ohne `^n` im Sprachstring sieht er optisch wie ein toter Eintrag aus |
| 9 | Zahlenleiste der Anmeldeanzahl | Chat/HUD zeigt `012345[6]78910`; die Benutzer fordern die Entfernung |
| 10 | Anmeldemenü schließt sich nach einem Klick | Das Menü schließt sich automatisch, obwohl man es mehrfach bedienen möchte |

### 2.2 Die Verbesserungen der neuen Version (Huaxue Edition v1.17)

| # | Verbesserung | Umsetzung |
|---|---|---|
| 1 | **AI-Menü in allen Sprachen** | Läuft komplett über `HnsLang_Get(id, key)`; unterstützt vereinfachtes Chinesisch, traditionelles Chinesisch, Englisch und Russisch; reagiert in Echtzeit auf `/lang` |
| 2 | **Anmeldeablauf neu strukturiert** | `SIGNUP_STATE`-Zustandsmaschine: Anmeldung → Gruppenbildung (alle in die Zuschauerrolle, 1 Spieler pro Sekunde steigt ein) → Wahl von Modus/Karte → Matchstart |
| 3 | **Sicherer Einsteig über ReAPI** | Statt `jointeam` wird `rg_set_user_team` (ReAPI) verwendet; in LOBBY/TRAINING freigegeben; kein Hängenbleiben in der Zuschauerrolle |
| 4 | **Vorabmarkierung bei externem Matchstart** | Das neue native `hns_begin_external_match` markiert vor dem Matchstart T/CT als Teilnehmer und behebt damit die zweite Ursache für „alle sofort zurück in die Zuschauerrolle" |
| 5 | **Kartenübergreifende PDS-Wiederherstellung** | Nach der Kartenwahl `PDS_SetCell("ai_pending_start",1)`; 5 Sekunden nach der Rückkehr wird das Match automatisch fortgesetzt (`taskPendingResume`) |
| 6 | **Kein automatischer Matchstart bei normalem Kartenwechsel** | Bei nicht-pending Kartenwechsel: Anmeldung wird geleert, Server geht in Bereitschaft; der Start erfolgt manuell durch den Admin |
| 7 | **Erfassung des Sponsors** | Nach der Kartenwahl gibt der erste online VIP/Admin den Sponsornamen im Chat ein; 30 Sekunden Timeout oder `/取消` überspringt |
| 8 | **mix-Menü mit fester Nummerierung** | Eintrag 7 ist immer ICGB (bei Nicht-Sponsoring-Runden ausgegraut und nicht anklickbar), Eintrag 8 ist immer das Admin-Menü |
| 9 | **Zahlenleisten-UI entfernt** | `buildSignupBar()` entfernt; das HUD zeigt nur noch „Anmeldung: n/12" |
| 10 | **Menü schließt nach Auswahl nicht** | Nach einer Aktion im Anmeldemenü kehrt man zum Hauptmenü zurück, für bequeme Mehrfachbedienung |

### 2.3 Zeitleiste der Versionsentwicklung (HnsAISignup Hauptplugin)

| Version | Zeit | Status | Beschreibung |
|---|---|---|---|
| v1.3 | 09-27 19:12 | Historisches Backup | Version vor der Team-Korrektur (teamfix) |
| v1.5 | 09-27 19:55 | Historisches Backup | Version mit Admin-Korrektur (adminfix) |
| v1.5 | 09-27 20:00 | Historisches Backup | Backup vor der zweiten Korrektur |
| v1.9 | 09-27 22:07 | Historisches Backup | Vor den großen Änderungen (vor der Neustrukturierung des Anmeldeablaufs) |
| **v1.17** | 09-30 23:00 | **Aktuell bereitgestellte Version** | Offizielle Huaxue-Version; alle Verbesserungen umgesetzt |
| v1.17+ | 10-01 02:13 | In Entwicklung | Neu: `taskRestorePendingRules` (verzögerte Wiederherstellung des Modus nach Kartenwechsel); nicht bereitgestellt |

> Vollständige Versionshistorie siehe `02_各插件历史版本/`; jede Version hat einen eigenen Ordner + Beschreibung.

---

## 3. Highlights der Huaxue Edition v1.17

- 🤖 **AI-Anmeldesystem v1.17**: Ein-Klick-Anmeldung mit `/signup`, Gruppenbildung, Freizeit-/Sponsoring-Runden, Abstimmung über Modus und Karten,
  erzwungener Matchstart (auch mit 1 Spieler testbar), Fortsetzung über Kartenwechsel hinweg, HUD-Anmeldezähler.
- 🎨 **Skin-System (MySQL)**: Individuelle Skins für Spieler, Kauf mit Münzen / Miete / dauerhafter Upgrade,
  zufällige Todes-Sounds, Verwaltung über das Admin-Menü `/cpm`.
- 💳 **Sponsoring / ICGB-Münzsystem**: Sponsoring-Runden erfassen den Sponsor automatisch; Münzen sind mit den Skins verknüpft.
- 🗂 **Kartenübergreifende Persistenz (PDS)**: Der Matchzustand geht beim Kartenwechsel nicht verloren; nach der KI-Kartenwahl wird das Match automatisch fortgesetzt.
- 🌐 **Viersprachige Lokalisierung**: Vereinfachtes / Traditionelles Chinesisch / Englisch / Russisch; AI- und Matchmenüs einheitlich.
- 🧠 **KI-Gegner für Matches**: Wenn niemand da ist, kann ein Match mit 1 Spieler zum Testen gestartet werden; kein Hängenbleiben in der Zuschauerrolle.
- 🛡 **Stabile Ladereihenfolge**: In `plugins.ini` ist die Reihenfolge HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin bereits festgelegt.

---

## 4. Plugin-Übersicht

| Plugin | Version | Funktion |
|---|---|---|
| HnsAISignup | v1.17 | AI-Anmeldesystem (Kern-Eigenentwicklung) |
| HnsMatchSystem | 2.0.5 | Match-Zustandsmaschine (OpenHNS-Basis + 3 neue natives) |
| HnsMatchBans | 1.1 | Bannverwaltung |
| HnsMatchMaps | 4.0.4 | Kartenverwaltung |
| HnsMatchStats | 1.1.1 | Datenstatistik |
| HnsMatchPts | 1.1 | Punkte |
| HnsMatchQuery | 1.0.0 | Match-Abfrage `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | Admin-Einstellungen `/adminmenu` |
| HnsMatchSkin | 1.0 | Skin-System (MySQL) |
| HnsMatchSql | 1.1 | Einheitliche MySQL-Verwaltung |
| HnsLanguage | 1.3.0 | Viersprachiger Sprachkern |
| HnsPersistentDataStorage | 1.0 | Kartenübergreifende Persistenz |
| HnsSponsorLocal | 1.0 | Sponsoring / ICGB-Münzen |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | Match-Hilfsfunktionen |

---

## 5. Repository-Struktur

```
01_当前版本_核心源码/        Aktuell bereitgestellter Kern-Plugin-Quellcode + include + compiled
02_各插件历史版本/           Jedes mehrfach versionierte Plugin in einem eigenen Unterordner, nach Version markiert
03_开发工作区_scripting/    Lokaler Entwicklungs-Arbeitsbereich + AMXX-Compiler
04_服务器部署_cstrike/       Vollständige Bereitstellungs-Verzeichnisstruktur (addons/amxmodx + Kategorien der Drittanbieter-Plugins)
05_皮肤系统_v1.0完整版/      Komplettes Installationspaket für das Skin-System MySQL
06_Beta测试插件包/          5 unabhängige kleine Plugins
07_第三方插件包/            SEM / semiclip / rtv_rus (dream-x.ru)
08_资源文件_asd/           Skin-Modelle / Sounds / Texturen
09_开发脚本与临时文件/      Zwischenprodukte der KI-Programmierung (nur zur Fehleranalyse)
10_交接与文档/              Änderungsaufzeichnungen, Übergabehinweise, Update-Log
```

---

## 6. Schnelle Bereitstellung

1. Lade in der **Release**-Sektion das neueste Bereitstellungspaket der **Huaxue Edition** herunter: `gtr_deploy_package_v1.17.zip`
2. Entpacke `addons/` und überschreibe damit das `cstrike/`-Verzeichnis auf dem Server
3. Konfiguriere MySQL gemäß `部署说明.txt` (beim ersten Mal muss die Skin-Datenbanktabelle erstellt werden)
4. Starte den Server neu / wechsle die Karte; prüfe in der Konsole mit `amxx plugins`, dass keine failed auftreten
5. Nach dem Betreten des Servers zeigt das Hauptmenü `/menu` den Titel **Hide'And'Seek**

> Detaillierte Bereitstellung siehe `10_交接与文档/` und die Release-Beschreibung.

---

## 7. Technologie-Stack

| Komponente | Beschreibung |
|---|---|
| Engine | CS 1.6 / ReHLDS / ReGameDLL |
| Plattform | AMX Mod X 1.10 (amxxpc 1.10.0.5479) |
| Basis | OpenHNS Match System 2.0.5 |
| Datenbank | MySQL (HnsMatchSql) + nvault (Offline-Fallback) |
| Erweiterungen | ReAPI, HamSandwich, MixSystem |
| Eigene Entwicklung | AI-Anmeldung / Sponsoring / Skin-Übernahme / kartenübergreifende Persistenz / viersprachig |

---

## 8. Urheberrechtshinweis

- **OpenHNS-Plugin-Familie** (HnsMatchSystem / Bans / Maps / Stats usw.): Urheberrecht bei den ursprünglichen Autoren
  (OpenHNS / Garey / Cultura usw.), MIT-ähnliche Open-Source-Lizenz.
- **GTR-Eigenentwicklungen** (AI-Anmeldung, Sponsoring, Skin-Übernahme, kartenübergreifende Speicherung, Lokalisierung usw.): Weiterentwicklung auf Basis der oben genannten Engine.
- **Drittanbieter-Plugin-Pakete** (SEM / rtv / FreshBans usw.): Urheberrecht bei den jeweiligen Autoren; Quelle: russische Seite dream-x.ru.
- **Skin-Materialien** (models / sounds / Texturen): Urheberrecht nicht angegeben; vor kommerzieller Nutzung bitte selbst klären.
- Fork / PR / Issue sind willkommen; bitte die Quelle angeben.

---

## 9. Mehrsprachige Versionen

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

<b>Alle Rechte der Auslegung liegen bei LINNA. GTRhns wird jeden bedienen.</b>

</div>
