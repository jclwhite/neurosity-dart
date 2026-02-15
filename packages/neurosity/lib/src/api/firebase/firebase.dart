import 'dart:async';

import 'package:firebase/firebase_io.dart';
import 'package:firebase_auth_dart/firebase_auth_dart.dart';
import 'package:firebase_core_dart/firebase_core_dart.dart';
import 'package:neurosity/src/api/client.dart';
import 'package:neurosity/src/models/models.dart';

///
class NeurosityFirebase extends Client {
  // todo(majid): add staging
  /// production
  final _firebaseOptions = const FirebaseOptions(
    appId: '',
    apiKey: 'AIzaSyB0TkZ83Fj0CIzn8AAmE-Osc92s3ER8hy8',
    authDomain: 'neurosity-device.firebaseapp.com',
    databaseURL: 'https://neurosity-device.firebaseio.com',
    projectId: 'neurosity-device',
    storageBucket: 'neurosity-device.appspot.com',
    messagingSenderId: '212595049674',
  );

  @override
  Future<void> connect() async {
    await Firebase.initializeApp(options: _firebaseOptions);
    _app = FirebaseAuth.instance;
  }

  late final FirebaseAuth _app;

  Device? _selectedDevice;
  Timer? _deviceChangesTimer;
  Timer? _deviceStatusTimer;
  Timer? _deviceSettingsTimer;
  Timer? _metricsTimer;

  final _deviceChanges = StreamController<Device?>.broadcast();
  final _deviceStatus = StreamController<DeviceStatus?>.broadcast();
  final _deviceSettings = StreamController<DeviceSetting?>.broadcast();
  final _metrics = StreamController<Metric?>.broadcast();

  FirebaseClient _database(String token) => FirebaseClient(token);

  @override
  Future<void> disconnect() async {
    _deviceChangesTimer?.cancel();
    _deviceStatusTimer?.cancel();
    _deviceSettingsTimer?.cancel();
    _metricsTimer?.cancel();
    await logout();
  }

  @override
  Future<void> login(NeurosityCredentials credentials) async {
    if (validateEmailPassword(credentials)) {
      await _app.signInWithEmailAndPassword(
        credentials.email!,
        credentials.password!,
      );
      return;
    }

    if (validateIdTokenAndProviderId(credentials)) {
      final provider = OAuthProvider(credentials.providerId!);
      final credential = provider.credential(idToken: credentials.idToken);
      await _app.signInWithCredential(credential);
      return;
    }

    if (validateCustomToken(credentials)) {
      await _app.signInWithCustomToken(credentials.customToken!);
      return;
    }

    throw ArgumentError(
      'Credentials must include email/password, idToken/providerId, or customToken.',
    );
  }

  @override
  Future<void> logout() async {
    await _app.signOut();
    _selectedDevice = null;
  }

  @override
  Stream<bool> onAuthStateChanged() {
    return _app.authStateChanges().map((user) => user != null);
  }

  Future<String> _getDBPath(String path) async {
    final auth = await _app.currentUser!.getIdToken();
    return '${_firebaseOptions.databaseURL}/$path.json?auth=$auth';
  }

  Future<Map<String, dynamic>?> _getDeviceFromPath(
    String deviceId,
    String path,
  ) async {
    if (_app.currentUser == null) {
      throw Exception('User is not logged in.');
    }
    final token = await _app.currentUser!.getIdToken();
    final db = _database(token);
    final devicePath = await _getDBPath('devices/$deviceId/$path');
    final response = await db.get(devicePath) as Map<String, dynamic>?;
    return response;
  }

  Future<Metric?> _getDeviceMetric(
    String deviceId,
    String metric,
    String label,
    bool atomic,
  ) async {
    if (_app.currentUser == null) {
      throw Exception('User is not logged in.');
    }
    const metricPath = 'metrics';
    final String path;
    if (atomic) {
      path = '$metricPath/$metric';
    } else {
      path = '$metricPath/$metric/$label';
    }
    final response = await _getDeviceFromPath(deviceId, path);
    if (response != null) {
      return Metric.fromJson(response);
    }
    return null;
  }

  @override
  Future<Device> getDevice(String deviceId) async {
    final response = await _getDeviceFromPath(deviceId, 'info');
    final json = response ?? {};
    return Device.fromJson(json);
  }

  ///
  FutureOr<DeviceStatus> getDeviceStatus(String deviceId) async {
    final response = await _getDeviceFromPath(deviceId, 'status');
    final json = response ?? {};
    return DeviceStatus.fromJson(json);
  }

  ///
  Future<DeviceSetting> getDeviceSetting(String deviceId) async {
    final response = await _getDeviceFromPath(deviceId, 'settings');
    final json = response ?? {};
    return DeviceSetting.fromJson(json);
  }

  @override
  Future<List<Device>> getDevices() async {
    if (_app.currentUser == null) {
      throw Exception('User is not logged in.');
    }
    final token = await _app.currentUser!.getIdToken();
    final db = _database(token);
    final userId = _app.currentUser!.uid;
    final userIdDevicesPath = await _getDBPath('users/$userId/devices');
    final response = await db.get(userIdDevicesPath);
    final obj = response as Map<String, dynamic>?;
    if (obj == null) {
      return <Device>[];
    }
    final deviceIds = obj.keys;
    final devices = <Device>[];

    for (final deviceId in deviceIds) {
      final device = await getDevice(deviceId);
      devices.add(device);
    }

    return devices;
  }

  @override
  Future<Device?> selectDevice(String deviceId) async {
    final devices = await getDevices();
    final device = devices
        .where(
          (device) => device.deviceId == deviceId,
        )
        .first;
    _selectedDevice = device;
    return device;
  }

  @override
  Device? getSelectedDevice() => _selectedDevice;

  @override
  Stream<Device?> onSelectedDeviceChange() {
    _deviceChangesTimer?.cancel();
    _deviceChangesTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_selectedDevice != null) {
          final updatedDevice = await getDevice(_selectedDevice!.deviceId);
          _deviceChanges.add(updatedDevice);
        }
      },
    );
    return _deviceChanges.stream;
  }

  @override
  Stream<DeviceStatus?> onStatus() {
    _deviceStatusTimer?.cancel();
    _deviceStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_selectedDevice != null) {
          final updated = await getDeviceStatus(
            _selectedDevice!.deviceId,
          );
          _deviceStatus.add(updated);
        }
      },
    );

    return _deviceStatus.stream;
  }

  @override
  Stream<DeviceSetting?> onSettingsChange() {
    _deviceSettingsTimer?.cancel();
    _deviceSettingsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_selectedDevice != null) {
          final updated = await getDeviceSetting(
            _selectedDevice!.deviceId,
          );
          _deviceSettings.add(updated);
        }
      },
    );

    return _deviceSettings.stream;
  }

  @override
  Stream<Metric?> onMetric({
    required String metric,
    String? label,
    required bool atomic,
  }) {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_selectedDevice != null) {
          final updated = await _getDeviceMetric(
            _selectedDevice!.deviceId,
            metric,
            label ?? '',
            atomic,
          );
          _metrics.add(updated);
        }
      },
    );

    return _metrics.stream;
  }
}
