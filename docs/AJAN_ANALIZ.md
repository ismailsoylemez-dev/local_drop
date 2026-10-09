# AJAN ANALİZ PROMPTU — local_drop
<!-- Kullanım: ajana "docs/AJAN_ANALIZ.md'ye göre analiz et" de. KOD DEĞİŞTİRMEZ. -->
<!-- Kurallar: AJAN_IS.md §2 (token) ve §5 (git) burada da geçerli. -->

## ODAK (isteğe bağlı)
- Alan: (boşsa tüm proje)
- Derin inceleme modülü: (boşsa YOK — bkz. §5)

---

## 1. KAYNAK
- Tek kaynak: `docs/PROJE_OZET.md`. Kod tarama YOK.
- Fark kontrolü (AJAN_IS §1.3 komutu):
  - Boş → yalnız özet.
  - Dolu → yalnız değişen hunk'lar; bütçe ≤5 dosya × 80 satır. Fark özete işlenir.
- Özetteki bir şüpheyi doğrulama: Grep + ±20 satır, en fazla 3 kontrol. Daha fazlası gerekiyorsa listelenir, okunmaz.

## 2. ÖZETTEN ÇIKARIM (kod okumadan)
Bölümleri çaprazla:
- §4 değişmez × §2 mimari × §7 karar → çelişki = mantık hatası adayı
- §5 sabitler → birim (sn/dk/bayt), sınır (< / ≤), çakışan değer
- §6 "Kod ✅ / Cihazda ⏳" → çalıştığı kanıtlanmamış özellik
- §6 "Test ⏳" ama "Kod ✅" → testsiz özellik
- §8 → önceliklendir: güvenlik açığı (yetkisiz erişim, path traversal) > veri kaybı (yarım dosya, üzerine yazma) > transfer kesilmesi > yanlış gösterim > kozmetik
- §9 → hangi bulguyu kapatır
- §10/§12 → aynı dosyaya art arda dokunuş = regresyon riski
- §3 boyutlar → 400 satırı aşan dosya bölünmeli
- §7 K5 + §11 → Play Store / Android sürüm engelleri (FGS türü, izinler)
Kodla doğrulanmamış çıkarım "aday" olarak işaretlenir; kesin gibi sunulmaz.

## 3. ÇIKTI (≤60 satır, tablo)
1. **Durum:** son commit · özet güncel mi (BASE..HEAD boş mu) · çalışma ağacı · aktif faz
2. **Hata / mantık hatası:** # | 🔴🟡🟢 | konu | yer | kanıt (§ / dosya:satır) | kesin/aday
3. **Güvenlik kontrolü:** token, rate limit, sanitize, resolve, XSS — her biri ✅/⏳/❌
4. **Çalışmayan / cihazda doğrulanmamış**
5. **İyileştirme + eklenebilecek özellik:** değer × maliyet (S/M/L)
6. **Sıradaki iş (P-n):** 3-5 madde, sıralı; her biri AJAN_IS GÖREV'ine kopyalanabilir tek satır

## 4. BİTİŞ
- Yeni bulgu → §8'e `S-n`; §12'ye analiz satırı (AJAN_IS §6 formatı, iş = `analiz`).
- Commit yalnız `docs/PROJE_OZET.md`: `docs(ozet): analiz YYYY-MM-DD`.

## 5. DERİN İNCELEME (yalnız ODAK'ta modül yazılıysa)
Özet, kayıtlı olmayan hatayı göremez. Bu yüzden yayın öncesi ve F3/F6/F7 sonrasında yapılır:
- Tek modül (ör. `server/handlers/upload_handler.dart`) + testi; Grep ile fonksiyon listesi → riskli fonksiyonlar ±40 satır.
- Öncelikli modüller: upload_handler, storage_service.resolve, auth_middleware, rate_limiter, web_ui (JS kısmı).
- Bütçe ≤600 satır okuma. Bulgular §8'e, modül notu §2/§3'e.
