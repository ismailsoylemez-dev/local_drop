# Play Store hazırlığı — Local Drop

Play Console formları doldurulurken kullanılacak metinler ve yayın adımları.
Uygulama: **Local Drop** · applicationId `com.ismail.localdrop` · sürüm `pubspec.yaml` → `version`.

---

## 1. Kısa ve uzun açıklama

**Kısa (≤80):** Telefon ile bilgisayar arasında, aynı Wi-Fi üzerinden kablosuz dosya ve metin paylaşımı.

**Uzun:**
Local Drop telefonunda küçük bir yerel sunucu açar. Aynı Wi-Fi ağındaki bilgisayarda tarayıcıyla QR'daki adrese gir; dosyaları sürükle-bırak ile telefona gönder, telefondaki dosyaları indir, metin ve bağlantı paylaş.

- İnternet, hesap veya bulut yok: dosyalar yalnız yerel ağda, iki cihaz arasında gider.
- Bilgisayara program kurmak gerekmez; herhangi bir modern tarayıcı yeter.
- Her başlatmada yeni erişim anahtarı ve PIN; işin bitince sunucuyu kapat ya da uzun süre kullanılmazsa kendiliğinden kapansın.
- Büyük dosyalar (4 GB'a kadar) ekran kilitliyken de aktarılır.

---

## 2. İzinler ve gerekçeleri

| İzin | Neden |
|---|---|
| `INTERNET` | Yerel ağdan gelen HTTP bağlantılarını kabul etmek için soket açar. Uygulama dışarıya (internete) istek atmaz. |
| `ACCESS_NETWORK_STATE` | Wi-Fi/hotspot bağlantısını ve IP değişimini algılamak; ağ yokken Başlat'ı pasif yapmak. |
| `ACCESS_WIFI_STATE` | Wi-Fi IP adresini okumak (QR'daki adres). Konum izni istenmez; SSID okunmaz. |
| `POST_NOTIFICATIONS` | Sunucu açıkken gösterilen kalıcı bildirim (Android 13+). Reddedilirse sunucu yine çalışır. |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` | Kullanıcının başlattığı dosya aktarımı ekran kapalıyken / uygulama arka plandayken sürsün. |
| `WAKE_LOCK` | Yalnız aktif transfer sürerken CPU'nun uyumaması (transfer bitince bırakılır). |

Kullanılmayan ve manifestte **kaldırılan** izinler: `READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES/VIDEO/AUDIO` (open_filex ekliyordu), `RECEIVE_BOOT_COMPLETED`. `MANAGE_EXTERNAL_STORAGE` hiç yok. İndirilenler'e kayıt MediaStore ile yapılır (izin gerekmez, Android 10+).

---

## 3. Ön plan servisi beyanı (Play Console → Uygulama içeriği → Ön plan hizmeti izinleri)

**Tür:** Veri senkronizasyonu (`dataSync`)

**Beyan metni:**
> Local Drop, kullanıcının "Başlat" düğmesiyle açtığı yerel bir HTTP sunucusu üzerinden telefon ile aynı Wi-Fi ağındaki bilgisayar arasında dosya aktarır. Aktarımlar birkaç GB olabilir ve kullanıcı bu sırada ekranı kilitleyebilir veya başka uygulamaya geçebilir. Ön plan hizmeti yalnız sunucu açıkken çalışır, kalıcı bildirimde adres ve "Durdur" düğmesi gösterilir. Kullanıcı Durdur'a bastığında, uygulamada sunucuyu kapattığında veya ayarlardaki süre (varsayılan 15 dk) boyunca aktarım olmadığında hizmet kapanır. Android 15'in dataSync süre sınırı dolduğunda da sunucu kapanır ve kullanıcıya bildirilir.

**Kullanıcıya etkisi:** Hizmet durdurulursa devam eden dosya aktarımı yarıda kesilir ve yarım dosya silinir.

**Video senaryosu (≤30 sn, ekran kaydı):**
1. Uygulamayı aç → **Başlat** → kalıcı bildirim "Local Drop çalışıyor — 192.168.x.x:8080" görünür.
2. Bilgisayarda tarayıcıyla adresi aç, büyük bir dosyayı sürükle; ilerleme çubuğu başlar.
3. Telefonda ekranı kilitle; bilgisayarda aktarımın sürdüğünü göster, tamamlanır.
4. Telefonu aç → dosya listede; bildirimdeki **Durdur** → bildirim kalkar, sunucu kapanır.

---

## 4. Veri güvenliği (Data Safety) formu

- **Veri topluyor mu?** Hayır.
- **Veri paylaşıyor mu?** Hayır.
- Gerekçe: Uygulamanın sunucusu yok; analitik, reklam, çökme raporu, üçüncü taraf SDK yok. Dosyalar ve metinler yalnız kullanıcının kendi cihazları arasında, yerel ağ üzerinden doğrudan aktarılır ve hiçbir dış sunucuya gönderilmez.
- **Aktarımda şifreleme:** Hayır — yerel ağda HTTP (TLS yok). Erişim tek kullanımlık rastgele anahtar/PIN ile korunur. Formda "veri toplanmadığı" için bu soru çıkmazsa açıklamaya not düşülebilir.
- **Kullanıcı veriyi silebilir mi?** Evet: uygulamadaki listeden silme, ya da uygulamayı kaldırma (uygulama klasörü silinir; İndirilenler'e taşınanlar kullanıcıda kalır).

---

## 5. Gizlilik politikası maddeleri

Politika sayfası (zorunlu URL) şu maddeleri içermeli:

1. **Toplanan veri yok.** Uygulama kişisel veri, cihaz kimliği, konum veya kullanım istatistiği toplamaz ve saklamaz.
2. **Dosyalar ve metinler** yalnız kullanıcının başlattığı aktarımda, aynı yerel ağdaki cihazlar arasında doğrudan gider; geliştiriciye veya üçüncü taraflara ulaşmaz.
3. **Saklama:** Alınan dosyalar telefonda uygulama klasöründe ya da kullanıcı seçerse İndirilenler/LocalDrop'ta durur; kullanıcı istediği an silebilir.
4. **Erişim güvenliği:** Her başlatmada yeni rastgele anahtar ve PIN üretilir; hatalı denemeler sınırlanır. Aynı ağdaki adresi bilen kişi dosyalara erişebilir — kullanıcı işi bitince sunucuyu kapatmalıdır; uygulama bir süre aktarım olmazsa kendiliğinden kapanır.
5. **İzinler** (bölüm 2) ve ne için kullanıldıkları.
6. **Çocuklar:** Uygulama çocuklara yönelik değildir ve onlardan veri toplamaz.
7. **İletişim** e-postası ve politikanın güncellenme tarihi.

---

## 6. Yayın adımları

1. **Anahtar oluştur** (bir kez; dosyayı ve şifreleri güvenli yerde yedekle, kaybedilirse güncelleme yayınlanamaz):
   ```powershell
   keytool -genkey -v -keystore C:\anahtarlar\localdrop-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **`android/key.properties`** (gitignore'da; repoya girmez):
   ```properties
   storePassword=<şifre>
   keyPassword=<şifre>
   keyAlias=upload
   storeFile=C:/anahtarlar/localdrop-upload.jks
   ```
   Dosya yoksa release yine derlenir ama **debug anahtarıyla** imzalanır ve Gradle uyarı verir — o paket Play'e yüklenemez.
3. Her yeni yüklemede `pubspec.yaml` → `version: 1.0.0+1` içindeki `+N` (versionCode) artırılır.
4. Derle:
   ```powershell
   flutter build appbundle --release
   ```
   Çıktı: `build\app\outputs\bundle\release\app-release.aab`.
5. Play Console → Dahili test kanalına yükle; Play App Signing'i etkinleştir.
6. Ekran görüntüleri (en az 2 telefon): ana ekran (QR + PIN), dosya listesi, bilgisayar tarayıcı arayüzü, ayarlar. Özellik grafiği 1024×500 (teal zemin + damla ikonu).
7. İçerik derecelendirmesi anketi (şiddet/kumar vb. yok), hedef kitle 18+, reklam yok.

---

## 7. Bilinen sınırlar (mağaza notu / SSS)

- Bilgisayar ile telefon aynı ağda olmalı; misafir/kurumsal ağlardaki "istemci yalıtımı" bağlantıyı engeller.
- Bazı üreticiler (MIUI vb.) arka plan uygulamalarını kapatır: "Otomatik başlatma" açık, pil "Kısıtlama yok" önerilir.
- Android 15+'ta dataSync hizmeti 24 saatte toplam ~6 saatle sınırlıdır; dolunca sunucu kapanır.
- Bağlantı HTTP'dir (yerel ağ); halka açık Wi-Fi'de kullanılması önerilmez.
