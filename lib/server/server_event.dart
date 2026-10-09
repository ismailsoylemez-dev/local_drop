/// Sunucudan UI'ye giden olaylar.
sealed class ServerEvent {
  const ServerEvent();
}

final class FileUploaded extends ServerEvent {
  const FileUploaded(this.name, this.bytes);
  final String name;
  final int bytes;
}

final class FileDeleted extends ServerEvent {
  const FileDeleted(this.name);
  final String name;
}

final class TextReceived extends ServerEvent {
  const TextReceived(this.text);
  final String text;
}

final class ServerErrorEvent extends ServerEvent {
  const ServerErrorEvent(this.message);
  final String message;
}

/// IP değişti, sunucu yeni adres/token ile yeniden başladı (controller yayar).
final class NetworkChanged extends ServerEvent {
  const NetworkChanged(this.ip);
  final String ip;
}
