# BackSpace - Project Context & Documentation

## 1. Project Overview
* **Name**: BackSpace
* **Platform**: Flutter (Android Target)
* **Dart / Flutter Version**: Flutter 3.44+ / Dart 3.12+ (SDK `'>=3.0.0 <4.0.0'`)
* **Purpose**: Real-time personal chat application for active user groups (15-20 users).
* **Core Capabilities**:
  * Real-time text messaging
  * Media sharing (Images, Profile Pictures)
  * Presence tracking (Online / Last Active status)
  * User search & contact addition via email
  * Google Sign-In authentication

---

## 2. Infrastructure & Architecture Decisions

### A. Hybrid Backend (Firestore + Cloudinary)
* **Database & Auth**: Cloud Firestore and Firebase Authentication (Google Sign-In) are retained for text chat history and user profile data.
* **Storage Provider**: Migrated from **Firebase Storage** to **Cloudinary** (Free Plan: 25 monthly credits).
  * *Reason*: Firebase Storage free tier has a strict 1 GB/day download bandwidth cap that gets exhausted quickly by active chat groups. Cloudinary provides generous storage/bandwidth credits without daily caps.
* **Secure Deletion Proxy (Cloudflare Workers)**:
  * A free serverless Cloudflare Worker proxy handles Cloudinary signed deletion requests (`/destroy`).
  * Avoids embedding the Cloudinary `API_SECRET` inside the mobile client.
* **In-App Media Migration**:
  * Built a one-time migration utility in `lib/api/apis.dart` using Firestore `collectionGroup('messages')` query.
  * Downloads historical media from Firebase Storage, re-uploads to Cloudinary, and updates Firestore document references automatically.

### B. Modern Android & Gradle Build System
* **Gradle Wrapper**: `8.12.1` (`android/gradle/wrapper/gradle-wrapper.properties`)
* **Android Gradle Plugin (AGP)**: `8.9.1` (`android/settings.gradle`)
* **Kotlin**: `2.0.21` (`android/settings.gradle`)
* **Java Target**: Java 17 / JVM 17 (`android/app/build.gradle` and root `android/build.gradle`)
* **Declarative Gradle Migration**:
  * Migrated from old `apply from:` / `buildscript` plugin loading to the modern `plugins { ... }` block in `settings.gradle` as the single source of truth.
* **Compatibility Hooks in Root `build.gradle`**:
  * Auto-injects `namespace` derived from `AndroidManifest.xml` for legacy packages lacking explicit namespace declarations in AGP 8.x.
  * Forces `buildConfig = true` and `compileSdkVersion = 34` across all subproject plugins.
* **Performance & Memory Tuning**:
  * Increased Gradle JVM heap memory to `-Xmx4096M`.
  * Disabled legacy Jetifier (`android.enableJetifier=false` in `gradle.properties`) to prevent memory crashes on heavy Flutter engine JARs.

### C. Dependency Modernization
* **Package Updates**:
  * `firebase_core: ^3.10.1`, `firebase_auth: ^5.4.1`, `cloud_firestore: ^5.6.2`, `firebase_messaging: ^15.2.1`
  * `google_sign_in: ^6.2.2`, `cached_network_image: ^3.4.1`, `image_picker: ^1.1.2`, `http: ^1.3.0`
  * `emoji_picker_flutter: ^1.6.3`
* **Package Replacements**:
  * **Replaced `gallery_saver` with `gal: ^2.3.0`**: Replaced abandoned `gallery_saver` (which locked `http` to old 0.13.x versions) with the modern `gal` package.
  * **Removed `flutter_notification_channel`**: Removed obsolete package that relied on removed Flutter v1 embedding APIs (`PluginRegistry.Registrar`).

---

## 3. Configuration & Credentials Setup

Before running the application, ensure the following constants are configured in `lib/api/apis.dart`:

```dart
static const String cloudinaryCloudName = 'YOUR_CLOUD_NAME';
static const String cloudinaryUploadPreset = 'YOUR_UPLOAD_PRESET'; // Unsigned mode
static const String deleteProxyUrl = 'YOUR_CLOUDFLARE_WORKER_URL';
static const String deleteProxyAuthToken = 'YOUR_PROXY_AUTH_TOKEN';
```

### Firebase & Google Sign-In Setup
1. Generate the SHA-1 key for your machine/keystore:
   ```powershell
   .\android\gradlew -p android signingReport
   ```
2. Add the generated **SHA-1** fingerprint to **Firebase Console** -> **Project Settings** -> **Your Android App**.
3. Download the updated `google-services.json` and place it in `android/app/google-services.json`.

---

## 4. How to Build & Run

### Standard Development Run
```powershell
flutter clean
flutter pub get
flutter run
```

### Building Release APK
```powershell
flutter build apk --release --android-skip-build-dependency-validation
```
*Output Location*: `build/app/outputs/flutter-apk/app-release.apk`

---

## 5. Next Steps / Project Roadmap
1. Complete the in-app Cloudinary media migration using the UI dialog in `home_screen.dart`.
2. Connect new photo/media sends directly to Cloudinary.
3. Expand media capabilities (Video sharing, Audio/Voice messages, Document attachments).
4. Modern UI revamp (Gradients, glassmorphism, animated bubbles, dark theme).
