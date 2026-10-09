/// Uygulama genelindeki sabitler (PROJE_OZET §5). Koda sihirli sayı yazılmaz.
abstract final class AppConstants {
  static const String appTitle = 'Local Drop';

  /// Sunucu ilk boş portu bu aralıkta arar (dahil).
  static const int portRangeStart = 8080;
  static const int portRangeEnd = 8090;

  /// Bind adresi: tüm IPv4 arayüzleri.
  static const String bindAddress = '0.0.0.0';

  /// Erişim token'ı: base62, Random.secure, her start'ta yeni.
  static const int tokenLength = 16;
  static const String tokenAlphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /// QR okutulamazsa /login'de girilen PIN.
  static const int pinLength = 6;

  /// Tek dosya üst sınırı: 4 GB.
  static const int maxFileBytes = 4 * 1024 * 1024 * 1024;

  /// Yanlış token limiti: IP başına pencere içinde en fazla bu kadar deneme.
  static const int wrongTokenLimit = 10;
  static const Duration wrongTokenWindow = Duration(minutes: 1);

  /// Ağ (IP) yoklama aralığı.
  static const Duration networkPollInterval = Duration(seconds: 3);

  /// Mobil veri arayüz adlarında geçen parçalar (v4-rmnet_data0 gibi CLAT dahil).
  static const List<String> mobileIfaceMarkers = ['rmnet', 'ccmni'];

  /// Yüklenmekte olan dosyanın geçici uzantısı.
  static const String partExtension = '.part';

  /// Alınan dosyaların uygulama belgeleri altındaki klasörü.
  static const String receivedDirName = 'received';

  /// Dosya adı üst sınırı (karakter, uzantı dahil) ve boş ad yerine kullanılan ad.
  static const int maxNameLength = 200;
  static const String fallbackFileName = 'dosya';

  /// Token'ın taşındığı query parametresi ve cookie adı.
  static const String tokenQueryParam = 't';
  static const String tokenCookieName = 'ld_token';

  /// /login form gövdesi üst sınırı.
  static const int loginBodyMaxBytes = 1024;

  /// Log öneki: [LD/<alan>].
  static const String logPrefix = 'LD';

  /// Log'da maskelenmiş değerin açık kalan karakter sayısı.
  static const int maskVisibleChars = 2;
}
