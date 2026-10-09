# PROJE ÖZETİ — Local Drop (local_drop)
<!-- OZET_META: guncelleme=2026-10-09 22:11 | son_kod_commit=(F7 commit'i, hash §12'de düzeltilecek) | faz=F7 tamam, F8 bekliyor -->

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
- Transfer gözlemcisi `MultiTransferObserver([WakelockPolicy, NetworkRestartPolicy])`: upload begin/finally end, download `trackTransfer`. IP değişince aynı sunucu yeni token/PIN ile yeniden açılır (aktif transfer bitene kadar ertelenir), bildirim `update`, olay `NetworkChanged`. ServerFactory = `(storage, transfers)`.
- `RateLimiter` auth'ta: engelli IP → her istek 429 (+Retry-After); yanlış token/PIN sayılır, doğru sıfırlar. Upload sonrası `StorageTarget.finalize` (hata → ServerErrorEvent, dosya kalır).
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
| lib/core/ | ~410 | constants, log, errors (+isDiskFull), format, safe_name, secrets, lan_ip, wakelock_policy (+MultiTransferObserver) |
| lib/server/ | ~700 | router, auth_middleware (+rate limit, 429), rate_limiter (59, saat enjekte), responses, server_event (+NetworkChanged), web_ui (378) |
| lib/server/handlers/ | ~420 | login (PIN sayacı), text, files, upload (_BodyGuard, saveStream, _finalize, 507 disk dolu) |
| lib/services/ | ~640 | server_service, storage_service (saveStream→writePart, ENOSPC'de .part silinir), network_service, file_actions, background_service (+update), device_channel, settings_service, storage_target |
| lib/state/ | 296+54 | server_controller (+activeTransfers, _restartForNetwork), network_restart_policy (saf) |
| lib/ui/ | ~680 | home_screen (+"Ağ değişti, QR yenilendi"), settings_screen, status_card (+Durdur onayı), files_panel (+yer yok), text_banner |
| android/.../MainActivity.kt, DeviceChannel.kt | 30+126 | motor önbelleği; kilitler + MediaStore |
| test/unit/ | ~800 | log, pick_lan_ip, network_service, safe_name, unique_name, secrets, format_size, server_controller, controller_events, wakelock_policy(6), storage_target(4), settings_service(3), controller_background(7), rate_limiter(9), network_restart(8), device_channel(4) |
| test/server/ | ~560 | disk_full(4) + | handler_test_utils (HandlerFixture), auth(9), files_handler(12), web_ui(5: başlıklar, harici kaynak yok, innerHTML 0), text_handler(8) |
| test/integration/ | 238+155 | roundtrip (50 MB, kopma, 413, eşzamanlı, port) + abuse (ham soket: %2e%2e, %252e, mutlak yol, NUL; 20) |
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
| Yanlış token/PIN limiti | IP başına 10 / dk (kayan) → 429 + Retry-After |
| Disk dolu | OS kodu 28/39/112 → 507 "Telefonda yer yok" |
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
| Sertleştirme (F7) | ✅ | ✅ (kapsam services+server %85,1) | ⏳ |
| Yayın hazırlığı (F8) | ⏳ | ⏳ | ⏳ |

## 7. Alınmış kararlar

- K1: Yalnız Android. K2: Provider. K3: Token zorunlu (QR'da); PIN yalnız QR okutulamazsa. K4: MANAGE_EXTERNAL_STORAGE yok.
- K5: FGS `dataSync`. Android 15 süre limiti → `onDestroy(isTimeout)` → sunucu kapanır, ekranda "Süre doldu, tekrar başlat" (ayrı bildirim = ek paket, yok).
- K6: IP = `NetworkInterface.list` (arayüz adıyla); `getWifiIP()` yalnız ipucu (Android 12+'da mobil veriyi döndürebilir). Konum izni yok.
- K7: indirme/silmede `safeName(ad) != ad` → 400; upload'da ad temizlenir.
- K8: T3 içerik = deterministik üreteçle bayt bayt (crypto paketi yok).
- K9: Web UI innerHTML 0; `?t=` `replaceState` ile silinir; CSP/nosniff her yanıtta.
- K10: Telefon→PC: `readAsByteStream` ile klasöre akışla kopya; yol referansı yok (SAF URI kalıcı değil).
- K11: open_filex'in READ_EXTERNAL_STORAGE + READ_MEDIA_* izinleri `tools:node="remove"` (onaylı).
- K12: wakelock_plus yok (yalnız ekran). CPU+Wi-Fi kilidi native, yalnız transfer sürerken. Boot alıcısı + izni kaldırıldı (onaylı).
- K13: İndirilenler (10+): biten dosya MediaStore'a taşınır, listelerde görünmez. Ayar JSON dosyada (SharedPreferences F8).
- K14: Engelli IP doğru token ile de 429. Kimliksiz `GET /` sayılmaz. NUL'lu multipart adı → 400. Kapsam: `flutter test --coverage` + lcov; background_service/file_actions yalnız cihazda.

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
17. F7: Transfer sırasında Wi-Fi değiştir → transfer hata, yeni QR + "Ağ değişti, QR yenilendi", yarım dosya listede yok (`Net ip değişti → restart`).
18. F7: Depolama doluyken yükle → PC'de "Telefonda yer yok" (507).
19. F7: Yanlış token ile 11 istek → 429 + Retry-After; transfer sürerken Durdur → onay penceresi.

## 10. COMMIT GÜNLÜĞÜ (eski → yeni)

| Commit | Faz | Özet |
|---|---|---|
| b52ff2e…9828744 | F0–F6 | … F5 mobil (5b16e45), F6 arka plan (9828744); hepsi dev + main'de |
| (bu commit) | F7 | feat(hardening): rate limit, disk dolu, ağ değişiminde yeniden başlatma, kapsam |

## 11. Ortam / cihaz notları

- Test cihazı: Xiaomi Mi 11 (MIUI). "USB üzerinden yükle" açık olmalı.
- adb: `C:\Android\sdk\platform-tools\adb.exe`
- Verileri silmeden kurulum: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- Log: `adb logcat -s flutter | Select-String "\[LD/"`
- PC ve telefon aynı Wi-Fi'de olmalı. Windows Güvenlik Duvarı giden trafiği engellemez; misafir ağlarda "client isolation" bağlantıyı keser (hata değil, ortam).
- MIUI: Otomatik başlatma açık + pil "Kısıtlama yok" (F6 testleri için).

## 12. İŞLEM GÜNLÜĞÜ (her iş 1 satır, en yeni altta)
<!-- format: YYYY-MM-DD HH:mm | hash/commitlenmedi | iş | kod: dosyalar | test: dosyalar | analyze/test | sonuç -->
<!-- 2026-10-09 20:33–21:33 | b52ff2e…9828744 | kurulum, F0–F6 | ayrıntı: §3, §7, §10 | analyze/test: OK (121) -->
<!-- 2026-10-09 22:11 | (bu commit) | F7 sertleştirme | kod: rate_limiter, auth/login, errors.isDiskFull, storage.writePart, upload 507, network_restart_policy, controller restart, status_card onay | test: +49 (170) | analyze/test: OK; kapsam services+server 85,1% | K14 -->
