# Neurosity [WIP]

Monorepo for the Neurosity SDKs in Dart and Flutter.

## Packages

- `packages/neurosity`: Core Dart SDK.
- `packages/neurosity_flutter`: Flutter-facing package.

## Recent parity updates (vs JS SDK)

The Dart SDK now includes:

- Multi-provider authentication support (email/password, custom token, id token + provider).
- Auth state stream via `onAuthStateChanged()`.
- Session lifecycle methods `logout()` and `disconnect()`.
- Automatic device selection behavior after login (`deviceId` or first available device).
- Expanded unit tests covering lifecycle, auth-state wiring, metric subscription routing, and auto-selection.

See `packages/neurosity/README.md` for usage details.
