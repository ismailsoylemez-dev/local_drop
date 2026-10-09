# AJAN İŞ PROMPTU — local_drop
<!-- Kullanım: GÖREV'i doldur (veya FAZLAR.md'deki F<n> satırını kopyala) → ajana: "docs/AJAN_IS.md'yi oku ve GÖREV'i uygula." -->
<!-- Bu dosya her işte geçerli sabit kural setidir. -->

## GÖREV
<!-- Boşsa ajan DURUR ve sorar. -->
- İstek:
- Faz (varsa): F
- Dosya/alan (biliniyorsa):
- Kabul ölçütü:
- Commit: evet

---

## 1. BAŞLANGIÇ (sırayla)
1. `docs/PROJE_OZET.md` oku (oturumda TEK kez). Kod tarama YOK.
2. Görev bir fazsa: `docs/FAZLAR.md` içinde yalnız o faz bölümünü oku (`Grep "^## F"` → offset/limit). Diğer fazlar okunmaz.
3. Fark kontrolü (repo varsa):
   ```powershell
   $B = git log -1 --format=%h -- docs/PROJE_OZET.md
   git log --oneline "$B..HEAD"; git status --short
   ```
   Boş değilse: `git diff --stat` + yalnız ilgili hunk'lar; farkı özete işle, sonra göreve geç.
4. Görev belirsizse ya da §4 değişmezleriyle çelişiyorsa → TEK soru sor, DUR.
5. Plan ≤5 satır. Dosya silme, paket ekleme/kaldırma, manifest/izin değişikliği, UI tema değişikliği → önce ONAY.
   İstisna: FAZLAR.md'de o faz için adı geçen paketler onaylı sayılır.

## 2. TOKEN KURALLARI
- Yalnız görevin gerektirdiği dosya ve aralık okunur. Yer bilinmiyorsa önce Grep (sembol/dosya adı), sonra offset/limit ile ±30 satır.
- Aynı dosya/aralık oturumda İKİNCİ kez okunmaz. İstisna: kendi düzenlemenden sonra yalnız o aralık.
- >400 satırlık dosya baştan sona okunmaz (boyutlar: PROJE_OZET §3).
- OKUNMAZ: `build/`, `.dart_tool/`, `pubspec.lock` (sürüm gerekiyorsa `Select-String "^  <paket>:" -Context 0,4`), `ios/`, `macos/`, `linux/`, `windows/`, `web/`, `*.iml`, `.flutter-plugins-dependencies`, `android/.gradle/`.
- Paket API'si: önce `$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\<paket>-<sürüm>\lib` içinde Grep. Web araması yalnız orada bulunamazsa.
- Komut çıktısı filtreli okunur:
  - `flutter analyze ... 2>&1 | Select-String "error|warning|issues found|No issues"`
  - `flutter test ... 2>&1 | Select-String "FAIL|Error|Some tests|All tests|\+\d+ -\d+"`
- Alt ajan yok. Ara anlatım yok; tek rapor en sonda (§7).
- Aynı hatayı 3 denemede çözemezsen DUR, denenenleri raporla.

## 3. KOD KURALLARI
- Değişmezler: PROJE_OZET §4. Sabitler yalnız `core/constants.dart`'ta (§5); koda sihirli sayı yazılmaz.
- Dart null safety; `!` yalnız gerçekten garantiliyse. try/catch + kullanıcıya Türkçe mesaj; async sonrası `context.mounted`.
- Log: `core/log.dart` → `Log.d('<alan>', mesaj)` = `debugPrint('[LD/<alan>] ...')`, yalnız kDebugMode. Token/PIN maskeli.
- Saf mantık (sanitize, IP seçimi, format, rate limit) Flutter'a bağımlı olmayan saf fonksiyonlarda olur → unit test edilebilir.
- Görev dışı refactor YOK. Görev dışı fark edilen hata/şüphe düzeltilmez → §8'e `S-n` (yer + neden) olarak yazılır.

## 4. TEST
Katmanlar (ayrıntılı senaryolar: FAZLAR.md ilgili faz "Test" bölümü):
- **T1 Unit:** saf fonksiyonlar. `test/unit/`
- **T2 Handler:** `shelf` `Request` nesnesiyle handler/router çağrısı, ağ açmadan. `test/server/`
- **T3 Yerel entegrasyon:** gerçek sunucu `127.0.0.1` port 0'da, geçici klasörde, `HttpClient` ile. `test/integration/` (`flutter test` ile çalışır, cihaz gerekmez)
- **T4 PC manuel:** PowerShell `curl.exe` komutları (faz bölümünde hazır). Ajan çalıştırmaz → §9'a yazar.
- **T5 Cihaz:** adım + beklenen `[LD/...]` log satırı. Ajan çalıştırmaz → §9'a yazar.

Kurallar:
- Çalışırken yalnız ilgili dosya: `flutter test test/<klasör>/<x>_test.dart` ve `flutter analyze lib/<dosya> test/<dosya>`.
- Davranış değişikliği = en az 1 yeni veya güncellenmiş test. Hata düzeltmesi = önce hatayı yakalayan test.
- Commit öncesi BİR kez: `flutter analyze` (0 hata) + `flutter test`.
- APK (`flutter build apk --debug`) yalnız manifest/gradle/Kotlin değiştiyse.
- Dokunulmayan, daha önce geçmiş testler tekrar çalıştırılmaz ve raporda yeniden listelenmez.
- T3'te büyük dosya: diske yazılmış sabit dosya değil, akışla üretilen veri (ör. 50 MB) + sha256 karşılaştırması. Test sonunda geçici klasör silinir.

## 5. GIT
- Branch `dev`; main'e merge ve push YOK.
- `git add -A` / `git add .` / `git commit -a` YASAK; dosyalar adıyla eklenir.
- Mesaj: `<tip>(<alan>): <özet>` (tip: feat/fix/test/docs/chore). PROJE_OZET.md AYNI commit'te.
- GÖREV "Commit: hayır" ise commit yok; §12'ye `commitlenmedi`.

## 6. BİTİŞ — ÖZET GÜNCELLEME (ZORUNLU; atlanırsa iş bitmemiştir)
Okuma/analiz dahil HER işte. Dosya baştan yazılmaz; o an okunup Edit ile değiştirilir.
1. Saat: `Get-Date -Format "yyyy-MM-dd HH:mm"`.
2. Baştaki `<!-- OZET_META: ... -->` satırı: guncelleme, son_kod_commit, faz.
3. §12'ye tek satır HTML yorumu:
   `<!-- YYYY-MM-DD HH:mm | <hash|commitlenmedi> | <iş> | kod: a.dart:10-40 | test: x_test(+2) | analyze/test: OK | sonuç -->`
   Hash commit'ten önce bilinmez → `(bu commit)` yaz; sonraki iş gerçek hash ile düzeltir.
4. Değiştiyse: §2 mimari, §3 dosya haritası (satır sayısıyla), §5 sabit, §6 özellik tablosu, §7 karar, §8 (kapananı sil, yeni S-n ekle), §9 cihaz testi, §10 commit satırı.
5. Özet ≤15 KB; aşarsa §10/§12'nin eski satırları tek satırda birleştirilir.
6. Commit (izinliyse) → `git status --short` temiz mi kontrol.

## 7. RAPOR (kısa, kullanıcıya)
- Yapılan: 1-3 madde
- Etkilenen: `dosya:satır` listesi
- Test: komut → sonuç (T1/T2/T3 sayıları)
- Commit: hash / commitlenmedi · çalışma ağacı: temiz / kirli
- Özet: güncellendi (§ listesi)
- Senin yapacağın: T4 komutları + T5 cihaz adımları (§9 madde numaralarıyla)
