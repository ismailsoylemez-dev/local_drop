import 'dart:async';

import 'package:local_drop/services/network_service.dart';

class FakeNetworkService extends NetworkService {
  final controller = StreamController<NetworkResult>();

  @override
  Stream<NetworkResult> watch() => controller.stream;

  @override
  Future<NetworkResult> current() async => const NoNetwork();
}
