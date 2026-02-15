import 'dart:async';

import 'package:neurosity/neurosity.dart';
import 'package:neurosity/src/api/client.dart';
import 'package:test/test.dart';

void main() {
  group('Neurosity', () {
    late FakeClient client;

    setUp(() {
      client = FakeClient();
    });

    test('connect initializes underlying client', () async {
      final neurosity = Neurosity(client: client);

      await neurosity.connect();

      expect(client.didConnect, isTrue);
    });

    test('login auto-selects configured device id', () async {
      final neurosity = Neurosity(
        options: const NeurosityOptions(deviceId: 'device-2'),
        client: client,
      );
      await neurosity.connect();

      await neurosity.login(
        NeurosityCredentials.withEmail(
          email: 'email@example.com',
          password: 'password',
        ),
      );

      expect(client.selectedDeviceId, 'device-2');
    });

    test('login auto-selects first device when device id is not set', () async {
      final neurosity = Neurosity(client: client);
      await neurosity.connect();

      await neurosity.login(
        NeurosityCredentials.withCustomToken('custom-token'),
      );

      expect(client.selectedDeviceId, 'device-1');
    });

    test('login does not auto-select when autoSelectDevice is false', () async {
      final neurosity = Neurosity(
        options: const NeurosityOptions(autoSelectDevice: false),
        client: client,
      );
      await neurosity.connect();

      await neurosity.login(
        NeurosityCredentials.withCustomToken('custom-token'),
      );

      expect(client.selectedDeviceId, isNull);
    });

    test('exposes auth state stream and delegates logout/disconnect', () async {
      final neurosity = Neurosity(client: client);
      await neurosity.connect();

      final authStates = <bool>[];
      final sub = neurosity.onAuthStateChanged().listen(authStates.add);

      client.authStateController.add(true);
      await Future<void>.delayed(Duration.zero);
      await neurosity.logout();
      await neurosity.disconnect();
      await sub.cancel();

      expect(authStates, contains(true));
      expect(client.didLogout, isTrue);
      expect(client.didDisconnect, isTrue);
    });

    test('focus requests awareness metric with focus label', () async {
      final neurosity = Neurosity(client: client);
      await neurosity.connect();

      neurosity.focus();

      expect(client.lastMetricName, 'awareness');
      expect(client.lastMetricLabel, 'focus');
      expect(client.lastMetricAtomic, isFalse);
    });
  });
}

class FakeClient extends Client {
  bool didConnect = false;
  bool didDisconnect = false;
  bool didLogout = false;
  String? selectedDeviceId;
  String? lastMetricName;
  String? lastMetricLabel;
  bool? lastMetricAtomic;

  final authStateController = StreamController<bool>.broadcast();

  final Device device1 = const Device(
    apiVersion: 'v1',
    channelNames: <String>['CP3'],
    channels: 1,
    deviceId: 'device-1',
    deviceNickname: 'Crown 1',
    manufacturer: 'Neurosity',
    model: 'Notion',
    modelName: 'Notion 2',
    modelVersion: '2',
    osVersion: '17.1.0',
    samplingRate: 256,
  );

  final Device device2 = const Device(
    apiVersion: 'v1',
    channelNames: <String>['CP4'],
    channels: 1,
    deviceId: 'device-2',
    deviceNickname: 'Crown 2',
    manufacturer: 'Neurosity',
    model: 'Notion',
    modelName: 'Notion 2',
    modelVersion: '2',
    osVersion: '17.1.0',
    samplingRate: 256,
  );

  @override
  Future<void> connect() async {
    didConnect = true;
  }

  @override
  Future<void> disconnect() async {
    didDisconnect = true;
  }

  @override
  Future<void> login(NeurosityCredentials credentials) async {}

  @override
  Future<void> logout() async {
    didLogout = true;
  }

  @override
  Stream<bool> onAuthStateChanged() => authStateController.stream;

  @override
  Future<List<Device>> getDevices() async => <Device>[device1, device2];

  @override
  Future<Device> getDevice(String deviceId) async =>
      deviceId == device2.deviceId ? device2 : device1;

  @override
  Device? getSelectedDevice() {
    if (selectedDeviceId == null) {
      return null;
    }
    return selectedDeviceId == device2.deviceId ? device2 : device1;
  }

  @override
  Stream<Device?> onSelectedDeviceChange() => const Stream<Device?>.empty();

  @override
  Stream<DeviceStatus?> onStatus() => const Stream<DeviceStatus?>.empty();

  @override
  Stream<DeviceSetting?> onSettingsChange() =>
      const Stream<DeviceSetting?>.empty();

  @override
  Stream<Metric?> onMetric({
    required String metric,
    String? label,
    required bool atomic,
  }) {
    lastMetricName = metric;
    lastMetricLabel = label;
    lastMetricAtomic = atomic;
    return const Stream<Metric?>.empty();
  }

  @override
  Future<Device?> selectDevice(String deviceId) async {
    selectedDeviceId = deviceId;
    return getSelectedDevice();
  }
}
