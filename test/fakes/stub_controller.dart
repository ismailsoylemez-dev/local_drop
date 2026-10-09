import 'dart:io';

import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:local_drop/state/server_controller.dart';

import 'fake_network_service.dart';

/// Durumu doğrudan ayarlanan controller (widget testleri). Dosya sistemi ve
/// ağ kullanmaz; çağrıları kaydeder.
class StubController extends ServerController {
  StubController()
    : super(
        network: FakeNetworkService(),
        storage: StorageService(Directory('stub-yok')),
      );

  ServerStatus stubStatus = ServerStatus.stopped;
  String? stubUrl;
  String? stubPin;
  String? stubError;
  NetworkResult? stubNetwork = const Connected('192.168.1.20');
  List<StoredFile> stubFiles = const [];
  String? stubText;
  String? stubNotice;
  bool stubDownloadsSupported = true;
  SaveLocation stubSaveLocation = SaveLocation.appFolder;
  final deleted = <String>[];
  int startCalls = 0;
  int stopCalls = 0;
  int stubActiveTransfers = 0;
  int clearTextCalls = 0;

  @override
  ServerStatus get status => stubStatus;
  @override
  String? get url => stubUrl;
  @override
  String? get pin => stubPin;
  @override
  String? get errorMessage => stubError;
  @override
  NetworkResult? get network => stubNetwork;
  @override
  List<StoredFile> get files => stubFiles;
  @override
  String? get lastText => stubText;
  @override
  String? get notice => stubNotice;
  @override
  bool get downloadsSupported => stubDownloadsSupported;
  @override
  SaveLocation get saveLocation => stubSaveLocation;

  @override
  Future<void> setSaveLocation(SaveLocation value) async {
    stubSaveLocation = value;
    notifyListeners();
  }

  @override
  bool get canStart =>
      stubNetwork is Connected &&
      (stubStatus == ServerStatus.stopped || stubStatus == ServerStatus.error);

  void update() => notifyListeners();

  @override
  Future<void> refreshFiles() async {}

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  int get activeTransfers => stubActiveTransfers;

  @override
  void clearText() {
    clearTextCalls++;
    stubText = null;
    notifyListeners();
  }

  @override
  Future<bool> deleteFile(String name) async {
    deleted.add(name);
    return true;
  }
}
