# PROJE ÖZETİ — Local Drop (local_drop)
<!-- OZET_META: guncelleme=2026-10-09 21:33 | son_kod_commit=(F6 commit'i, hash §12'de düzeltilecek) | faz=F6 tamam, F7 bekliyor -->

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

Bağımlılıklar (mevcut): shelf, shelf_router, shelf_multipart (2.x — API 1.x'ten farklı, lock'taki sürüme göre yaz), network_info_plus, qr_flutter, path_provider, provider ^6.1.5+1, open_filex 4.7.0, share_plus 13.3.1, file_picker 13.1.0 (`FilePicker.pickFiles()` → `List<PlatformFile>`, `readAsByteStream()`), flutter_foreground_task 11.0.3. wakelock_plus EKLENMEDİ (K12).

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
- MainActivity motoru önbellekte (`provideFlutterEngine`) → kaydırınca sunucu ölmez, süreci FGS tutar. FGS isolate'i yalnız bildirim: Durdur/timeout → `sendDataToMain`.
- Kotlin `DeviceChannel`: kilitler (PARTIAL + Wi-Fi <API34), saveToDownloads (MediaStore, IS_PENDING, ayrı thread).
- `WakelockPolicy`: upload begin/finally end, download `trackTransfer`. Upload sonrası `StorageTarget.finalize` (hata → ServerErrorEvent, dosya kalır).
- Tek paylaşım klasörü: PC'den gelenler + telefondan "Bilgisayara gönder"le eklenenler (ikisi de `/api/files`'ta).
- Sunucu → UI olayları: `Stream<ServerEvent>` (FileUploaded, FileDeleted, TextReceived, ServerErrorEvent) — ServerService.events → ServerController.events.
- İstek hattı: securityHeaders (her yanıta CSP + nosniff) → errorMiddleware (500 JSON) → authMiddleware (`?t=`/cookie; `/login` muaf; tokensız `GET /` → 302 /login) → shelf_router.
- Upload: `_BodyGuard` gövdeyi izler; bağlantı koparsa aktif parça hatayla kapanır (mime 2.1.0 bunu yapmıyor, yoksa `.part` asılı kalır).
- Geçici dosya: `.<ad>.part` (safeName noktayla başlamaz → gerçek adla çakışmaz). Eşzamanlı aynı ad: `StorageService.reserveUnique`.
- Tüm dosya sistemi yolları `StorageService.resolve(name)` üzerinden; kök dışına çıkan yol = istisna.

## 3. Dosya haritası

| Dosya | Satır | Görev |
|---|---|---|
| lib/main.dart, app.dart | 57+29 | storage/settings load; WakelockPolicy(NativeDeviceChannel), StorageTarget; MultiProvider; MaterialApp M3 teal |
| lib/core/ | ~380 | constants (§5, 80), log, errors, format (formatSize=JS, formatDate), safe_name, secrets, lan_ip, wakelock_policy (TransferObserver, LockAdapter, WakelockPolicy) |
| lib/server/ | ~640 | router (CSP/nosniff, error, auth, route'lar; transfers+target param), auth_middleware, responses, server_event, web_ui (378, innerHTML 0) |
| lib/server/handlers/ | ~410 | login, text (≤64 KB), files (list/download trackTransfer/delete), upload (_BodyGuard, saveStream, _finalize, transfers) |
| lib/services/ | ~620 | server_service, storage_service (resolve/reserveUnique/list/saveStream/delete), network_service, file_actions, background_service (FGS + task handler), device_channel, settings_service (JSON), storage_target |
| lib/state/server_controller.dart | 254 | durum, files, lastText, notice, saveLocation/downloadsSupported; start (+FGS, izin) / stop; olaylar; Fgs stop/timeout; import/delete |
| lib/ui/ | ~640 | home_screen (yerleşim, SnackBar, Ayarlar), settings_screen (RadioGroup kayıt yeri), widgets: status_card (+notice), files_panel, text_banner |
| android/.../MainActivity.kt, DeviceChannel.kt | 30+126 | motor önbelleği; kilitler + MediaStore |
| test/unit/ | ~800 | log, pick_lan_ip, network_service, safe_name, unique_name, secrets, format_size, server_controller, controller_events, wakelock_policy(6), storage_target(4), settings_service(3), controller_background(7) |
| test/server/ | ~440 | handler_test_utils (HandlerFixture), auth(9), files_handler(12), web_ui(5: başlıklar, harici kaynak yok, innerHTML 0), text_handler(8) |
| test/integration/server_roundtrip_test.dart | 238 | 50 MB, (1), kopma, 413, 5 eşzamanlı, port dolu, token yenileme |
| test/ui/ | ~340 | test_app, finders, home_screen, home_running, received_list, settings_screen(3) |
| test/fakes/ | ~170 | FakeNetwork/Server/BackgroundService, StubController |

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
| FGS / depolama | id 256, kanal `local_drop_server`; Download/`LocalDrop`; `settings.json` |
| Log öneki | `[LD/<alan>]` (debugPrint, yalnız kDebugMode) |

## 6. Özellik durumu

| Özellik | Kod | Test | Cihazda |
|---|---|---|---|
| İskelet + Provider (F1) | ✅ | ✅ | ⏳ |
| IP tespiti (F2) | ✅ | ✅ | ⏳ |
| HTTP sunucu + token (F3) | ✅ | ✅ | ⏳ |
| Web arayüzü (F4) | ✅ | ✅ | ⏳ |
| Mobil arayüz (F5) | ✅ | ✅ | ⏳ |
| Arka plan + depolama (F6) | ✅ | ✅ | ⏳ |
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
- K5: FGS türü `dataSync` (yerel dosya aktarımı). Android 15 süre limiti → `onDestroy(isTimeout)` → sunucu kapanır, ekranda "Süre doldu, tekrar başlat" (ayrı bildirim için ek paket gerekir, eklenmedi).
- K12: wakelock_plus yok (Android'de yalnız ekranı açık tutar). CPU+Wi-Fi kilidi native, yalnız transfer sürerken (sayaç). FGS allowWakeLock/WifiLock kapalı. RECEIVE_BOOT_COMPLETED + RebootReceiver `tools:node="remove"`. Plan onayı 2026-10-09.
- K13: İndirilenler (Android 10+): biten dosya MediaStore'a taşınır, uygulama/PC listesinde görünmez. Ayar SharedPreferences yerine JSON dosya (paket F8'de).

## 8. AÇIK BULGULAR (S-n: şüphe, B-n: doğrulanmış)

(yok)

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
11. F6: Başlat → kalıcı bildirim "Local Drop çalışıyor — IP:PORT"; "Durdur" → sunucu kapanır (`Fgs stop by notification`).
12. F6: Ekranı kilitle, PC'den 2 GB yükle → tamamlanır, hash eşit (`Lock acquireLocks` → `releaseLocks`).
13. F6: Son uygulamalardan kaydır → sunucu çalışmaya devam (MIUI: otomatik başlatma + pil kısıtlaması yok).
14. F6: Ayarlar → İndirilenler → PC'den yükle → Dosyalar > Download/LocalDrop'ta (`Storage downloads name=`).
15. F6: Bildirim izni reddet → sunucu çalışır, kartta "Bildirim izni yok…" uyarısı.
16. F6: cleartext kaldırıldı → 4. maddedeki curl komutları aynen çalışır.

## 10. COMMIT GÜNLÜĞÜ (eski → yeni)

| Commit | Faz | Özet |
|---|---|---|
| b52ff2e…5b16e45 | F0–F5 | ilk commit … F4 web (14d508f), özet (4269b26), F5 mobil arayüz (5b16e45); hepsi dev + main'de |
| (bu commit) | F6 | feat(android): FGS, transfer kilitleri, İndirilenler, ayarlar, cleartext kaldırıldı |

## 11. Ortam / cihaz notları

- Test cihazı: Xiaomi Mi 11 (MIUI). "USB üzerinden yükle" açık olmalı.
- adb: `C:\Android\sdk\platform-tools\adb.exe`
- Verileri silmeden kurulum: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- Log: `adb logcat -s flutter | Select-String "\[LD/"`
- PC ve telefon aynı Wi-Fi'de olmalı. Windows Güvenlik Duvarı giden trafiği engellemez; misafir ağlarda "client isolation" bağlantıyı keser (hata değil, ortam).
- MIUI: Otomatik başlatma açık + pil "Kısıtlama yok" (F6 testleri için).

## 12. İŞLEM GÜNLÜĞÜ (her iş 1 satır, en yeni altta)
<!-- format: YYYY-MM-DD HH:mm | hash/commitlenmedi | iş | kod: dosyalar | test: dosyalar | analyze/test | sonuç -->
<!-- 2026-10-09 20:33–21:17 | b52ff2e…5b16e45 | kurulum, F0–F5 | ayrıntı: §3, §7 (K6–K11), §10 | analyze/test: OK (98) -->
<!-- 2026-10-09 21:33 | (bu commit) | F6 arka plan + depolama | kod: MainActivity/DeviceChannel.kt, manifest, background/device_channel/settings/storage_target servisleri, wakelock_policy, handler'lar, controller, settings_screen | test: +23 (121) | analyze/test/apk: OK; birleşik manifest doğrulandı | K5, K12, K13; S1 kapandı -->
