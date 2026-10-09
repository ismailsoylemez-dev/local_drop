# PROJE ÖZETİ — Local Drop (local_drop)
<!-- OZET_META: guncelleme=2026-10-09 21:17 | son_kod_commit=(F5 commit'i, hash §12'de düzeltilecek) | faz=F5 tamam, F6 bekliyor -->

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

Bağımlılıklar (mevcut): shelf, shelf_router, shelf_multipart (2.x — API 1.x'ten farklı, lock'taki sürüme göre yaz), network_info_plus, qr_flutter, path_provider, provider ^6.1.5+1, open_filex 4.7.0, share_plus 13.3.1, file_picker 13.1.0 (yeni API: `FilePicker.pickFiles()` → `List<PlatformFile>`, `readAsByteStream()`).
Planlanan: foreground task + wakelock (F6).

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
- UI yalnız `ServerController`'ı okur; platform eklentileri (aç/paylaş/seç) `FileActions` (Provider) üzerinden.
- main: `StorageService.appDefault()` await → `ServerController(network, storage)`; ServerFactory = `ServerService Function(StorageService)`.
- Tek paylaşım klasörü: PC'den gelenler + telefondan "Bilgisayara gönder"le eklenenler (ikisi de `/api/files`'ta).
- Sunucu → UI olayları: `Stream<ServerEvent>` (FileUploaded, FileDeleted, TextReceived, ServerErrorEvent) — ServerService.events → ServerController.events.
- İstek hattı: securityHeaders (her yanıta CSP + nosniff) → errorMiddleware (500 JSON) → authMiddleware (`?t=`/cookie; `/login` muaf; tokensız `GET /` → 302 /login) → shelf_router.
- Upload: `_BodyGuard` gövdeyi izler; bağlantı koparsa aktif parça hatayla kapanır (mime 2.1.0 bunu yapmıyor, yoksa `.part` asılı kalır).
- Geçici dosya: `.<ad>.part` (safeName noktayla başlamaz → gerçek adla çakışmaz). Eşzamanlı aynı ad: `StorageService.reserveUnique`.
- Tüm dosya sistemi yolları `StorageService.resolve(name)` üzerinden; kök dışına çıkan yol = istisna.

## 3. Dosya haritası

| Dosya | Satır | Görev |
|---|---|---|
| lib/main.dart | 25 | storage await; MultiProvider(FileActions, ServerController) |
| lib/app.dart | 29 | LocalDropApp: MaterialApp, M3, seed teal, light/dark |
| lib/core/constants.dart | 61 | AppConstants (§5) |
| lib/core/format.dart | 23 | formatSize (web UI JS ile aynı), formatDate `gg.aa.yyyy ss:dd` |
| lib/core/errors.dart | 26 | ServerStartException, PathEscapeException, FileTooLargeException |
| lib/core/safe_name.dart | 46 | safeName, splitExtension, uniqueName (saf) |
| lib/core/secrets.dart | 32 | generateToken, generatePin, constantTimeEquals |
| lib/core/lan_ip.dart | 42 | IfaceAddress record; saf `pickLanIp(list, preferred:)` |
| lib/core/log.dart | 20 | Log.d (kDebugMode), Log.mask |
| lib/server/responses.dart | 15 | jsonOk/jsonError, html/json başlıkları |
| lib/server/server_event.dart | 25 | sealed ServerEvent |
| lib/server/auth_middleware.dart | 51 | authMiddleware, tokenCookie, readCookie |
| lib/server/router.dart | 84 | contentSecurityPolicy, securityHeaders, errorMiddleware, buildHandler (route tablosu) |
| lib/server/web_ui.dart | 378 | const webUiHtml: sürükle-bırak, XHR progress/hız/ETA, liste (indir/sil satır içi onay), metin gönder, 401/ağ banner'ı, dark mode, 5 sn liste yenileme; innerHTML 0 |
| lib/server/handlers/text_handler.dart | 62 | POST /api/text: JSON {text}, ≤64 KB (header + akış), TextReceived |
| lib/server/handlers/login_handler.dart | 60 | GET/POST /login (PIN → cookie) |
| lib/server/handlers/files_handler.dart | 74 | list, download (stream, filename*), delete |
| lib/server/handlers/upload_handler.dart | 137 | multipart → storage.saveStream; 413; _BodyGuard |
| lib/services/server_service.dart | 87 | shelf_io.serve, port aralığı, token/PIN, events, stop/dispose |
| lib/services/storage_service.dart | 131 | resolve(strict), reserveUnique, list, saveStream (.part→rename, maxBytes), delete |
| lib/services/file_actions.dart | 36 | open (OpenFilex → TR mesaj), share, pick |
| lib/services/network_service.dart | 91 | sealed NetworkResult (Connected/NoNetwork); NetworkService.current()/watch() (distinct, enjekte edilebilir kaynaklar) |
| lib/state/server_controller.dart | 172 | status/url/pin/network/canStart; files, lastText; start/stop; olay → liste yenile/lastText; deleteFile, importFile, fileFor |
| lib/ui/screens/home_screen.dart | 95 | olay → SnackBar; LayoutBuilder ≥600 Row (`layout-wide`) / Column (`layout-narrow`); banner |
| lib/ui/widgets/status_card.dart | 140 | kapalı/başlatılıyor/QR+URL(kopyala)+PIN+Durdur/hata+Tekrar dene |
| lib/ui/widgets/files_panel.dart | 215 | liste (dokun aç, uzun bas Paylaş/Sil onaylı), Bilgisayara gönder |
| lib/ui/widgets/text_banner.dart | 60 | gelen metin: Kopyala / Kapat |
| test/unit/ | ~470 | log, pick_lan_ip(9), network_service, safe_name(9), unique_name(5), secrets, format_size, server_controller (loopback), controller_events(8) |
| test/server/ | ~440 | handler_test_utils (HandlerFixture), auth(9), files_handler(12), web_ui(5: başlıklar, harici kaynak yok, innerHTML 0), text_handler(8) |
| test/integration/server_roundtrip_test.dart | 238 | 50 MB, (1), kopma, 413, 5 eşzamanlı, port dolu, token yenileme |
| test/ui/ | ~290 | test_app, finders (buttonWithText<T>), home_screen, home_running (QR/durumlar/banner/yerleşim 800-360), received_list (biçim, sil onay, uploaded→satır) |
| test/fakes/ | 122 | FakeNetworkService, FakeServerService, StubController |

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
| Dosya adı | ≤200 karakter (rune), boşsa `dosya` |
| Token taşıma | `?t=` / cookie `ld_token` (HttpOnly, SameSite=Strict, Path=/) |
| /login gövde | ≤1024 B |
| Metin (`/api/text`) | ≤64 KB (UTF-8, JSON gövdesi) |
| Web liste yenileme | 5000 ms (sekme görünürken) |
| Geniş yerleşim eşiği | 600 dp (`HomeScreen.wideBreakpoint`) |
| Log öneki | `[LD/<alan>]` (debugPrint, yalnız kDebugMode) |

## 6. Özellik durumu

| Özellik | Kod | Test | Cihazda |
|---|---|---|---|
| İskelet + Provider (F1) | ✅ | ✅ | ⏳ |
| IP tespiti (F2) | ✅ | ✅ | ⏳ |
| HTTP sunucu + token (F3) | ✅ | ✅ | ⏳ |
| Web arayüzü (F4) | ✅ | ✅ | ⏳ |
| Mobil arayüz (F5) | ✅ | ✅ | ⏳ |
| Arka plan + depolama (F6) | ⏳ | ⏳ | ⏳ |
| Sertleştirme (F7) | ⏳ | ⏳ | ⏳ |
| Yayın hazırlığı (F8) | ⏳ | ⏳ | ⏳ |

## 7. Alınmış kararlar

- K1: Hedef yalnız Android (iOS Local Network izni ve arka plan kısıtı kapsam dışı).
- K2: Provider (ChangeNotifier); Riverpod/GetX yok.
- K3: Token zorunlu; QR'a gömülü. PIN yalnız QR okutulamayan durum için.
- K4: Alınan dosyalar F3–F5'te uygulama klasöründe; F6'da Download/LocalDrop (MediaStore). MANAGE_EXTERNAL_STORAGE kullanılmaz.
- K6: IP kaynağı = `NetworkInterface.list` (arayüz adıyla); `getWifiIP()` yalnız `preferred` ipucu. Neden: getWifiIP konum izni istemiyor ama Android 12+'da aktif ağı (Wi-Fi kapalıyken mobil veri) döndürüyor; arayüz adı olmadan mobil veri elenemez. Konum izni istenmez.
- K7: indirme/silmede ad `safeName(ad) == ad` değilse 400 (düzeltilmez); upload'da ad temizlenir. Bozuk %-kodlu URL'yi shelf zaten Request oluştururken reddeder.
- K8: T3 içerik doğrulaması sha256 yerine deterministik üreteçle bayt bayt karşılaştırma (crypto paketi eklememek için; daha sıkı).
- K9: Web UI hiç innerHTML kullanmaz (test sayısı 0). Token cookie'ye alınınca `history.replaceState` ile `?t=` adres çubuğundan silinir. CSP/nosniff tüm yanıtlara eklenir.
- K10: Telefon→PC: seçilen dosya `readAsByteStream` ile paylaşım klasörüne akışla kopyalanır (`saveStream`, ≤4 GB). Yol referansı tutulmaz: SAF `content://` URI'leri kalıcı yol değil. >500 MB'ta da RAM sorunu yok; bedel diskte çift kopya.
- K11: open_filex'in eklediği READ_EXTERNAL_STORAGE + READ_MEDIA_IMAGES/VIDEO/AUDIO ana manifestte `tools:node="remove"` (kullanıcı onayı 2026-10-09). Yalnız uygulama klasörü açılır. Birleşik manifest doğrulandı.
- K5 (F6'da kesinleşecek): FGS türü adayı `dataSync` (Android 15 süre limiti → onTimeout'ta sunucu kapanır + bildirim).

## 8. AÇIK BULGULAR (S-n: şüphe, B-n: doğrulanmış)

- S1 🟢 `usesCleartextTraffic="true"` global açık. Gelen sunucu trafiğini etkilemez; gereksizse F6'da kaldırılacak.

## 9. CİHAZDA BEKLEYEN DOĞRULAMALAR

(Her faz FAZLAR.md "Cihaz" maddelerini ekler; doğrulanınca silinir. Log: `[LD/...]`.)

1. F1: Açılış → "Local Drop" başlığı + Başlat.
2. F2: Wi-Fi açık → `IP: 192.168.x.x` (`Net ip=`); kapat → ≤3 sn "Ağ bağlantısı yok", Başlat pasif (`Net no-network`); yalnız hotspot → 192.168.43.1 benzeri.
3. F3: Başlat → `Server started 0.0.0.0:8080 token=ab**`; 1 GB upload'da `adb shell dumpsys meminfo com.example.local_drop` RAM 1 GB artmıyor.
4. F3 T4 (PowerShell; `<IP>:<PORT>`, `<T>` ekrandan):
   ```powershell
   curl.exe -s -o NUL -w "%{http_code}`n" "http://<IP>:<PORT>/api/files"            # 401
   curl.exe -s "http://<IP>:<PORT>/api/files?t=<T>"                                  # []
   curl.exe -s -F "file=@C:\temp\test.zip" "http://<IP>:<PORT>/api/upload?t=<T>"     # 200
   curl.exe -s -o C:\temp\geri.zip "http://<IP>:<PORT>/api/download/test.zip?t=<T>"
   (Get-FileHash C:\temp\test.zip).Hash -eq (Get-FileHash C:\temp\geri.zip).Hash    # True
   ```
5. F3/F5: `http://<IP>:<PORT>/login` → PIN → arayüz; QR'ı ikinci telefonla okut → arayüz; kopyala butonu panoya alıyor.
6. F4: Chrome → Ağ sekmesinde dış istek yok, adres çubuğunda `?t=` kalmıyor; 3 dosya sürükle → 3 progress (%, MB/s, kalan), liste yenileniyor.
7. F4: `<img src=x onerror=alert(1)>.txt` yükle → listede metin, alert yok; gizli pencerede token'sız `/api/files` → 401; sunucu yeniden başlarsa "Bağlantı süresi doldu…".
8. F4: 360 px + koyu tema kullanılabilir.
9. F5: PC'den yükle → "x alındı" SnackBar + satır (`Upload done name=... bytes=...`); dokun → açılıyor; uzun bas → Paylaş / Sil onayı.
10. F5: "Bilgisayara gönder" → PDF → PC listesinde, indiriliyor (`Files import`); PC'den metin → banner, Kopyala/Kapat çalışıyor; yatay/≥600 dp → yan yana.

## 10. COMMIT GÜNLÜĞÜ (eski → yeni)

| Commit | Faz | Özet |
|---|---|---|
| b52ff2e…4269b26 | F0–F4 | ilk commit, GitHub birleştirme, F1 iskelet (1375142), F2 ağ (d3d42d4), F3 sunucu (5af0001), F4 web (14d508f) + özet sıkıştırma (4269b26); hepsi dev + main'de |
| (bu commit) | F5 | feat(ui): QR kartı, dosya listesi, telefondan gönderme, metin banner'ı |

## 11. Ortam / cihaz notları

- Test cihazı: Xiaomi Mi 11 (MIUI). "USB üzerinden yükle" açık olmalı.
- adb: `C:\Android\sdk\platform-tools\adb.exe`
- Verileri silmeden kurulum: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- Log: `adb logcat -s flutter | Select-String "\[LD/"`
- PC ve telefon aynı Wi-Fi'de olmalı. Windows Güvenlik Duvarı giden trafiği engellemez; misafir ağlarda "client isolation" bağlantıyı keser (hata değil, ortam).
- MIUI: Otomatik başlatma açık + pil "Kısıtlama yok" (F6 testleri için).

## 12. İŞLEM GÜNLÜĞÜ (her iş 1 satır, en yeni altta)
<!-- format: YYYY-MM-DD HH:mm | hash/commitlenmedi | iş | kod: dosyalar | test: dosyalar | analyze/test | sonuç -->
<!-- 2026-10-09 20:33–20:43 | b52ff2e, 1375142, d3d42d4 | docs kurulumu + F0 repo + F1 iskelet + F2 ağ servisi | ayrıntı: §3, §7 (K6), §10 | analyze/test: OK (16) -->
<!-- 2026-10-09 20:56–21:02 | 5af0001, 14d508f | F3 HTTP sunucu + F4 web arayüzü | ayrıntı: §3, §7 (K7–K9) | analyze/test: OK (78) -->
<!-- 2026-10-09 21:17 | (bu commit) | F5 mobil arayüz | kod: ui/*, server_controller, file_actions, storage.saveStream (upload'dan taşındı), manifest (K11), +3 paket | test: +20 (98) | analyze/test/apk: OK | K10, K11 -->
