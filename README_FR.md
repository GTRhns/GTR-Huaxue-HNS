# 🎮 Système de plugins GTR HNS pour matchs · Huaxue Edition

<p align="center">
  <img src="assets/banner.jpg" alt="华雪版封面" width="480">
</p>

<div align="center">

[![AMX Mod X](https://img.shields.io/badge/AMX_Mod_X-1.10-blue)]()
[![ReGameDLL](https://img.shields.io/badge/ReGameDLL-5.x-orange)]()
[![Version](https://img.shields.io/badge/Version-v1.18-green)]()
[![Storage](https://img.shields.io/badge/Storage-PDS_%2B_MySQL-9cf)]()
[![Language](https://img.shields.io/badge/Language-4_Languages-ff69b4)]()
[![License](https://img.shields.io/badge/License-GPLv3-success)]()

</div>

**🌐 Language / 语言:** [简体中文](README.md) · [繁體中文](README_ZH-TW.md) · [English](README_EN.md) · [Deutsch](README_DE.md) · [Русский](README_RU.md) · [Italiano](README_IT.md) · [Türkçe](README_TR.md) · [Français](README_FR.md)

> **Développé à partir du moteur de matchs OpenHNS, avec de nombreuses fonctionnalités développées par l'équipe GTR**
> Compatible : CS 1.6 / ReHLDS / AMX Mod X 1.10
> Version actuelle : **Huaxue Edition v1.18** (tag : `huaxue-v1.18`) · version du 2026-10-01

---

## 📌 Table des matières

- [1. Présentation du projet](#1-présentation-du-projet)
- [2. Nouveau vs ancien : quelles différences](#2-nouveau-vs-ancien-quelles-différences)
- [3. Points forts de la Huaxue Edition v1.18](#3-points-forts-de-la-huaxue-edition-v118)
- [4. Liste des plugins](#4-liste-des-plugins)
- [5. Structure du dépôt](#5-structure-du-dépôt)
- [6. Déploiement rapide](#6-déploiement-rapide)
- [7. Pile technologique](#7-pile-technologique)
- [8. Droits d'auteur](#8-droits-dauteur)
- [9. Versions multilingues](#9-versions-multilingues)

---

## 1. Présentation du projet

Il s'agit d'un système complet de plugins pour serveurs de matchs HNS (Hide 'n' Seek, cache-cache) sur CS 1.6.

La base provient du projet open source **OpenHNS** (HnsMatchSystem 2.0.5 et son ensemble de plugins officiels).
L'équipe GTR y a ajouté une grande quantité de code maison autour de tout le processus « **inscription → répartition en équipes → choix du mode/carte → début du match → règlement** », formant ainsi un **moteur de matchs GTR** indépendant.

---

## 2. Nouveau vs ancien : quelles différences

### 2.1 Problèmes de l'ancienne version (l'origine des correctifs de ce dépôt)

| # | Problème de l'ancienne version | Comportement réellement constaté par les utilisateurs |
|---|---|---|
| 1 | Menu IA codé en dur en chinois | Après avoir mis `/lang` en anglais, le menu d'inscription IA reste en chinois |
| 2 | Défaut dans le processus de démarrage forcé | Le démarrage forcé envoie les joueurs en spectateur puis « disparaît », sans choisir la carte/le mode |
| 3 | Entrée en jeu via la commande `jointeam` | Bloquée par `blockCmd` ; en mode LOBBY, les joueurs restent bloqués en spectateur |
| 4 | Les participants ne sont pas marqués avant le démarrage | `forceUnmatchedToSpec` dans `mix_start()` renvoie en spectateur tous les joueurs qui viennent d'entrer |
| 5 | Perte totale de l'état lors du changement de carte | Après le changelevel de la carte choisie par l'IA, l'inscription/le mode sont perdus ; le match ne démarre jamais |
| 6 | Démarrage automatique même lors d'un simple changement de carte | L'admin change de carte et le serveur lance lui-même l'inscription, puis clôt automatiquement la liste après 2 minutes |
| 7 | Aucun enregistrement du sponsor pour les rondes sponsorisées | En ronde sponsorisée, personne ne peut indiquer au système « qui est le sponsor » |
| 8 | Élément 7 anormal dans le menu mix | L'élément 7 (mode HNS) « ne se laisse pas cliquer » ; sans `^n` dans la chaîne de langue, il ressemble visuellement à un élément mort |
| 9 | Barre numérique du nombre d'inscrits | Le chat/HUD affiche `012345[6]78910` ; les utilisateurs demandent sa suppression |
| 10 | Le menu d'inscription se ferme au premier clic | Le menu se ferme automatiquement alors qu'on souhaite l'utiliser en continu |

### 2.2 Les améliorations correspondantes dans la nouvelle version (Huaxue Edition v1.18)

| # | Amélioration | Mise en œuvre |
|---|---|---|
| 1 | **Menu IA entièrement multilingue** | Tout passe par `HnsLang_Get(id, key)` ; prend en charge le chinois simplifié/traditionnel, l'anglais et le russe ; réagit en direct à `/lang` |
| 2 | **Refonte du processus d'inscription** | Machine à états `SIGNUP_STATE` : inscription → clôture (tous en spectateur + entrée de 1 joueur par seconde) → choix du mode/carte → début du match |
| 3 | **Entrée en jeu sécurisée via ReAPI** | Utilisation de `rg_set_user_team` (ReAPI) au lieu de `jointeam` ; autorisé en LOBBY/TRAINING ; plus de blocage en spectateur |
| 4 | **Pré-marquage lors du démarrage externe** | Le nouveau native `hns_begin_external_match` marque T/CT comme participants avant le début, corrigeant la deuxième cause du « tous renvoyés en spectateur au démarrage » |
| 5 | **Restauration PDS entre les cartes** | Après le choix de la carte, `PDS_SetCell("ai_pending_start",1)` ; 5 secondes après le retour, le match reprend automatiquement (`taskPendingResume`) |
| 6 | **Pas de démarrage automatique lors d'un simple changement de carte** | Changement de carte non-pending : l'inscription est vidée et le serveur passe en attente ; démarrage manuel par l'admin |
| 7 | **Enregistrement du sponsor** | Après le choix de la carte, le premier VIP/admin en ligne saisit le nom du sponsor dans le chat ; délai de 30 secondes ou `/取消` pour passer |
| 8 | **Menu mix à numérotation fixe** | L'élément 7 est toujours ICGB (grisé et non cliquable hors ronde sponsorisée), l'élément 8 est toujours le menu admin |
| 9 | **Suppression de la barre numérique** | `buildSignupBar()` supprimé ; le HUD n'affiche plus que « Inscription : n/12 » |
| 10 | **Le menu ne se ferme plus après un clic** | Retour au menu principal après une action dans le menu d'inscription, pour une utilisation en continu |
| 11 | **Victoire déterminée par l'équipe logique** | Nouveau native `hns_get_player_match_team` ; le règlement wintime crédite la bonne équipe (v1.18) |
| 12 | **Permissions du menu restreintes** | Taille d'équipe / nouvelle répartition / démarrage forcé visibles et cliquables uniquement pour VIP/admin (v1.18) |
| 13 | **État de mode unique** | L'IA et MatchSystem partagent un seul mode ; restauré avec le reste après un changement de carte, plus de divergence (v1.18) |

### 2.3 Chronologie des versions (plugin principal HnsAISignup)

| Version | Heure | Statut | Description |
|---|---|---|---|
| v1.3 | 09-27 19:12 | Sauvegarde historique | Version avant la correction des équipes (teamfix) |
| v1.5 | 09-27 19:55 | Sauvegarde historique | Version avec correction admin (adminfix) |
| v1.5 | 09-27 20:00 | Sauvegarde historique | Sauvegarde avant la deuxième correction |
| v1.9 | 09-27 22:07 | Sauvegarde historique | Avant les modifications majeures (avant la refonte du processus d'inscription) |
| **v1.17** | 09-30 23:00 | **Version précédente** | Version officielle Huaxue ; toutes les améliorations incluses |
| v1.17+ | 10-01 02:13 | En développement | Ajout de `taskRestorePendingRules` (restauration différée du mode après changement de carte) ; non déployé |
| **v1.18** | 10-01 | **Version déployée actuellement** | Correctif de détermination du vainqueur wintime + restauration du mode après changement de carte + permissions du menu restreintes + état de mode unique |

> Historique complet des versions dans `02_各插件历史版本/` ; chaque version a son propre dossier + description.

---

## 3. Points forts de la Huaxue Edition v1.18

- 🤖 **Système d'inscription IA v1.18** : inscription en un clic avec `/signup`, répartition en équipes, rondes loisir/sponsorisées, vote du mode et des cartes,
  démarrage forcé (testable à 1 joueur), reprise après changement de carte, compteur d'inscrits HUD.
- 🎨 **Système de skins (MySQL)** : skins personnalisés pour les joueurs, achat avec pièces / location / mise à niveau permanente,
  sons de mort aléatoires, gestion via le menu admin `/cpm`.
- 💳 **Sponsoring / système de pièces ICGB** : les rondes sponsorisées enregistrent automatiquement le sponsor ; les pièces sont liées aux skins.
- 🗂 **Persistance entre les cartes (PDS)** : l'état du match n'est pas perdu lors d'un changement de carte ; après le choix de la carte par l'IA, le match reprend automatiquement.
- 🌐 **Localisation en quatre langues** : chinois simplifié / traditionnel / anglais / russe ; menus IA et de match unifiés.
- 🧠 **IA pour les matchs** : quand personne n'est là, un match de test peut démarrer avec 1 joueur ; pas de blocage en spectateur.
- 🛡 **Ordre de chargement stable** : `plugins.ini` fixe déjà l'ordre HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin.
- 🎯 **Correctif de détermination du vainqueur** : le règlement wintime ajoute les points selon l'équipe logique du match ; plus de mauvais joueurs crédités après un changement de camp ou de carte.
- 🔐 **Permissions restreintes** : les actions d'administration (taille d'équipe / nouvelle répartition / démarrage forcé) visibles et cliquables uniquement pour VIP/admin.

---

## 4. Liste des plugins

| Plugin | Version | Fonction |
|---|---|---|
| HnsAISignup | v1.18 | Système d'inscription IA (développement maison central) |
| HnsMatchSystem | 2.0.5+ | Machine à états de match (base OpenHNS + 2 natives : `hns_get_player_match_team` / `hns_get_match_team_cs`) |
| HnsMatchBans | 1.1 | Gestion des bannissements |
| HnsMatchMaps | 4.0.4 | Gestion des cartes |
| HnsMatchStats | 1.1.1 | Statistiques de données |
| HnsMatchPts | 1.1 | Points |
| HnsMatchQuery | 1.0.0 | Consultation des matchs `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | Réglages admin `/adminmenu` |
| HnsMatchSkin | 1.0 | Système de skins (MySQL) |
| HnsMatchSql | 1.1 | Gestion unifiée MySQL |
| HnsLanguage | 1.3.0 | Noyau linguistique à quatre langues |
| HnsPersistentDataStorage | 1.0 | Persistance entre les cartes |
| HnsSponsorLocal | 1.0 | Sponsoring / pièces ICGB |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | Aides aux matchs |

---

## 5. Structure du dépôt

```
01_当前版本_核心源码/        Code source du noyau du plugin déployé actuellement + include + compiled
02_各插件历史版本/           Chaque plugin multi-versions dans son propre dossier, annoté par version
03_开发工作区_scripting/    Espace de travail de développement local + compilateur AMXX
04_服务器部署_cstrike/       Structure complète de déploiement (addons/amxmodx + catégories de plugins tiers)
05_皮肤系统_v1.0完整版/      Pack d'installation complet du système de skins MySQL
06_Beta测试插件包/          5 petits plugins indépendants
07_第三方插件包/            SEM / semiclip / rtv_rus (dream-x.ru)
08_资源文件_asd/           Modèles de skins / sons / textures
09_开发脚本与临时文件/      Produits intermédiaires de la programmation IA (pour comparaison/débogage uniquement)
10_交接与文档/              Journal des modifications, notes de passation, journal de mise à jour
```

---

## 6. Déploiement rapide

1. Rendez-vous dans la section **Release** pour télécharger le pack de déploiement de la **Huaxue Edition** : `gtr_deploy_package_v1.18.zip`
2. Décompressez `addons/` et écrasez le dossier `cstrike/` du serveur
3. Configurez MySQL selon `部署说明.txt` (la première fois, la table des skins doit être créée)
4. Redémarrez le serveur / changez de carte ; vérifiez dans la console `amxx plugins` qu'il n'y a pas de failed
5. Après l'entrée sur le serveur, le menu principal `/menu` affiche le titre **Hide'And'Seek**

> Voir `10_交接与文档/` et la description de la Release pour les détails du déploiement.

---

## 7. Pile technologique

| Composant | Description |
|---|---|
| Moteur | CS 1.6 / ReHLDS / ReGameDLL |
| Plateforme | AMX Mod X 1.10 (amxxpc 1.10.0.5479) |
| Base | OpenHNS Match System 2.0.5 |
| Base de données | MySQL (HnsMatchSql) + nvault (repli hors ligne) |
| Extensions | ReAPI, HamSandwich, MixSystem |
| Développement maison | Inscription IA / sponsoring / reprise des skins / persistance entre les cartes / quatre langues |

---

## 8. Droits d'auteur

- **Famille de plugins OpenHNS** (HnsMatchSystem / Bans / Maps / Stats, etc.) : droits d'auteur aux auteurs originaux
  (OpenHNS / Garey / Cultura, etc.), licence open source de type MIT.
- **Extensions GTR maison** (inscription IA, sponsoring, reprise des skins, stockage entre les cartes, localisation, etc.) : développement basé sur le moteur susmentionné.
- **Packs de plugins tiers** (SEM / rtv / FreshBans, etc.) : droits d'auteur aux auteurs respectifs ; source : site russe dream-x.ru.
- **Matériaux des skins** (models / sounds / textures) : droits d'auteur non précisés ; veuillez vérifier vous-même avant une utilisation commerciale.
- Fork / PR / Issue sont les bienvenus ; il suffit d'indiquer la source.

---

## 9. Versions multilingues

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

<b>Tous les droits d'interprétation appartiennent à LINNA. GTRhns servira chacun.</b>

</div>
