# Welcome to Katch

## What is Katch?
Katch is your ultimate personal assistant and "second brain" that fits right in your pocket. Designed for people on the move, it allows you to capture fleeting thoughts, track your expenses, and set reminders instantly using just your voice. 

Instead of fumbling through complex menus, typing out long notes, or using three different apps for your calendar, finances, and to-do lists, you simply speak naturally. Katch listens, understands what you need, and organizes your life for you AUTOMATICALLY !!

## Magic Features
- **Unmatched Ease of Use:** Forget complex menus or endless typing. Just tap the microphone and speak your mind—or type if you prefer. Katch's AI instantly parses your input, understands the context, and automatically organizes everything into tasks, budgets, and memories without any manual data entry.
- **Ask Your Memory Vault:** Never forget a detail again. You can chat with your memories like you would a real person. Ask, *"What book did John recommend to me last month?"* and Katch will instantly find the answer from your past notes.
- **Advanced Smart Reminders:** 
  - Say, *"Remind me to call the dentist tomorrow at 3 PM"* and it auto-schedules. 
  - Need repetition? Tell it to *"remind me to take pills every day at 8 AM"* and it sets a **recurring reminder**.
  - **Offline Alarms:** Katch uses native device alarms. Even if you are entirely offline, on an airplane, or the app is closed, your phone will ring to remind you.
- **Stay on Track:** Beyond offline alarms, Katch proactively taps you on the shoulder with online push notifications and a helpful email digest so nothing slips through the cracks.
- **Comprehensive Finance Tracking:**
  - **Personal Budgeting:** Say, *"I spent Rs 45 on groceries."* Katch extracts the expense, maps it to a customizable category (like 'Groceries'), and updates your dynamic Pie/Bar charts and net balance KPIs.
  - **Splitwise Integration:** Going out with friends? Say, *"Split a 200 Rs taxi with Sarah & John."* Katch detects the split, automatically calculates who owes whom, and perfectly tracks your debts & credits in a dedicated Split section.
- **Bank-Level Security:** Secure your data with robust Google OAuth or standard email OTP. Only you can access your personal vault, backed by Row-Level Security in the cloud.

## Who is this App For?
- **Busy Professionals & Creatives:** Perfect for when you get your best ideas while driving, walking the dog, or simply away from a keyboard.
- **Freelancers & Roommates:** Effortlessly track daily expenses, manage receipts, or split bills on the fly without navigating clunky accounting apps.
- **Productivity Enthusiasts:** Anyone looking for a frictionless personal assistant that actually remembers everything you tell it—and proactively reminds you when it matters most.

## How to Get the APP?
1. **Install App:** Download and Install from [link](https://github.com/AmshuBelbase/Katch/releases/latest) by clicking katch-v(latest_version).apk under Assets.
2. **Sign Up:** Create a free account securely using your email or Google account.
3. **Speak Your Mind:** Tap the microphone on the home screen and talk naturally. Try saying: *"I need to renew my passport before next Friday"* or *"Paid 12 rupees for a tea"*.
4. **Let the App Work:** Sit back and relax. Katch will instantly organize your note, extract the "Renew Passport" task, and quietly schedule your reminder.
5. **Chat & Search:** Need to find an old thought? Go to the Chat tab and just ask for it.
6. **Get Reminded:** When a deadline approaches, your phone will buzz to remind you. It’s that easy!


# Are you a developer like me?

Katch is an intelligent voice memory application built with Flutter. It allows users to capture, organize, and search their memories, thoughts, and tasks using voice input and natural language processing.

## Features (Brief)
- **Unmatched Ease of Use**: No more fumbling through complex menus or disjointed apps. Simply tap the microphone to record your voice or type text. Katch's AI automatically parses, categorizes, and organizes everything for you without any manual data entry.
- **Advanced Smart Reminders**: 
  - **Auto-Scheduling**: Say a deadline, and it automatically schedules itself.
  - **Recurring Reminders**: Fully supports recurring tasks (e.g., "Remind me to take my pills every day at 8 AM").
  - **Offline Alarms**: Uses the native `alarm` package to ensure your phone physically rings at the exact due time, even if you are entirely offline or the app is closed.
  - **Multi-channel Notifications**: Proactively notifies you via push notifications and daily email digests.
- **Comprehensive Finance Tracking**: 
  - **Personal Budgeting**: Autonomously extracts personal expenses and incomes. Automatically maps them to custom expense categories (e.g., Groceries, Subscriptions) and visualizes them using dynamic Pie/Bar charts with net balance KPIs.
  - **Splitwise Integration**: Automatically detects when you split bills (e.g., "I split a Rs200 taxi with Sarah & John"). It calculates and tracks exactly who owes whom, keeping your social finances perfectly balanced.
- **Search & AI Chat**: Easily find past memories and chat with your vault using vector-powered semantic search. Ask questions like "What books did John recommend?" and get instant answers.
- **Secure Authentication**: Keep your data safe with robust Google OAuth and custom OTP login flows backed by cloud Row-Level Security.

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
