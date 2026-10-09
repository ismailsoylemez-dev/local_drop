# PROJE ÖZETİ — Local Drop (local_drop)
<!-- OZET_META: guncelleme=2026-10-09 21:02 | son_kod_commit=(F4 commit'i, hash §12'de düzeltilecek) | faz=F4 tamam, F5 bekliyor -->

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
- Sunucu → UI olayları: `Stream<ServerEvent>` (FileUploaded, FileDeleted, TextReceived, ServerErrorEvent) — ServerService.events → ServerController.events.
- İstek hattı: securityHeaders (her yanıta CSP + nosniff) → errorMiddleware (500 JSON) → authMiddleware (`?t=`/cookie; `/login` muaf; tokensız `GET /` → 302 /login) → shelf_router.
- Upload: `_BodyGuard` gövdeyi izler; bağlantı koparsa aktif parça hatayla kapanır (mime 2.1.0 bunu yapmıyor, yoksa `.part` asılı kalır).
- Geçici dosya: `.<ad>.part` (safeName noktayla başlamaz → gerçek adla çakışmaz). Eşzamanlı aynı ad: `StorageService.reserveUnique`.
- Tüm dosya sistemi yolları `StorageService.resolve(name)` üzerinden; kök dışına çıkan yol = istisna.

## 3. Dosya haritası

| Dosya | Satır | Görev |
|---|---|---|
| lib/main.dart | 15 | runApp + ChangeNotifierProvider<ServerController(network: NetworkService())> |
| lib/app.dart | 29 | LocalDropApp: MaterialApp, M3, seed teal, light/dark |
| lib/core/constants.dart | 61 | AppConstants (§5) |
| lib/core/format.dart | 14 | formatSize (saf; web UI JS ile aynı kural) |
| lib/core/errors.dart | 17 | ServerStartException, PathEscapeException |
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
| lib/server/handlers/upload_handler.dart | 170 | multipart → .part → rename; limit 413; _BodyGuard |
| lib/services/server_service.dart | 87 | shelf_io.serve, port aralığı, token/PIN, events, stop/dispose |
| lib/services/storage_service.dart | 78 | root, resolve(strict), partFileFor, reserveUnique/release, list |
| lib/services/network_service.dart | 91 | sealed NetworkResult (Connected/NoNetwork); NetworkService.current()/watch() (distinct, enjekte edilebilir kaynaklar) |
| lib/state/server_controller.dart | 104 | ServerStatus; network+canStart; start (ServerFactory enjekte) → url/pin; stop; events |
| lib/ui/screens/home_screen.dart | 71 | kapalı: ağ metni + Başlat; starting: progress; running: URL (seçilebilir) + PIN + Durdur; error: mesaj |
| test/fakes/fake_network_service.dart | 13 | StreamController'lı sahte ağ |
| test/ui/home_screen_test.dart | 53 | widget (FakeNetworkService): başlık, NoNetwork→pasif, Connected→IP |
| test/unit/pick_lan_ip_test.dart | 64 | IP seçimi (9) |
| test/unit/network_service_test.dart | 35 | watch distinct, getWifiIP hata fallback |
| test/unit/safe_name_test.dart | 55 | safeName (9) |
| test/unit/unique_name_test.dart | 24 | uniqueName (5) |
| test/unit/secrets_test.dart | 22 | token/PIN/constantTimeEquals |
| test/unit/format_size_test.dart | 14 | formatSize |
| test/server/web_ui_test.dart | 57 | GET / başlıklar, harici kaynak yok, innerHTML 0, gömülü sabitler |
| test/server/text_handler_test.dart | 78 | 200/413 (header+akış)/400/401 |
| test/unit/server_controller_test.dart | 85 | start/stop/hata/ağ yok (loopback) |
| test/server/handler_test_utils.dart | 76 | HandlerFixture, multipart gövde |
| test/server/auth_test.dart | 87 | 401/cookie/login (9) |
| test/server/files_handler_test.dart | 139 | liste/indir/sil/upload/yol geçişi (12) |
| test/integration/server_roundtrip_test.dart | 238 | 50 MB, (1), kopma, 413, 5 eşzamanlı, port dolu, token yenileme |
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
| Dosya adı | ≤200 karakter (rune), boşsa `dosya` |
| Token taşıma | `?t=` / cookie `ld_token` (HttpOnly, SameSite=Strict, Path=/) |
| /login gövde | ≤1024 B |
| Metin (`/api/text`) | ≤64 KB (UTF-8, JSON gövdesi) |
| Web liste yenileme | 5000 ms (sekme görünürken) |
| Log öneki | `[LD/<alan>]` (debugPrint, yalnız kDebugMode) |

## 6. Özellik durumu

| Özellik | Kod | Test | Cihazda |
|---|---|---|---|
| İskelet + Provider (F1) | ✅ | ✅ | ⏳ |
| IP tespiti (F2) | ✅ | ✅ | ⏳ |
| HTTP sunucu + token (F3) | ✅ | ✅ | ⏳ |
| Web arayüzü (F4) | ✅ | ✅ | ⏳ |
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
- K7: indirme/silmede ad `safeName(ad) == ad` değilse 400 (düzeltilmez); upload'da ad temizlenir. Bozuk %-kodlu URL'yi shelf zaten Request oluştururken reddeder.
- K8: T3 içerik doğrulaması sha256 yerine deterministik üreteçle bayt bayt karşılaştırma (crypto paketi eklememek için; daha sıkı).
- K9: Web UI hiç innerHTML kullanmaz (test sayısı 0). Token cookie'ye alınınca `history.replaceState` ile `?t=` adres çubuğundan silinir. CSP/nosniff tüm yanıtlara eklenir.
- K5 (F6'da kesinleşecek): FGS türü adayı `dataSync` (Android 15 süre limiti → onTimeout'ta sunucu kapanır + bildirim).

## 8. AÇIK BULGULAR (S-n: şüphe, B-n: doğrulanmış)

- S1 🟢 `usesCleartextTraffic="true"` global açık. Gelen sunucu trafiğini etkilemez; gereksizse F6'da kaldırılacak.

## 9. CİHAZDA BEKLEYEN DOĞRULAMALAR

(Her faz kendi maddelerini FAZLAR.md "Cihaz" bölümünden buraya ekler; doğrulanınca silinir.)

1. F1: Uygulama açılıyor, Local Drop başlığı ve Başlat butonu görünüyor.
2. F2: Wi-Fi açık → ekranda `IP: 192.168.x.x`; log `[LD/Net] ip=192.168...`.
3. F2: Wi-Fi kapat → ≤3 sn içinde "Ağ bağlantısı yok", Başlat pasif; log `[LD/Net] no-network`.
4. F2: Hotspot aç (Wi-Fi kapalı) → 192.168.43.1 benzeri adres (MIUI'de farklı alt ağ olabilir).
5. F3: Başlat → log `[LD/Server] started 0.0.0.0:8080 token=ab**`; ekranda URL + PIN.
6. F3: 1 GB upload sırasında `adb shell dumpsys meminfo com.example.local_drop` → RAM 1 GB artmıyor.
7. F3 T4 (PC PowerShell; `<IP>:<PORT>`, `<T>` ekrandan):
   ```powershell
   curl.exe -s -o NUL -w "%{http_code}`n" "http://<IP>:<PORT>/api/files"                  # 401
   curl.exe -s "http://<IP>:<PORT>/api/files?t=<T>"                                        # []
   curl.exe -s -F "file=@C:\temp\test.zip" "http://<IP>:<PORT>/api/upload?t=<T>"          # 200
   curl.exe -s -o C:\temp\geri.zip "http://<IP>:<PORT>/api/download/test.zip?t=<T>"
   (Get-FileHash C:\temp\test.zip).Hash -eq (Get-FileHash C:\temp\geri.zip).Hash          # True
   ```
8. F3: Tarayıcıda `http://<IP>:<PORT>/login` → PIN → `/` açılıyor.
9. F4 T4: Chrome'da ekrandaki adres → arayüz açılıyor; DevTools Ağ sekmesinde dış istek yok, adres çubuğunda `?t=` kalmıyor.
10. F4 T4: 3 dosya sürükle → 3 progress (yüzde, MB/s, kalan), hepsi tamamlanıyor, liste yenileniyor.
11. F4 T4: Adı `<img src=x onerror=alert(1)>.txt` olan dosya yükle → listede metin (`_img src=x ..._`), alert yok.
12. F4 T4: Gizli pencerede token'sız `http://<IP>:<PORT>/api/files` → 401; arayüz açıkken sunucuyu durdur/başlat → "Bağlantı süresi doldu, QR'ı tekrar okutun".
13. F4: Metin gönder → log `[LD/Text] received chars=N` (telefonda banner F5'te).
14. F4: Telefon dar ekran (360 px) ve koyu tema → arayüz kullanılabilir.

## 10. COMMIT GÜNLÜĞÜ (eski → yeni)

| Commit | Faz | Özet |
|---|---|---|
| b52ff2e | F0 | chore: ilk commit + ajan dokumanlari (repo, dev branch, .gitignore) |
| e3e5df7, 6582d22 | — | GitHub main birleştirme (README 1 satır) |
| 1375142 | F1 | feat(app): iskelet, Provider, sabitler, log (origin/dev'e push edildi) |
| d3d42d4 | F2 | feat(net): IP tespiti + ağ durumu akışı (dev + main push) |
| 5af0001 | F3 | feat(server): shelf sunucu, token/PIN, upload/download/delete (dev + main push) |
| (bu commit) | F4 | feat(web): web arayüzü + POST /api/text + CSP |

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
<!-- 2026-10-09 20:43 | d3d42d4 | F2 ağ servisi | kod: core/lan_ip.dart, services/network_service.dart, state/server_controller.dart, ui/screens/home_screen.dart, core/constants.dart, main.dart | test: pick_lan_ip_test(+9), network_service_test(+2), home_screen_test(+2) | analyze/test: OK (16) | K6 kararı; manifest değişmedi -->
<!-- 2026-10-09 20:56 | 5af0001 | F3 HTTP sunucu | kod: core/{errors,safe_name,secrets,constants}, server/*, services/{server,storage}_service, state/server_controller, ui/home_screen | test: safe_name(+9) unique_name(+5) secrets(+3) server_controller(+3) auth(+9) files_handler(+12) roundtrip(+7) | analyze/test: OK (64) | mime kopma hatası _BodyGuard ile çözüldü; K7, K8 -->
<!-- 2026-10-09 21:02 | (bu commit) | F4 web arayüzü | kod: server/web_ui.dart, server/handlers/text_handler.dart, server/router.dart, core/format.dart, core/constants.dart | test: format_size(+1) web_ui(+5) text_handler(+8) | analyze/test: OK (78); JS node --check OK, formatSize JS=Dart | K9 -->
