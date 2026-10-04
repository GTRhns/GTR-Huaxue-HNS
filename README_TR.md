# 🎮 GTR HNS Maç Eklenti Sistemi · Huaxue Sürümü

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

> **OpenHNS maç motoru temel alınarak geliştirilmiş, GTR ekibinin çok sayıda özgün özelliğiyle birleştirilmiştir**
> Uyumluluk: CS 1.6 / ReHLDS / AMX Mod X 1.10
> Güncel sürüm: **Huaxue Sürümü v1.19** (etiket: `huaxue-v1.19`) · 2026-10-01 sürümü

---

## 📌 İçindekiler

- [1. Proje Tanıtımı](#1-proje-tanıtımı)
- [2. Yeni Sürüm vs Eski Sürüm: Farklar](#2-yeni-surum-vs-eski-surum-farklar)
- [3. Huaxue Sürümü v1.19'in Öne Çıkanları](#3-huaxue-surumu-v118in-one-cikanlari)
- [4. Eklenti Listesi](#4-eklenti-listesi)
- [5. Depo Yapısı](#5-depo-yapisi)
- [6. Hızlı Dağıtım](#6-hizli-dagitim)
- [7. Teknoloji Yığını](#7-teknoloji-yigini)
- [8. Telif Hakkı Açıklaması](#8-telif-hakkı-aciklamasi)
- [9. Çok Dilli Sürümler](#9-cok-dilli-surumler)

---

## 1. Proje Tanıtımı

Bu, CS 1.6 HNS (Hide 'n' Seek, saklambaç) maç sunucuları için eksiksiz bir eklenti sistemidir.

Temel, açık kaynaklı **OpenHNS** projesinden (HnsMatchSystem 2.0.5 ve resmî eklenti seti) gelir;
GTR ekibi bunun üzerine «**kayıt → takım oluşturma → mod/harita seçimi → maç başlatma → sonuçlandırma**» sürecinin tamamına
çok sayıda özgün kod ekleyerek bağımsız **GTR özgün maç motorunu** oluşturmuştur.

---

## 2. Yeni Sürüm vs Eski Sürüm: Farklar

### 2.1 Eski sürümün sorunları (bu depoda giderilen kök nedenler)

| # | Eski sürüm sorunu | Kullanıcıların gerçekte karşılaştığı durum |
|---|---|---|
| 1 | AI menüsünde koda gömülü Çince | `/lang` İngilizceye alınınca AI kayıt menüsü yine Çince kalıyor |
| 2 | Zorla maç başlatma akışı hatalı | Zorla başlatma oyuncuları spec'e atıp "kayboluyor": harita/mod seçilmiyor |
| 3 | Maça `jointeam` komutuyla çıkma | `blockCmd` tarafından engelleniyor, LOBBY modunda oyuncular spec'te takılı kalıyor |
| 4 | Maç öncesi katılımcılar işaretlenmiyor | `mix_start()` içindeki `forceUnmatchedToSpec` yeni maça çıkanları tekrar spec'e atıyor |
| 5 | Harita değişince tüm durum kayboluyor | AI harita seçip changelevel yapınca kayıt/mod tamamen kayboluyor, maç hiç başlayamıyor |
| 6 | Normal harita değişimi de maç başlatıyor | Admin harita değiştirince sunucu kendiliğinden kayıt başlatıyor, 2 dakika sonra takımları topluyor |
| 7 | Sponsorlu maçta sponsor kaydı yok | Sponsorlu maç açılıyor ama kimse sisteme "sponsor kim" diyemiyor |
| 8 | Mix menüsü 7. maddesi hatalı | 7. madde (HNS modu) "tıklanmıyor": dil dizgisinde `^n` yok, ölü madde gibi görünüyor |
| 9 | Kayıt sayısı şeridi | Sohbet/HUD'da `012345[6]78910` görünüyor, kullanıcılar kaldırılmasını istedi |
| 10 | Kayıt menüsü bir tıkta kapanıyor | Menüde sürekli işlem yapılmak isteniyor ama menü kendiliğinden kapanıyor |

### 2.2 Yeni sürümdeki (Huaxue Sürümü v1.19) karşılık gelen iyileştirmeler

| # | İyileştirme | Uygulama şekli |
|---|---|---|
| 1 | **AI menüsü tamamen çok dilli** | Tamamı `HnsLang_Get(id, key)` üzerinden; basitleştirilmiş/geleneksel Çince, İngilizce, Rusça olmak üzere 4 dil, `/lang` ile gerçek zamanlı senkronize |
| 2 | **Kayıt akışı yeniden yapılandırıldı** | `SIGNUP_STATE` durum makinesi: kayıt → takım toplama (herkes spec + saniyede 1 oyuncu maça) → mod/harita seçimi → maç başlatma |
| 3 | **ReAPI ile güvenli maça çıkış** | `jointeam` yerine `rg_set_user_team` (ReAPI) kullanılıyor; LOBBY/TRAINING'de serbest, spec'te takılma önlendi |
| 4 | **Harici maç başlatmada ön işaretleme** | Yeni native `hns_begin_external_match` maçtan önce T/CT'yi katılımcı olarak işaretliyor; "maç anında herkesin spec'e dönmesi" sorununun ikinci kök nedenini çözer |
| 5 | **Haritalar arası PDS kurtarma** | Harita seçilince `PDS_SetCell("ai_pending_start",1)`; harita değişip geri dönünce maç 5 saniye içinde otomatik devam eder (`taskPendingResume`) |
| 6 | **Normal harita değişimi artık maç başlatmıyor** | Pending olmayan harita değişimi: kayıt temizlenir, sunucu beklemede, maçı admin elle başlatır |
| 7 | **Sponsorlu maçta sponsor kaydı** | Harita seçildikten sonra ilk çevrimiçi VIP/admin sohbete sponsor adını yazar; 30 saniye zaman aşımı veya `/取消` ile atlanır |
| 8 | **Mix menüsünde sabit numaralandırma** | 7. madde her zaman ICGB (sponsorlu maç yoksa gri ve tıklanamaz), 8. madde her zaman admin menüsü |
| 9 | **Sayı şeridi arayüzü kaldırıldı** | `buildSignupBar()` silindi, HUD yalnızca `报名: n/12` gösterir |
| 10 | **Menü tıklamadan sonra kapanmıyor** | Kayıt menüsünde işlem sonrası ana menüye dönülür, kesintisiz işlem için |
| 11 | **Kazananın mantıksal takıma göre belirlenmesi** | Yeni native `hns_get_player_match_team`; wintime hesaplaması doğru takıma puan ekler (v1.19) |
| 12 | **Menü izinlerinin daraltılması** | Takım boyutu / yeniden gruplama / zorla başlatma yalnızca VIP/admin tarafından görülebilir ve tıklanabilir (v1.19) |
| 13 | **Tek maç modu durumu** | AI ve MatchSystem aynı maç modunu paylaşır; harita değişince modla birlikte geri yüklenir, çatallanma önlendi (v1.19) |

### 2.3 Sürüm geçmişi zaman çizelgesi (HnsAISignup ana eklentisi)

| Sürüm | Zaman | Durum | Açıklama |
|---|---|---|---|
| v1.3 | 09-27 19:12 | Tarihî yedek | Takım düzeltmesinden (teamfix) önceki sürüm |
| v1.5 | 09-27 19:55 | Tarihî yedek | Admin düzeltmeli (adminfix) sürüm |
| v1.5 | 09-27 20:00 | Tarihî yedek | İkinci düzeltmeden önceki yedek |
| v1.9 | 09-27 22:07 | Tarihî yedek | Büyük değişikliklerden önce (kayıt akışı yeniden yapılandırılmadan önce) |
| **v1.17** | 09-30 23:00 | **Önceki sürüm** | Huaxue Sürümü resmî sürümü, tüm iyileştirmeler uygulandı |
| v1.17+ | 10-01 02:13 | Geliştiriliyor | `taskRestorePendingRules` eklendi (harita değişiminden sonra modu gecikmeli geri yükleme), dağıtılmadı |
| **v1.19** | 10-01 | **Güncel dağıtılan sürüm** | wintime kazanan belirleme düzeltmesi + harita değişiminde modun geri yüklenmesi + menü izinlerinin daraltılması + tek maç modu durumu |

> Tam sürüm geçmişi `02_各插件历史版本/` içindedir; her sürümün ayrı klasörü + açıklaması vardır.

---

## 3. Huaxue Sürümü v1.19'in Öne Çıkanları

- 🤖 **AI kayıt sistemi v1.19**: `/signup` tek tıkla kayıt, takım toplama ve gruplama, eğlence/sponsorlu maçlar, mod ve harita oylaması,
  zorla maç başlatma (1 kişiyle test edilebilir), harita değişince maçı sürdürme, HUD kayıt sayacı.
- 🎨 **Skin sistemi (MySQL)**: oyuncuya özel skinler, jetonla satın alma / kiralama / kalıcı yükseltme,
  rastgele ölüm sesleri, admin `/cpm` menüsünden yönetim.
- 💳 **Sponsorluk / ICGB jeton sistemi**: sponsorlu maçlarda sponsor otomatik kaydedilir, jetonlar skinlerle bağlantılıdır.
- 🗂 **Haritalar arası kalıcılık (PDS)**: harita değişince maç durumu kaybolmaz, AI harita seçtikten sonra maç otomatik devam eder.
- 🌐 **4 dilde yerelleştirme**: Basitleştirilmiş / Geleneksel Çince / English / Русский, AI menüsü ve maç menüsü tek tip.
- 🧠 **AI maç botları**: kimse yokken 1 kişiyle maç test edilebilir, spec'te takılmaz.
- 🛡 **Kararlı yükleme sırası**: `plugins.ini` içinde sıra hazır: HnsLanguage → PDS → Sponsor → MatchSystem → … → AISignup → Skin.
- 🎯 **Kazanan belirleme düzeltmesi**: wintime hesaplaması puanları mantıksal maç takımına ekler; taraf/harita değişiminde artık yanlış oyunculara puan eklenmez.
- 🔐 **İzinlerin daraltılması**: yönetim işlemleri (takım boyutu / yeniden gruplama / zorla başlatma) yalnızca VIP/admin tarafından görülebilir ve tıklanabilir.

---

## 4. Eklenti Listesi

| Eklenti | Sürüm | İşlev |
|---|---|---|
| HnsAISignup | v1.19 | AI kayıt sistemi (temel özgün geliştirme) |
| HnsMatchSystem | 2.0.5+ | Maç durum makinesi (OpenHNS tabanı + 2 yeni native: `hns_get_player_match_team` / `hns_get_match_team_cs`) |
| HnsMatchBans | 1.1 | Yasaklama yönetimi |
| HnsMatchMaps | 4.0.4 | Harita yönetimi |
| HnsMatchStats | 1.1.1 | İstatistikler |
| HnsMatchPts | 1.1 | Puanlar |
| HnsMatchQuery | 1.0.0 | Maç sorgulama `/hnsquery` |
| HnsMatchAdmin | 1.0.0 | Admin ayarları `/adminmenu` |
| HnsMatchSkin | 1.0 | Skin sistemi (MySQL) |
| HnsMatchSql | 1.1 | MySQL birleşik yönetimi |
| HnsLanguage | 1.3.0 | 4 dilli dil çekirdeği |
| HnsPersistentDataStorage | 1.0 | Haritalar arası kalıcılık |
| HnsSponsorLocal | 1.0 | Sponsorluk / ICGB jetonları |
| HnsMatchTraining / Watcher / Pause / Recontrol / Ownage / Chatmanager / MapRules / PlayerInfo | … | Maç yardımcıları |

---

## 5. Depo Yapısı

```
01_当前版本_核心源码/       güncel dağıtılan sürümün çekirdek eklenti kaynakları + include + compiled
02_各插件历史版本/          her çok sürümlü eklenti ayrı klasörde, sürüme göre işaretli
03_开发工作区_scripting/    yerel geliştirme çalışma alanı + AMXX derleyicisi
04_服务器部署_cstrike/      eksiksiz dağıtım dizin yapısı (addons/amxmodx + üçüncü taraf eklenti sınıflandırması)
05_皮肤系统_v1.0完整版/     skin sistemi MySQL eksiksiz kurulum paketi
06_Beta测试插件包/          5 bağımsız küçük eklenti
07_第三方插件包/            SEM / semiclip / rtv_rus (dream-x.ru)
08_资源文件_asd/            skin modelleri / sesler / doku materyalleri
10_交接与文档/              değişiklik kayıtları, devir notları, güncelleme günlüğü
```

---

## 6. Hızlı Dağıtım

1. **Release** bölümüne gidip en son **Huaxue Sürümü** dağıtım paketini indirin: `gtr_deploy_package_v1.19.zip`
2. `addons/` klasörünü açıp sunucunun `cstrike/` dizininin üzerine yazın
3. `部署说明.txt` talimatına göre MySQL'i yapılandırın (skin veritabanı için ilk açılışta tablo oluşturulmalı)
4. Sunucuyu yeniden başlatın / harita değiştirin, konsolda `amxx plugins` ile failed olmadığını doğrulayın
5. Oyuncu sunucuya girince `/menu` ana menü başlığı **Hide'And'Seek** göstermeli

> Ayrıntılı dağıtım için `10_交接与文档/` ve Release açıklamalarına bakın.

---

## 7. Teknoloji Yığını

| Bileşen | Açıklama |
|---|---|
| Motor | CS 1.6 / ReHLDS / ReGameDLL |
| Platform | AMX Mod X 1.10 (amxxpc 1.10.0.5479) |
| Taban | OpenHNS Match System 2.0.5 |
| Veritabanı | MySQL (HnsMatchSql) + nvault (çevrimdışı yedek) |
| Uzantılar | ReAPI, HamSandwich, MixSystem |
| Özgün geliştirmeler | AI kayıt / sponsorluk / skin yönetimi / haritalar arası kalıcılık / 4 dil |

---

## 8. Telif Hakkı Açıklaması

- **OpenHNS ailesi eklentileri** (HnsMatchSystem / Bans / Maps / Stats vb.): telif hakkı özgün yazarlara aittir
  (OpenHNS / Garey / Cultura vb.), MIT benzeri açık kaynak lisansı.
- **GTR özgün uzantıları** (AI kayıt, sponsorluk, skin yönetimi, haritalar arası depolama, dil desteği vb.): yukarıdaki motor temel alınarak geliştirilmiştir.
- **Üçüncü taraf eklenti paketleri** (SEM / rtv / FreshBans vb.): telif hakkı ilgili yazarlara aittir, kaynak: Rus sitesi dream-x.ru.
- **Skin materyalleri** (models / sounds / dokular): telif hakkı belirtilmemiş, ticari kullanımdan önce kendiniz doğrulayın.
- Fork / PR / Issue açmaktan çekinmeyin, kaynağı belirtmeniz yeterli.

---

## 9. Çok Dilli Sürümler

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

<b>Tüm yorum hakları LINNA'ya aittir. GTRhns herkese hizmet edecektir.</b>

</div>
