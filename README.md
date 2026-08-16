# 🚀 BackSpace — Real-Time Chat & Group Messaging App

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20FCM-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media%20CDN-3448C5?logo=cloudinary&logoColor=white)](https://cloudinary.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen)](#)
[![Version](https://img.shields.io/badge/Version-v2.0.0-blue)](#)

**BackSpace** is a full-featured, cross-platform real-time messaging application built with **Flutter**, **Firebase**, and **Cloudinary**. BackSpace features instant 1-on-1 messaging, robust group chats, 24-hour expiring status/stories, FCM v1 rich push notifications, WhatsApp-style message edit/delete rules, and automated serverless media lifecycle cleanup.

---

## ✨ Features

### 💬 1-on-1 Direct Messaging
- **Real-Time Sync**: Low-latency message delivery powered by Cloud Firestore streams.
- **Online & Last Active Status**: Live green indicator dots and dynamic "Online" / "Last seen" timestamps.
- **Unread Message Indicators**: Right-aligned blue unread dot indicators and bold message previews.
- **Mute & Block System**: Flexible notification muting (1 Hour, 1 Week, Always) and user blocking.

### 👥 Group Chat Architecture
- **Group Creation & Management**: Create groups with custom titles, descriptions, and avatars.
- **Consecutive Message Layout**: Smart WhatsApp-style message layout hiding duplicate avatars/names for consecutive messages from the same sender.
- **Role-Based Permissions**: Group Admin badges, member management, and Group Owner admin demotion ("Dismiss as Admin").
- **Group Notification Muting**: Mute notifications per group directly from context popovers or Group Info settings.

### 📸 24-Hour Status / Stories
- **Multimodal Status Creation**: Post text, image, or video status updates.
- **Real-Time View Tracking**: Live status view counts and viewers tray.
- **Auto-Expiration**: Statuses automatically expire after 24 hours.

### 🔔 FCM v1 Rich Push Notifications
- **High-Priority Delivery**: Instant background and killed-state push notifications via Firebase Cloud Messaging (FCM v1 API).
- **Rich Media & Avatars**: Displays sender profile images and photo/video badges inside native OS notifications.
- **Notification Deep-Linking**: Tapping a notification routes directly into the specific 1:1 or Group chat.

### ⏱️ WhatsApp-Style Message Rules
- **1-Hour Edit Window**: Text messages can be edited within 1 hour of sending time.
- **6-Hour Delete Window**: Messages can be deleted within 6 hours of sending time.

### ☁️ Cloudinary Storage & Serverless Cleanup
- **Auto-Format & Compression**: Instant image/video optimization using Cloudinary's dynamic CDN (`f_auto`, `q_auto`, responsive resizing).
- **Serverless Media Purge**: Firebase Cloud Functions listen to Firestore `onDelete` triggers to automatically delete associated image/video assets from Cloudinary when messages or stories expire or get deleted.

---

## 🛠️ Tech Stack

- **Frontend**: Flutter (Dart 3.x)
- **Backend & Database**: Cloud Firestore, Firebase Auth, Firebase Cloud Messaging (FCM v1)
- **Serverless Functions**: Firebase Cloud Functions (Node.js 20)
- **Media CDN & Optimization**: Cloudinary (Upload API + Node.js Admin SDK)
- **Local Caching**: `cached_network_image` with custom avatar cache manager

---

## 📁 Folder Structure

```
lib/
├── api/                   # Firestore, Auth, FCM, and Cloudinary API handlers
├── helper/                # Date utilities, Cache managers, Theme controllers, Dialogs
├── models/                # Data models (ChatUser, Message, GroupChat, Story)
├── screens/               # App screens (Home, Chat, Group, Story, Settings, Profile)
│   └── auth/              # Login and Splash screens
└── widgets/               # Reusable UI components (Context popovers, Cards, Tray)
functions/                 # Firebase Cloud Functions (Node.js 20 backend)
```

---

## 🚀 Setup & Installation Guide

Follow these steps to set up and run **BackSpace** on your local machine:

### 📋 Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.0.0`)
- [Node.js](https://nodejs.org/) (`>= 20.x`) & `npm`
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- An active [Firebase Project](https://console.firebase.google.com/)
- A free [Cloudinary Account](https://cloudinary.com/)

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/S-aurav/BackSpace.git
cd BackSpace
```

---

### Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

---

### Step 3: Firebase Configuration

1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication** (Google Sign-In and Email/Password).
3. Enable **Cloud Firestore** in production mode.
4. Enable **Firebase Cloud Messaging (FCM)**.
5. Register your Android app package (e.g., `com.example.backspace`) and download `google-services.json`. Place it inside:
   ```
   android/app/google-services.json
   ```
6. Run `flutterfire configure` or create `lib/firebase_options.dart` with your Firebase project credentials.

---

### Step 4: Configure Cloudinary Credentials

Open `lib/api/apis.dart` and fill in your Cloudinary Cloud Name and Unsigned Upload Preset:

```dart
// lib/api/apis.dart
static const String cloudinaryCloudName = 'YOUR_CLOUDINARY_CLOUD_NAME';
static const String cloudinaryUploadPreset = 'YOUR_CLOUDINARY_UPLOAD_PRESET';
```

---

### Step 5: Firebase Cloud Functions Setup (Serverless Media Cleanup & Notifications)

1. Navigate to the `functions` directory:
   ```bash
   cd functions
   npm install
   ```
2. Create a `.env` file inside the `functions/` directory:
   ```env
   CLOUDINARY_CLOUD_NAME=your_cloudinary_cloud_name
   CLOUDINARY_API_KEY=your_cloudinary_api_key
   CLOUDINARY_API_SECRET=your_cloudinary_api_secret
   ```
3. Deploy the Cloud Functions to your Firebase project:
   ```bash
   npx -y firebase-tools@latest deploy --only functions
   ```

---

<p center>Made with ❤️ using Flutter & Firebase</p>
