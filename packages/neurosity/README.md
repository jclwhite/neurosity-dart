# Neurosity Dart SDK

The Neurosity SDK for Dart provides a typed interface for Neurosity headsets, including authentication, device selection, and real-time metrics streams.

## Installation

```bash
dart pub add neurosity
```

## Quick Start

```dart
import 'package:neurosity/neurosity.dart';

Future<void> main() async {
  final neurosity = Neurosity(
    options: const NeurosityOptions(
      // Optional: when set, this device is selected automatically after login.
      deviceId: 'DEVICE_ID',
      // Optional: disable to manually select a device after login.
      autoSelectDevice: true,
    ),
  );

  await neurosity.connect();

  // Supports email/password, custom tokens, and idToken/providerId auth.
  await neurosity.login(
    NeurosityCredentials.withEmail(
      email: 'you@example.com',
      password: 'password',
    ),
  );

  // Emits true/false based on authentication state.
  final authSub = neurosity.onAuthStateChanged().listen(print);

  // Access selected device (selected automatically by default).
  final selectedDevice = neurosity.getSelectedDevice();
  print(selectedDevice);

  // Subscribe to metrics.
  final focusSub = neurosity.focus().listen(print);

  await Future<void>.delayed(const Duration(seconds: 5));

  await focusSub.cancel();
  await authSub.cancel();
  await neurosity.logout();
  await neurosity.disconnect();
}
```

## Device Selection Behavior

By default (`autoSelectDevice: true`), the SDK selects:

1. `options.deviceId` when provided.
2. Otherwise, the first device returned by `getDevices()`.

Set `autoSelectDevice: false` to opt out and call `selectDevice(...)` manually.

## Available Streams

- `onSelectedDeviceChange()`
- `onStatus()`
- `onSettingsChange()`
- `brainwaves(...)`
- `signalQuality()`
- `channelAnalysis()`
- `accelerometer()`
- `awareness(...)`
- `focus()`
- `calm()`
- `kinesis(...)`
- `predictions(...)`

## Testing

Run tests from the package directory:

```bash
dart test
```
