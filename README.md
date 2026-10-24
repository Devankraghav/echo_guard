# 🛡️ EchoGuard

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![TensorFlow Lite](https://img.shields.io/badge/TFLite-FF6F00?style=for-the-badge&logo=TensorFlow&logoColor=white)](https://www.tensorflow.org/lite)
[![SQLite](https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![Release Version](https://img.shields.io/github/v/release/Devankraghav/echo_guard?style=for-the-badge&color=brightgreen)](https://github.com/Devankraghav/echo_guard/releases/latest)

**An offline-first, privacy-focused personal safety application built with Flutter, TensorFlow Lite, and local storage.**

[📥 Download Latest APK](https://github.com/Devankraghav/echo_guard/releases/latest/download/app-release.apk) · [🐛 Report Bug](../../issues) · [✨ Request Feature](../../issues)

</div>

---

## 📖 About EchoGuard

**EchoGuard** is designed to provide reliable, real-time personal safety monitoring without relying on external cloud servers, constant internet connections, or third-party APIs. By leveraging on-device machine learning and local data storage, EchoGuard ensures that your audio feeds, emergency contacts, and safety logs remain strictly private and under your control.

---

## ✨ Key Features

* **🧠 100% Offline AI Threat Detection**: Utilizes embedded TensorFlow Lite (`YAMNet`) audio classification models directly on your device hardware to recognize emergency audio cues locally.
* **🔒 Privacy-First Architecture**: No cloud backend, no account sign-ups, and no telemetry. Your personal safety data stays on your phone.
* **💾 Local SQLite Database**: Securely manages your emergency trusted contacts, event history, and app configurations locally using lightweight SQLite storage.
* **⚡ Instant Emergency Alerts**: Rapidly triggers automated safety flows, alerting designated contacts when potential distress signals are detected.
* **🌙 Sleek Modern UI**: Clean, responsive dark-themed user interface optimized for quick accessibility during high-stress scenarios.

---

## 📱 How to Download & Install

You can install EchoGuard directly on your Android device without visiting the Google Play Store:

1. Visit the **[Releases Page](https://github.com/Devankraghav/echo_guard/releases/latest)**.
2. Under **Assets**, download the latest **`app-release.apk`** file[cite: 5].
3. Open the downloaded APK on your Android phone and follow the on-screen prompts to install (granting "Install from unknown sources" permission if requested).
4. Launch **EchoGuard**, configure your trusted contacts, and start monitoring!

---

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) (Cross-platform mobile development)
* **Language**: Dart
* **Machine Learning**: TensorFlow Lite (`tflite_flutter`) with `YAMNet` audio classification model & class labels
* **Local Database**: SQLite (`sqflite`) for offline storage
* **State Management & Services**: Custom services for background processing (`ml_audio_service.dart`, `alert_service.dart`, `database_helper.dart`)

---

## 📂 Project Structure

```text
echo_guard/
├── android/                 # Android native configuration and build files
├── assets/
│   ├── images/              # App icons, logos, and UI graphics
│   └── models/              # TFLite model (yamnet.tflite) & class labels
├── lib/
│   ├── services/            # Core logic (ML audio, local database, alerts)
│   └── main.dart            # Main application entry point and UI views
├── test/                    # Widget and unit tests
├── pubspec.yaml             # Project dependencies and asset declarations
└── README.md
