# PROJE ÖZETİ — Local Drop (local_drop)
<!-- OZET_META: guncelleme=2026-10-09 20:43 | son_kod_commit=(F2 commit'i, hash §12'de düzeltilecek) | faz=F2 tamam, F3 bekliyor -->

> **TEK GİRİŞ NOKTASI.** Durum, analiz ve iş başlangıcı buradan yapılır; kodu TARAMA.
> İş kuralları: `docs/AJAN_IS.md` · Analiz: `docs/AJAN_ANALIZ.md` · Faz görevleri ve test senaryoları: `docs/FAZLAR.md` (yalnız ilgili `## F<n>` başlığı okunur).

---

## 0. UCUZ ANALİZ PROTOKOLÜ (ZORUNLU)

1. Bu dosyayı oku (tek kez). Kod okuma YOK.
2. BASE = özete dokunan son commit (her kod commit'i özeti de içerir):
   ```powershell
   $B = git log -1 --format=%h -- docs/PROJE_OZET.md
   git log --oneline "$B..HEAD"; git status --short
   ```
   İkisi de boş → analiz = §8 + §9. DUR.
3. Dolu → `git diff --stat "$B..HEAD"` → yalnız değişen hunk'lar okunur. Sonra bu farklar özete işlenir.
4. Şüphe doğrulama: Grep + ±20 satır. >400 satırlık dosya baştan okunmaz (boyutlar §3).
5. Repo yoksa (F0 öncesi) bu adım atlanır.

**GÜNCELLEME KURALI:** Okuma/analiz dahil HER işin sonunda AJAN_IS §6 uygulanır. Bu dosya eski kopyadan baştan YAZILMAZ; o an okunur, Edit ile değiştirilir. Özet, kodla aynı commit'e girer.

---

## 1. Uygulama

Flutter (Dart, null safety) **Android** uygulaması. Telefon, uygulamanın içinde `shelf` ile bir HTTP sunucusu açar. Aynı Wi-Fi'deki bilgisayar, tarayıcıdan QR'daki adrese girer ve dosya yükler/indirir, metin gönderir. İnternet ve üçüncü taraf sunucu yok.
Paket adı: `local_drop` · applicationId: F8'de `com.ismail.localdrop` · Dart SDK ^3.13.1 (dot-shorthand var).
Branch: `dev` (push YOK).

Bağımlılıklar (mevcut): shelf, shelf_router, shelf_multipart (2.x — API 1.x'ten farklı, lock'taki sürüme göre yaz), network_info_plus, qr_flutter, path_provider, provider ^6.1.5+1.
Planlanan: open_filex + share_plus + file_picker (F5), foreground task + wakelock (F6).

## 2. Mimari (hedef)

```
lib/
  main.dart, app.dart
  core/      constants.dart (§5 sabitleri), log.dart, errors.dart, utils (safe_name, format)
  services/  network_service (IP), server_service (shelf yaşam döngüsü), storage_service (kök klasör, resolve)
  server/    router.dart, handlers/ (files, upload, download, text), auth_middleware, rate_limiter, web_ui.dart (const HTML)
  state/     server_controller.dart (ChangeNotifier — UI'nin TEK durum kaynağı)
  ui/        screens/, widgets/
```
- UI yalnız `ServerController`'ı okur; servisleri doğrudan çağırmaz.
- Sunucu → UI olayları: `Stream<ServerEvent>` (uploaded, deleted, textReceived, error).
- Tüm dosya sistemi yolları `StorageService.resolve(name)` üzerinden; kök dışına çıkan yol = istisna.

## 3. Dosya haritası

| Dosya | Satır | Görev |
|---|---|---|
| lib/main.dart | 15 | runApp + ChangeNotifierProvider<ServerController(network: NetworkService())> |
| lib/app.dart | 29 | LocalDropApp: MaterialApp, M3, seed teal, light/dark |
| lib/core/constants.dart | 41 | AppConstants (§5) |
| lib/core/lan_ip.dart | 42 | IfaceAddress record; saf `pickLanIp(list, preferred:)` |
| lib/core/log.dart | 20 | Log.d (kDebugMode), Log.mask |
| lib/services/network_service.dart | 91 | sealed NetworkResult (Connected/NoNetwork); NetworkService.current()/watch() (distinct, enjekte edilebilir kaynaklar) |
| lib/state/server_controller.dart | 56 | ServerStatus; status/url/pin/errorMessage; network + canStart (watch dinler); start/stop stub |
| lib/ui/screens/home_screen.dart | 40 | "Sunucu kapalı" + ağ metni (IP / Ağ bağlantısı yok) + Başlat (ağ yoksa pasif) |
| test/ui/home_screen_test.dart | 64 | widget (FakeNetworkService): başlık, NoNetwork→pasif, Connected→IP |
| test/unit/pick_lan_ip_test.dart | 64 | IP seçimi (9) |
| test/unit/network_service_test.dart | 35 | watch distinct, getWifiIP hata fallback |
| test/unit/log_test.dart | 12 | mask |

## 4. Değişmez kurallar

- Ağ: yalnız yerel ağdan GELEN istekler. Uygulama dışarıya istek ATMAZ (analytics/CDN/telemetri yok).
- Her route token ister (`?t=` veya cookie). Karşılaştırma sabit zamanlı. Token loga maskeli yazılır (`ab**`).
- Upload RAM'e alınmaz: stream → `<ad>.part` → bitince rename. Yarıda kalırsa `.part` silinir.
- Dosya adları yalnız `safeName()` ile temizlenir; yol birleştirme yalnız `StorageService.resolve()` ile yapılır.
- Web UI tek dosya; harici CDN/font YOK; kullanıcı verisi yalnız `textContent` ile basılır.
- State: yalnız Provider. Başka state paketi yok.
- Async sonrası `context.mounted`; kullanıcıya Türkçe SnackBar, ayrıntı `[LD/<alan>]` loguna.
- Platform hedefi yalnız Android; ios/macos/linux/windows/web klasörlerine dokunulmaz.
- GIT: `git add -A` / `git add .` / `git commit -a` YASAK.

## 5. Kritik sabitler (core/constants.dart)

| Konu | Değer |
|---|---|
| Port aralığı | 8080 → 8090 (ilk boş olan) |
| Bind | 0.0.0.0 |
| Token | 16 karakter, Random.secure, base62; her start'ta yeni |
| PIN | 6 hane, token'dan bağımsız üretilir; yalnız QR okutulamazsa elle giriş (`/login`) |
| Tek dosya limiti | 4 GB |
| Yanlış token limiti | IP başına 10 / dk → 429 |
| Ağ yoklama | 3 sn |
| Mobil arayüz işaretleri | `rmnet`, `ccmni` (ad içinde geçerse elenir) |
| Kısmi dosya uzantısı | `.part` |
| Log öneki | `[LD/<alan>]` (debugPrint, yalnız kDebugMode) |

## 6. Özellik durumu

| Özellik | Kod | Test | Cihazda |
|---|---|---|---|
| İskelet + Provider (F1) | ✅ | ✅ | ⏳ |
| IP tespiti (F2) | ✅ | ✅ | ⏳ |
| HTTP sunucu + token (F3) | ⏳ | ⏳ | ⏳ |
| Web arayüzü (F4) | ⏳ | ⏳ | ⏳ |
| Mobil arayüz (F5) | ⏳ | ⏳ | ⏳ |
| Arka plan + depolama (F6) | ⏳ | ⏳ | ⏳ |
| Sertleştirme (F7) | ⏳ | ⏳ | ⏳ |
| Yayın hazırlığı (F8) | ⏳ | ⏳ | ⏳ |

## 7. Alınmış kararlar

- K1: Hedef yalnız Android (iOS Local Network izni ve arka plan kısıtı kapsam dışı).
- K2: Provider (ChangeNotifier); Riverpod/GetX yok.
- K3: Token zorunlu; QR'a gömülü. PIN yalnız QR okutulamayan durum için.
- K4: Alınan dosyalar F3–F5'te uygulama klasöründe; F6'da Download/LocalDrop (MediaStore). MANAGE_EXTERNAL_STORAGE kullanılmaz.
- K6: IP kaynağı = `NetworkInterface.list` (arayüz adıyla); `getWifiIP()` yalnız `preferred` ipucu. Neden: getWifiIP konum izni istemiyor ama Android 12+'da aktif ağı (Wi-Fi kapalıyken mobil veri) döndürüyor; arayüz adı olmadan mobil veri elenemez. Konum izni istenmez.
- K5 (F6'da kesinleşecek): FGS türü adayı `dataSync` (Android 15 süre limiti → onTimeout'ta sunucu kapanır + bildirim).

## 8. AÇIK BULGULAR (S-n: şüphe, B-n: doğrulanmış)

- S1 🟢 `usesCleartextTraffic="true"` global açık. Gelen sunucu trafiğini etkilemez; gereksizse F6'da kaldırılacak.

## 9. CİHAZDA BEKLEYEN DOĞRULAMALAR

(Her faz kendi maddelerini FAZLAR.md "Cihaz" bölümünden buraya ekler; doğrulanınca silinir.)

1. F1: Uygulama açılıyor, Local Drop başlığı ve Başlat butonu görünüyor.
2. F2: Wi-Fi açık → ekranda `IP: 192.168.x.x`; log `[LD/Net] ip=192.168...`.
3. F2: Wi-Fi kapat → ≤3 sn içinde "Ağ bağlantısı yok", Başlat pasif; log `[LD/Net] no-network`.
4. F2: Hotspot aç (Wi-Fi kapalı) → 192.168.43.1 benzeri adres (MIUI'de farklı alt ağ olabilir).

## 10. COMMIT GÜNLÜĞÜ (eski → yeni)

| Commit | Faz | Özet |
|---|---|---|
| b52ff2e | F0 | chore: ilk commit + ajan dokumanlari (repo, dev branch, .gitignore) |
| e3e5df7, 6582d22 | — | GitHub main birleştirme (README 1 satır) |
| 1375142 | F1 | feat(app): iskelet, Provider, sabitler, log (origin/dev'e push edildi) |
| (bu commit) | F2 | feat(net): IP tespiti + ağ durumu akışı |

## 11. Ortam / cihaz notları

- Test cihazı: Xiaomi Mi 11 (MIUI). "USB üzerinden yükle" açık olmalı.
- adb: `C:\Android\sdk\platform-tools\adb.exe`
- Verileri silmeden kurulum: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- Log: `adb logcat -s flutter | Select-String "\[LD/"`
- PC ve telefon aynı Wi-Fi'de olmalı. Windows Güvenlik Duvarı giden trafiği engellemez; misafir ağlarda "client isolation" bağlantıyı keser (hata değil, ortam).
- MIUI: Otomatik başlatma açık + pil "Kısıtlama yok" (F6 testleri için).

## 12. İŞLEM GÜNLÜĞÜ (her iş 1 satır, en yeni altta)
<!-- format: YYYY-MM-DD HH:mm | hash/commitlenmedi | iş | kod: dosyalar | test: dosyalar | analyze/test | sonuç -->
<!-- 2026-10-09 20:40 | commitlenmedi | docs/kurulum | kod: yok | özet + AJAN_IS + AJAN_ANALIZ + FAZLAR oluşturuldu -->
<!-- 2026-10-09 20:33 | b52ff2e | F0 repo kurulumu | kod: .gitignore (+imza/ajan satırları), CLAUDE.md (ignore) | test: yok | analyze/test: — | dev branch, ilk commit; platform klasörleri + pubspec.lock + .metadata da (değiştirilmeden) eklendi, temiz ağaç için -->
<!-- 2026-10-09 20:38 | 1375142 | F1 iskelet | kod: main.dart, app.dart, core/constants.dart, core/log.dart, state/server_controller.dart, ui/screens/home_screen.dart, README; widget_test.dart silindi | test: home_screen_test(+1), log_test(+2) | analyze/test: OK | demo kaldırıldı, Provider iskeleti kuruldu -->
<!-- 2026-10-09 20:43 | (bu commit) | F2 ağ servisi | kod: core/lan_ip.dart, services/network_service.dart, state/server_controller.dart, ui/screens/home_screen.dart, core/constants.dart, main.dart | test: pick_lan_ip_test(+9), network_service_test(+2), home_screen_test(+2) | analyze/test: OK (16) | K6 kararı; manifest değişmedi -->
