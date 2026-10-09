# FAZLAR — local_drop
<!-- Ajan bu dosyayı baştan sona OKUMAZ: Grep "^## F" → yalnız GÖREV'deki fazın bölümü (offset/limit). -->
<!-- Her faz: GÖREV satırı (AJAN_IS GÖREV'ine kopyalanır) + kapsam + test senaryoları (T1-T5) + cihaz maddeleri. -->
<!-- Faz bitince PROJE_OZET §6 satırı güncellenir; T4/T5 maddeleri §9'a taşınır. -->

## F0 — Repo ve doküman kurulumu

**GÖREV:** İstek: git repo kur, docs'u ilk commit'e al · Faz: F0 · Kabul: `dev` branch'te tek commit, çalışma ağacı temiz · Commit: evet

Kapsam:
1. `git init`, `git checkout -b dev`.
2. `.gitignore` kontrol: `build/`, `.dart_tool/`, `*.iml`, `android/local.properties`, `android/key.properties`, `*.jks`, `CLAUDE.md`, `.claude/` ekli mi; eksikse ekle.
3. Kökte `CLAUDE.md`: tek satır → "Her işte önce docs/AJAN_IS.md'yi oku." (gitignore'da kalır).
4. İlk commit: dosyalar adıyla eklenir (`git add .gitignore pubspec.yaml lib test android docs analysis_options.yaml README.md`). Mesaj: `chore: ilk commit + ajan dokumanlari`.

Test: yok (kod değişmedi). `git status --short` boş olmalı.

---

## F1 — İskelet ve mimari

**GÖREV:** İstek: counter demoyu kaldır, PROJE_OZET §2 klasör yapısını ve Provider iskeletini kur · Faz: F1 · Kabul: uygulama açılıyor, placeholder ana ekran, analyze 0, test geçiyor · Commit: evet

Kapsam:
1. `lib/main.dart` demo kodu tamamen silinir. `provider` eklenir (onaylı).
2. `core/constants.dart`: PROJE_OZET §5'teki tüm sabitler.
3. `core/log.dart`: `Log.d(area, msg)` → kDebugMode'da `debugPrint('[LD/$area] $msg')`. `Log.mask(token)` → ilk 2 karakter + `**`.
4. `app.dart`: MaterialApp, Material 3, seed teal, light + dark, title "Local Drop".
5. `state/server_controller.dart`: `enum ServerStatus { stopped, starting, running, error }`; alanlar `status`, `url`, `pin`, `errorMessage`; `start()` / `stop()` stub.
6. `ui/screens/home_screen.dart`: "Sunucu kapalı" + FilledButton "Başlat" (controller.start'a bağlı, stub).
7. README: 3 satır proje tanımı + "Ajan kuralları: docs/AJAN_IS.md".
8. PROJE_OZET §3 dosya haritası satır sayılarıyla doldurulur.

Test:
- T2 yerine widget: `test/ui/home_screen_test.dart` → başlık, "Sunucu kapalı", "Başlat" butonu görünür. Eski `test/widget_test.dart` silinir (onaylı).
- T1: `test/unit/log_test.dart` → `mask('abcdef') == 'ab**'`, `mask('') == '**'`.

Cihaz (T5 → §9): "Uygulama açılıyor, Local Drop başlığı ve Başlat butonu görünüyor."

---

## F2 — Ağ servisi (IP tespiti)

**GÖREV:** İstek: services/network_service.dart ile Wi-Fi/hotspot IPv4 tespiti ve ağ durumu akışı · Faz: F2 · Kabul: ana ekranda IP görünüyor, Wi-Fi kapalıyken "Ağ bağlantısı yok" · Commit: evet

Kapsam:
1. `sealed class NetworkResult { Connected(String ip), NoNetwork() }`.
2. Önce `network_info_plus.getWifiIP()`. null/boşsa `NetworkInterface.list(type: IPv4)` taranır.
3. Seçim saf fonksiyonda: `String? pickLanIp(List<String> adresler)`. Öncelik: 192.168.x > 10.x > 172.16–31.x. Hariç: 127.x, 169.254.x, 172.15/172.32 gibi özel aralık dışı adresler, mobil veri (rmnet/ccmni arayüz adları) → arayüz adı da parametre olarak geçer.
4. `Stream<NetworkResult> watch()`: §5 yoklama aralığı, yalnız değişince yayın (distinct).
5. Konum izni İSTENMEZ. getWifiIP konum izni isterse yalnız fallback kullanılır; karar §7'ye yazılır.
6. Controller ağ durumunu dinler; NoNetwork'te Başlat pasif.

Test:
- T1 `test/unit/pick_lan_ip_test.dart`:
  - `['10.0.0.5','192.168.1.20'] → 192.168.1.20`
  - `['127.0.0.1','169.254.3.4'] → null`
  - `['172.20.1.2','172.32.0.1'] → 172.20.1.2`
  - hotspot: `wlan1 / 192.168.43.1 → 192.168.43.1`
  - mobil veri arayüzü (`rmnet_data0 / 10.x`) + `wlan0 / 192.168.1.5` → 192.168.1.5
  - boş liste → null
- T2 widget: fake NetworkService ile `NoNetwork` → buton disabled + metin; `Connected` → IP metni.

Cihaz (T5 → §9):
1. Wi-Fi açık → ekranda 192.168.x.x; log `[LD/Net] ip=192.168...`.
2. Wi-Fi kapat → ≤3 sn içinde "Ağ bağlantısı yok"; log `[LD/Net] no-network`.
3. Hotspot aç (Wi-Fi kapalı) → 192.168.43.1 benzeri adres.

---

## F3 — HTTP sunucusu (çekirdek)

**GÖREV:** İstek: shelf sunucusu, token middleware, files/upload/download/delete route'ları, StorageService · Faz: F3 · Kabul: T1+T2+T3 geçer; PC'den curl ile yükleme/indirme çalışır · Commit: evet

Kapsam:
1. `server_service.dart`: `shelf_io.serve(handler, InternetAddress.anyIPv4, port)`; §5 port aralığında ilk boş port; hepsi doluysa `ServerStartException('Port bulunamadı')`. `stop()` → `close(force: true)`; controller dispose'da da kapanır.
2. Token + PIN her start'ta üretilir. `auth_middleware`: `?t=` veya `ld_token` cookie; geçerli `?t=` ile gelen ilk istekte HttpOnly + SameSite=Strict cookie set edilir. Karşılaştırma sabit zamanlı. Geçersiz → 401 JSON.
3. `GET /login` + `POST /login` (PIN ile cookie alma) — basit form.
4. Route'lar:
   - `GET /` → şimdilik `<h1>Local Drop</h1>` (F4'te web UI)
   - `GET /api/files` → `[{name, size, modified}]`, ada göre sıralı
   - `POST /api/upload` → shelf_multipart 2.x (lock'taki sürümün API'sini Pub cache'ten Grep'le); her part stream → `.part` → rename; aynı ad varsa `ad (1).ext`; Content-Length > limit ise okumadan 413; akış sırasında limit aşılırsa iptal + `.part` silinir + 413
   - `GET /api/download/<name>` → stream; `Content-Disposition: attachment; filename*=UTF-8''...`; doğru Content-Length
   - `DELETE /api/files/<name>` → 204 / 404
5. `storage_service.dart`: kök = `getApplicationDocumentsDirectory()/received`; `resolve(name)` → `safeName` + kanonik yol kök altında değilse `PathEscapeException`.
6. `core/safe_name.dart`: `/ \ : * ? " < > |`, kontrol karakterleri, baştaki nokta/boşluk temizlenir; `..` yasak; boş sonuç → `dosya`; 200 karakter sınırı (uzantı korunur).
7. Hata middleware'i: yakalanmayan istisna → 500 JSON `{error}`; ayrıntı yalnız loga.
8. Controller: running'de `url = http://<ip>:<port>/?t=<token>`; olaylar `Stream<ServerEvent>`.

Test:
- T1 `test/unit/safe_name_test.dart`: `../../etc/passwd → etc_passwd` (ya da benzeri, `..` ve ayraç içermez); `a/b\\c.txt`; `"  .gizli"`; `con.txt` korunur (Android'de geçerli); emoji/Türkçe `şöğüİı.pdf` korunur; 300 karakterlik ad → ≤200 ve `.pdf` korunur; `""` → `dosya`.
- T1 `test/unit/unique_name_test.dart`: `a.txt` varken → `a (1).txt`; `a (1).txt` da varsa → `a (2).txt`; uzantısız ad.
- T2 `test/server/auth_test.dart`: token yok → 401; yanlış → 401; doğru query → 200 + `Set-Cookie`; cookie ile → 200.
- T2 `test/server/files_handler_test.dart`: boş klasör → `[]`; `GET /api/download/..%2F..%2Fsecret` → 400/404, kök dışı dosya ASLA dönmez; olmayan dosya → 404; DELETE → 204, tekrar → 404.
- T3 `test/integration/server_roundtrip_test.dart` (127.0.0.1, port 0, geçici kök):
  1. Akışla üretilmiş 50 MB upload → `/api/files`'ta görünür → download sha256 eşit.
  2. Aynı adla 2. upload → `ad (1).ext`.
  3. Upload ortasında soket kapatılır → kökte ne dosya ne `.part` kalır.
  4. Limit testten küçük bir değere override edilir (constructor parametresi) → 413 ve `.part` yok.
  5. 5 eşzamanlı upload → 5 dosya, hepsinin sha256'sı doğru.
  6. Port doluysa bir sonrakine geçer (ilk portu test başta tutar).

T4 PC manuel (→ §9; `<IP>:<PORT>` ve `<T>` ekrandan):
```powershell
curl.exe -s -o NUL -w "%{http_code}`n" "http://<IP>:<PORT>/api/files"                  # 401
curl.exe -s "http://<IP>:<PORT>/api/files?t=<T>"                                        # []
curl.exe -s -F "file=@C:\temp\test.zip" "http://<IP>:<PORT>/api/upload?t=<T>"          # 200
curl.exe -s -o C:\temp\geri.zip "http://<IP>:<PORT>/api/download/test.zip?t=<T>"
(Get-FileHash C:\temp\test.zip).Hash -eq (Get-FileHash C:\temp\geri.zip).Hash          # True
```

Cihaz (T5 → §9):
1. Başlat → log `[LD/Server] started 0.0.0.0:8080 token=ab**`.
2. 1 GB dosya upload sırasında Android Studio Profiler / `adb shell dumpsys meminfo <paket>` → RAM 1 GB artmıyor (stream).

---

## F4 — Web arayüzü (PC tarafı)

**GÖREV:** İstek: server/web_ui.dart tek dosya HTML/CSS/JS arayüz + POST /api/text · Faz: F4 · Kabul: Chrome/Edge'de 3 dosya paralel yükleme progress ile, liste/indir/sil/metin gönder çalışır · Commit: evet

Kapsam:
1. `const String webUiHtml` — inline CSS + vanilla JS; harici CDN/font YOK.
2. Sürükle-bırak + "Dosya seç" (multiple). Her dosya ayrı XHR (`upload.onprogress`), dosya başına progress, MB/s ve kalan süre.
3. Telefondaki dosyalar listesi: ad, boyut (KB/MB/GB), indir, sil (onay için `confirm` değil, satır içi "Emin misin?" butonu).
4. Metin: textarea + "Telefona gönder" → `POST /api/text` (JSON `{text}`, ≤64 KB, aşarsa 413). Telefon olay olarak alır.
5. Hata: 401 → "Bağlantı süresi doldu, QR'ı tekrar okutun"; ağ hatası → "Tekrar dene".
6. Kullanıcı verisi yalnız `textContent`; `innerHTML` yalnız sabit şablonla.
7. `prefers-color-scheme` dark; 360 px genişlikte de kullanılabilir.
8. Yanıt başlıkları: `Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'`, `X-Content-Type-Options: nosniff`.

Test:
- T2 `test/server/web_ui_test.dart`: `GET /` → 200, `text/html; charset=utf-8`, CSP başlığı var; gövdede `http://`/`https://` ile başlayan harici kaynak YOK (regex); `innerHTML` geçen her satır sabit şablon (Grep ile sayı kontrolü — beklenen sayı testte sabit).
- T2 `test/server/text_handler_test.dart`: geçerli metin → 200 + olay yayınlandı; 64 KB+1 → 413; JSON değil → 400.
- T1 `test/unit/format_size_test.dart`: 0 → `0 B`, 1536 → `1,5 KB`, 1073741824 → `1,0 GB`.

T4 PC manuel (→ §9):
1. Chrome'da QR adresi → arayüz açılıyor, Ağ sekmesinde dış istek yok.
2. 3 dosya sürükle → 3 progress, hepsi tamamlanıyor, liste yenileniyor.
3. Dosya adı `<img src=x onerror=alert(1)>.txt` olan dosya yükle → listede metin olarak görünüyor, alert yok.
4. Token'sız adres → 401 mesajı.

---

## F5 — Mobil arayüz

**GÖREV:** İstek: QR/URL/PIN kartı, alınan dosyalar listesi, telefondan PC'ye gönderme, gelen metin · Faz: F5 · Kabul: iki yönlü transfer telefondan yönetilebiliyor, liste anlık güncel · Commit: evet

Kapsam:
1. Durum kartı: kapalı → Başlat; açık → QR (qr_flutter), kopyalanabilir URL, PIN, Durdur. starting'de progress, error'da mesaj + Tekrar dene.
2. "Alınan dosyalar": ad, boyut, tarih. Dokun → `open_filex`; uzun bas → alt sayfa: Paylaş (`share_plus`) / Sil (onaylı).
3. "Bilgisayara gönder": `file_picker` (çoklu) → paylaşım klasörüne kopya. >500 MB dosyada kopya yerine yol referansı tutma seçeneğini değerlendir; karar §7'ye.
4. Gelen metin: üstte banner, "Kopyala" → panoya.
5. ServerEvent → SnackBar ("x alındı"), liste yenilenir.
6. LayoutBuilder: genişlik ≥600 → QR ve liste yan yana.
7. Paketler (onaylı): open_filex, share_plus, file_picker — güncel sürüm Pub'dan doğrulanır.

Test:
- T2 widget `test/ui/home_running_test.dart` (fake controller): running → QR widget'ı + URL + PIN görünür; stopped → QR yok; error → mesaj + Tekrar dene.
- T2 widget `test/ui/received_list_test.dart`: 3 dosya → 3 satır, boyut formatlı; uploaded olayı → satır eklenir; sil onayı → controller.delete çağrıldı.
- T2 widget: genişlik 800 → Row düzeni, 360 → Column düzeni.
- T1 `test/unit/controller_events_test.dart`: textReceived olayı → `lastText` güncellenir; stop → url/pin null.

Cihaz (T5 → §9):
1. Ekrandaki URL'yi PC tarayıcısına yaz (veya QR'ı ikinci bir telefonla okut) → arayüz açılıyor; `/login`'de PIN ile giriş çalışıyor.
2. PC'den yükle → telefonda SnackBar + listede satır; log `[LD/Upload] done name=... bytes=...`.
3. Telefondan PDF seç → PC listesinde görünüyor, indiriliyor.
4. PC'den metin gönder → telefonda banner, Kopyala çalışıyor.

---

## F6 — Android arka plan ve depolama

**GÖREV:** İstek: foreground service + wakelock, Download/LocalDrop'a kayıt (MediaStore), cleartext ayarının temizlenmesi · Faz: F6 · Kabul: ekran kilitliyken 2 GB upload tamamlanıyor, dosya Dosyalar uygulamasında görünüyor · Commit: evet

Kapsam (manifest/izin değişikliği → plan onayı zorunlu):
1. FGS paketi: `flutter_foreground_task` (güncel sürüm doğrulanır). Bildirim: "Local Drop çalışıyor — <IP>:<PORT>" + "Durdur" aksiyonu.
2. Android 14+: FGS türü seçimi (K5). `dataSync` ise Android 15 süre limiti → `onTimeout` geldiğinde sunucu kapanır, bildirim "Süre doldu, tekrar başlat". Seçim ve gerekçe §7'ye.
3. `POST_NOTIFICATIONS` (13+) runtime izni; reddedilirse sunucu yine çalışır, kullanıcıya not.
4. Transfer sürerken wakelock (`wakelock_plus`) + Wi-Fi kilidi; transfer sayısı 0'a inince bırakılır.
5. Depolama: Ayarlar'da "Uygulama klasörü / İndirilenler"; İndirilenler → MediaStore ile `Download/LocalDrop`. `.part` her zaman uygulama klasöründe, bitince MediaStore'a taşınır. MANAGE_EXTERNAL_STORAGE YOK.
6. `usesCleartextTraffic` kaldırılır (S1); gelen sunucu trafiğini etkilemediği T4 ile doğrulanır.

Test:
- T1 `test/unit/wakelock_policy_test.dart`: aktif transfer sayacı 0→1 acquire, 1→2 tek acquire, 2→0 release; hata ile biten transfer de sayacı düşürür.
- T2 `test/unit/storage_target_test.dart` (fake MediaStore adaptörü): İndirilenler seçiliyken bitmiş dosya taşınır, `.part` hiç taşınmaz; taşıma hatasında dosya uygulama klasöründe kalır ve olay `error` yayınlanır.
- APK: `flutter build apk --debug` (manifest değişti).

Cihaz (T5 → §9):
1. Başlat → kalıcı bildirim görünüyor; "Durdur" → sunucu kapanıyor, log `[LD/Fgs] stop by notification`.
2. Ekranı kilitle, PC'den 2 GB yükle → tamamlanıyor; sha256 eşit.
3. Uygulamayı son uygulamalardan kaydır → sunucu çalışmaya devam ediyor (MIUI: otomatik başlatma açık).
4. İndirilenler seçili → dosya Dosyalar > Download/LocalDrop'ta.
5. Bildirim izni reddedildi → sunucu yine çalışıyor, uyarı metni görünüyor.
6. Cleartext kaldırıldıktan sonra T4 F3 komutları aynen çalışıyor.

---

## F7 — Sertleştirme

**GÖREV:** İstek: rate limit, disk dolu, ağ değişiminde yeniden başlatma, eksik test kapsaması · Faz: F7 · Kabul: lib/services + lib/server satır kapsaması ≥%80, tüm testler geçer · Commit: evet

Kapsam:
1. `rate_limiter.dart`: IP başına yanlış token sayacı, §5 limit → 429 + `Retry-After`. Saat enjekte edilebilir (test için).
2. Disk dolu (`FileSystemException` ENOSPC) → 507 + "Telefonda yer yok"; `.part` silinir.
3. Ağ değişimi (IP değişti) → sunucu yeni IP ile yeniden başlar, yeni token/QR, SnackBar "Ağ değişti, QR yenilendi". Aktif transfer varsa transfer bitene kadar ertelenir.
4. Transfer sürerken Durdur → onay penceresi ("Aktif transfer iptal edilecek").
5. `flutter test --coverage` + `lcov` özeti → §6'ya yüzde.

Test:
- T1 `test/unit/rate_limiter_test.dart`: 10 yanlış → 11.'si 429; 60 sn sonra (fake saat) tekrar 401; farklı IP etkilenmez; doğru token sayacı sıfırlar.
- T2 `test/server/disk_full_test.dart`: fake storage ENOSPC fırlatır → 507, `.part` yok.
- T1 `test/unit/network_restart_test.dart`: IP değişimi + aktif transfer 0 → restart; aktif transfer 1 → bekler, 0 olunca restart.
- T3 `test/integration/abuse_test.dart`: `%2e%2e%2f`, çift encode `%252e%252e`, mutlak yol `/data/...`, null byte `a%00.txt` → hepsi 400/404, kök dışına dosya yazılmaz/okunmaz.

Cihaz (T5 → §9):
1. Transfer sırasında Wi-Fi değiştir → transfer hata verir, yeni QR çıkar, yarım dosya listede yok.
2. Telefon depolaması doluyken yükle → PC'de "Telefonda yer yok".

---

## F8 — Yayın hazırlığı

**GÖREV:** İstek: ikon, applicationId, onboarding, ayarlar, release imzası hazırlığı, Play Store notları · Faz: F8 · Kabul: `flutter build appbundle --release` başarılı (imza dosyası kullanıcıda), docs/play_store.md hazır · Commit: evet

Kapsam:
1. `flutter_launcher_icons` (adaptive) + `flutter_native_splash` (dev_dependencies).
2. applicationId `com.ismail.localdrop`, label "Local Drop", versionCode/versionName.
3. İlk açılış onboarding (3 sayfa): aynı Wi-Fi gerekli · QR okut veya PIN gir · Güvenlik: adres yalnız sende, sunucuyu işin bitince kapat. Gösterildi bilgisi SharedPreferences.
4. Ayarlar: port, kayıt yeri (F6), otomatik durdurma (X dk transfer yoksa kapat; varsayılan 15 dk → §5'e eklenir), tema.
5. `android/key.properties` + `*.jks` gitignore'da; `build.gradle.kts` release imzası key.properties varsa okunur, yoksa debug ile imzalanır ve uyarı loglanır.
6. `docs/play_store.md`: izin gerekçeleri (INTERNET, ACCESS_WIFI_STATE, POST_NOTIFICATIONS, FOREGROUND_SERVICE_<tür>), FGS beyan metni + video senaryosu, Data Safety (veri toplanmaz, cihaz dışına gönderilmez), gizlilik politikası maddeleri.

Test:
- T2 widget `test/ui/onboarding_test.dart`: ilk açılış → onboarding; tamamla → bir daha görünmez.
- T1 `test/unit/auto_stop_test.dart`: fake saat; 15 dk transfer yok → stop; transfer varken süre sıfırlanır.
- Tam regresyon: `flutter analyze` + `flutter test` + `flutter build appbundle --release`.

Cihaz (T5 → §9):
1. Temiz kurulum → onboarding → QR → transfer uçtan uca.
2. 15 dk boşta → sunucu kendiliğinden kapanıyor, bildirim kalkıyor.
3. Release build'de `[LD/` logu YOK (kDebugMode).
