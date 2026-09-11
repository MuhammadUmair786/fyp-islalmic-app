# 🕌 Digital Islamic Hub

A comprehensive, professional, and feature-rich Islamic application built with Flutter. Digital Islamic Hub serves as a central platform for Muslims to enhance their faith, knowledge, and daily religious practices through modern technology.

---

## 🌟 Key Features

### 📖 Al-Quran Al-Kareem
*   **Full Quran Access**: Read the Holy Quran with high-quality Arabic text and translations (English/Urdu).
*   **Audio Recitations**: Stream audio from world-renowned Qaris (Abdul Basit, Mishary Alafasy, Abdurrahman Sudais).
*   **Resume Reading**: Automatically remembers your last read position (Surah & Ayah) for a seamless experience.
*   **Favorites & Bookmarks**: Save your most-loved Surahs and individual Ayahs for quick access.
*   **Professional Sharing**: Share beautiful Ayah cards directly to social media (icons are automatically excluded for a clean look).

### 📚 Authentic Hadith Library
*   **Major Collections**: Includes Sahih Bukhari, Sahih Muslim, Sunan Abu Dawud, and Jami at-Tirmidhi.
*   **Topic-wise Browsing**: Navigate through categorized chapters for easy learning.
*   **Progress Tracking**: "Resume Hadith" feature to pick up right where you left off.

### 🤖 Islamic AI Scholar (Mufti AI)
*   **AI-Powered Guidance**: An intelligent chatbot configured as an Islamic Scholar to answer complex queries based on Quran and authentic Hadith.
*   **Chat History**: Persistent chat sessions stored in Firestore, allowing users to revisit past discussions.
*   **Verified Scholars**: Option to escalate AI answers to verified human scholars for authenticated fatwas.

### 🕋 Prayer & Daily Utilities
*   **Smart Prayer Times**: Location-based timings with instant loading via advanced caching.
*   **Interactive Qaza Tracker**: Automated reminders at the end of each prayer time with "Yes/No" buttons to log missed prayers instantly.
*   **Masjid Auto-Silent**: Geofence-based technology that automatically puts your phone on 'Do Not Disturb' (DND) when you enter a mosque.
*   **Qibla Compass**: Highly accurate, sensor-based compass with haptic feedback to find Makkah's direction.
*   **Automatic Safar Dua**: Speed-based smart notifications that remind you to recite the travel prayer when your vehicle exceeds 20 km/h.
*   **Daily Sunnah & Deeds**: Gamified task list to track daily good deeds with streak monitoring and point systems.

### ✨ Personalization & UI
*   **Modern Design**: Premium dark-mode default UI with a focus on readability and responsiveness.
*   **Multi-Language Support**: Seamlessly switch between English and Urdu.
*   **Mood-Based Ayah**: Get Quranic recommendations based on how you are feeling (Happy, Sad, Anxious, etc.).

---

## 🛠️ Technology Stack

*   **Frontend**: Flutter (Dart)
*   **Backend/Database**: 
    *   Firebase (Authentication, Firestore for History & Settings)
    *   SQLite (Offline storage for Quran and Hadith databases)
*   **Cloud Storage**: Cloudinary (for high-speed profile image hosting)
*   **State Management**: ValueNotifier & Provider patterns
*   **Services**: 
    *   `adhan` for accurate prayer calculations
    *   `geolocator` & `google_maps_flutter` for location-based features
    *   `flutter_local_notifications` for scheduled Azan and reminders
    *   `sensors_plus` for magnetometer-based Qibla detection

---

## 🚀 Setup & Installation

### Prerequisites
*   Flutter SDK (Latest Stable)
*   Android Studio / VS Code
*   A Firebase Project (Google Services JSON/Plist configured)

### Steps
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/your-repo/digital_islamic_hub.git
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run Clean & Build**:
    ```bash
    flutter clean
    flutter run
    ```

---

## 📂 Project Structure

*   `lib/core/`: Database helpers and low-level logic.
*   `lib/models/`: Data models for Surah, Ayah, Hadith, and User data.
*   `lib/screens/`: UI implementation for all features.
*   `lib/services/`: External integrations (Notifications, DND, Bookmarks, Prayer calculations).
*   `lib/theme/`: Global styling and theme configurations.

---

## 🛡️ Permissions Required
*   **Location**: For Prayer Times, Qibla, and Masjid Silent features.
*   **Notifications**: For Azan alerts and Qaza reminders.
*   **DND Access**: Required for the Auto-Silent feature to function.
*   **Camera/Storage**: For updating profile pictures.

---

Developed with ❤️ for the Muslim Ummah.  
**Digital Islamic Hub** — *Your Gateway to Faith & Knowledge.*
