# Idtra Flutter SDK (Biometrics & Active Liveness)

Official Flutter SDK for embedding **Idtra Biometric Face Verification** and **Active Liveness Detection** into Flutter mobile applications (iOS & Android).

---

## 1. Installation

Add `idtra_biometrics_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  idtra_biometrics_sdk: ^1.0.0
```

Run:
```bash
flutter pub get
```

---

## 2. Platform Permissions

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to perform facial biometric KYC and active liveness verification.</string>
```

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

---

## 3. Quick Start Example

```dart
import 'package:flutter/material.dart';
import 'package:idtra_biometrics_sdk/idtra_biometrics.dart';

void startKycVerification(BuildContext context) async {
  try {
    final result = await IdtraBiometrics.startVerification(
      context: context,
      apiKey: "sk_live_...",
      nin: "12345678901", // or use bvn: "22233344455"
    );

    if (result != null && result.isMatch) {
      print("Face Match Confirmed!");
      print("Citizen Name: ${result.citizenData?.fullName}");
      print("Confidence Score: ${result.confidence}");
    } else {
      print("Verification failed or rejected: ${result?.message}");
    }
  } catch (e) {
    print("Verification Error: $e");
  }
}
```

---

## Direct API Verification (Without UI)

If you have your own custom camera viewfinder and want to send base64 selfie data directly:

```dart
final result = await IdtraBiometrics.directVerify(
  apiKey: "sk_live_...",
  serviceType: "NIN", // or "BVN"
  number: "12345678901",
  base64Image: "data:image/jpeg;base64,...",
);
```

---

## License

MIT © [Idtra Technologies Ltd](https://idtra.com)
