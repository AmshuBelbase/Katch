# Katch

Katch is an intelligent voice memory application built with Flutter. It allows users to capture, organize, and search their memories, thoughts, and tasks using voice input and natural language processing.

## Features
- **Voice Capture**: Quickly record your thoughts and memories using voice.
- **Memories & Organization**: View and manage your saved memories.
- **Smart Reminders**: Set context-aware reminders.
- **Search**: Easily find past memories.

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / Xcode for emulators and building

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/AmshuBelbase/Katch.git
   ```
2. Navigate to the project directory:
   ```bash
   cd voice_memory_app
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. **Firebase Configuration**:
   - Create a Firebase project.
   - Download the `google-services.json` for Android and place it in `android/app/`.
   - Download the `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`.
   - Ensure you run `flutterfire configure` to generate `lib/firebase_options.dart`.

5. Run the app:
   ```bash
   flutter run
   ```
