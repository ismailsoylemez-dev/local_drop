import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/log.dart';
import '../../services/file_actions.dart';
import '../../services/storage_service.dart';
import '../../state/server_controller.dart';

/// Paylaşım klasörü: PC'den gelenler + telefondan "Bilgisayara gönder"le
/// eklenenler. Dokun → aç; uzun bas → Paylaş / Sil.
class FilesPanel extends StatefulWidget {
  const FilesPanel({super.key});

  @override
  State<FilesPanel> createState() => _FilesPanelState();
}

class _FilesPanelState extends State<FilesPanel> {
  bool _importing = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendToPc() async {
    final controller = context.read<ServerController>();
    final actions = context.read<FileActions>();
    final List<PickedFile> picked;
    try {
      picked = await actions.pick();
    } catch (e) {
      Log.d('Files', 'pick hata: $e');
      if (mounted) _snack('Dosya seçilemedi');
      return;
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _importing = true);
    var ok = 0;
    String? error;
    for (final file in picked) {
      try {
        await controller.importFile(file.name, file.read());
        ok++;
      } on FileTooLargeException {
        error = '${file.name}: dosya çok büyük';
      } catch (e) {
        if (isDiskFull(e)) {
          error = 'Telefonda yer yok';
          break;
        }
        Log.d('Files', 'import hata ${file.name}: $e');
        error = '${file.name} eklenemedi';
      }
    }
    if (!mounted) return;
    setState(() => _importing = false);
    _snack(error ?? '$ok dosya bilgisayara açıldı');
  }

  Future<void> _open(StoredFile file) async {
    final controller = context.read<ServerController>();
    final actions = context.read<FileActions>();
    try {
      final error = await actions.open(controller.fileFor(file.name).path);
      if (error != null && mounted) _snack(error);
    } catch (e) {
      Log.d('Files', 'open hata: $e');
      if (mounted) _snack('Dosya açılamadı');
    }
  }

  Future<void> _share(StoredFile file) async {
    final controller = context.read<ServerController>();
    final actions = context.read<FileActions>();
    try {
      await actions.share(controller.fileFor(file.name).path);
    } catch (e) {
      Log.d('Files', 'share hata: $e');
      if (mounted) _snack('Paylaşılamadı');
    }
  }

  Future<void> _confirmDelete(StoredFile file) async {
    final controller = context.read<ServerController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosya silinsin mi?'),
        content: Text(file.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteFile(file.name);
      if (mounted) _snack('${file.name} silindi');
    } catch (e) {
      Log.d('Files', 'delete hata: $e');
      if (mounted) _snack('Silinemedi');
    }
  }

  Future<void> _showActions(StoredFile file) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(file.name, maxLines: 2),
              subtitle: Text(formatSize(file.size)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Paylaş'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Sil'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'share':
        await _share(file);
      case 'delete':
        await _confirmDelete(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = context.select<ServerController, List<StoredFile>>(
      (c) => c.files,
    );
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Dosyalar', style: textTheme.titleMedium),
                  ),
                  if (_importing)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: _sendToPc,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Bilgisayara gönder'),
                    ),
                ],
              ),
            ),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Henüz dosya yok. Bilgisayardan gönderilenler ve buradan '
                  'eklediklerin burada görünür.',
                  style: textTheme.bodySmall,
                ),
              )
            else
              for (final file in files)
                ListTile(
                  key: ValueKey('file-${file.name}'),
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatSize(file.size)} · ${formatDate(file.modified)}',
                  ),
                  onTap: () => _open(file),
                  onLongPress: () => _showActions(file),
                ),
          ],
        ),
      ),
    );
  }
}
