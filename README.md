# College Attendance Client

A lightweight Flutter mobile app that lets students view their attendance data from the UKTech university portal. The app handles login via an embedded webview, fetches attendance tables, parses HTML, stores data locally with SQLite, and presents a clean dark‑mode UI with both list and table views.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Flutter](https://img.shields.io/badge/flutter-3.24%2B-green)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-grey)
![License](https://img.shields.io/badge/license-MIT-yellow)

## Features

- **Web‑login flow** – Securely logs in to the university portal using `flutter_inappwebview` and captures the session cookie.
- **HTML parsing** – Extracts attendance tables from the portal’s HTML using the `html` package.
- **Local persistence** – Stores the latest attendance data in an SQLite database (`sqflite`) for offline access.
- **SharedPreferences UI state** – Remembers the user’s selected session, semester, month, year and list‑/table‑view mode across app launches.
- **Dark theme** – Uses `ThemeData.dark()` with custom accent colours that change based on overall attendance percentage.
- **Responsive UI** – Shows a circular progress indicator for overall attendance, expandable cards for each subject, or a compact data table.
- **Pull‑to‑refresh** – Swipe down to re‑sync attendance data at any time.
- **Session management** – Helper to clear stored cookies and force a fresh login.

## Installation

### Prerequisites

- Flutter SDK ≥ 3.24 (stable) – see https://flutter.dev/docs/get-started/install
- Android Studio / Xcode (for device emulators)
- A device or emulator with internet access to the UKTech portal

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/College-Attendance-Client.git
cd College-Attendance-Client

# Get Flutter dependencies
flutter pub get

# Run the app on Android
flutter run -d android

# Or run on iOS
flutter run -d ios
```

## Quick Start

1. **Launch the app** – The first screen is a login webview (`https://online.uktech.ac.in/ums/Student/Account/Login`).
2. **Enter your university credentials** – After a successful login the app captures the `session_cookie` and stores it securely with `flutter_secure_storage`.
3. **View attendance** – The dashboard shows your name, overall attendance gauge, and a list of subjects.
4. **Filter** – Use the pill‑styled dropdowns to change **Session**, **Semester**, **Month**, and **Year**. Selecting “Full Semester” aggregates attendance over all months.
5. **Toggle view** – Press the grid/table icon in the header to switch between card view and a compact table view. The choice is saved for the next launch.
6. **Pull‑to‑refresh** – Swipe down on the list to re‑sync data.

## Usage Details

| Component | Description |
|-----------|-------------|
| `AuthInterceptorService` (`lib/data/services/auth_interceptor.dart`) | Handles login cookie extraction and provides authenticated HTTP headers. |
| `HtmlParserService` (`lib/data/services/html_parser_service.dart`) | Extracts hidden form parameters and parses the attendance table into `AttendanceModel` objects. |
| `DatabaseHelper` (`lib/data/local/database_helper.dart`) | SQLite helper that creates the `attendance` table and offers `saveAttendance` / `getCached`. |
| `DashboardScreen` (`lib/data/screens/dashboard_screen.dart`) | Main UI – loads cached data, syncs with the server, persists UI preferences, and builds the list/table view. |
| `SubjectCard` (`lib/data/widgets/subject_card.dart`) | Reusable card widget that displays a subject’s percentage, attended/held numbers, and a circular progress indicator. |
| `SharedPreferences` (`package:shared_preferences`) | Persists user‑selected filters and view mode across app restarts. |
| `flutter_secure_storage` | Stores the session cookie and the user’s name securely on the device. |

### Persistence Flow

1. On start, `_loadPreferences()` reads the saved keys (`selectedSession`, `selectedSemester`, `selectedMonth`, `selectedYear`, `isTableView`).
2. When a dropdown changes, the `onChanged` handler saves the new value via `_savePreferences()` and triggers a sync.
3. The view‑toggle button also saves the updated `isTableView` flag.

### Session Clear

A helper method `_clearSession()` deletes the stored cookie and student name, then shows a Snackbar prompting the user to log in again. Hook this up to a settings or logout button if desired.

## Architecture

```
college_attendance_client/
├─ lib/
│  ├─ data/
│  │  ├─ models/
│  │  │   └─ attendance_model.dart          # Data model
│  │  ├─ local/
│  │  │   └─ database_helper.dart           # SQLite helper
│  │  ├─ services/
│  │  │   ├─ auth_interceptor.dart           # Cookie handling
│  │  │   └─ html_parser_service.dart       # HTML → model parser
│  │  ├─ widgets/
│  │  │   └─ subject_card.dart               # Reusable UI card
│  │  └─ screens/
│  │      └─ dashboard_screen.dart           # Main screen + UI state
│  └─ main.dart                              # App entry point
├─ android/                                   # Android project files
├─ ios/                                       # iOS project files
├─ pubspec.yaml                               # Dependencies (flutter, http, sqflite, etc.)
└─ README.md                                  # This documentation
```

## Testing

The project currently has no unit tests. Suggested test coverage:

- **AuthInterceptorService** – mock `CookieManager` and verify cookie extraction.
- **HtmlParserService** – feed sample HTML snippets and assert correct `AttendanceModel` list.
- **DatabaseHelper** – in‑memory SQLite tests for `saveAttendance` / `getCached`.
- **DashboardScreen** – widget tests for dropdown persistence and view‑toggle behaviour.

Add tests under `test/` and run with:

```bash
flutter test
```

## Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Make your changes, add tests, and ensure `flutter test` passes.
4. Submit a Pull Request with a clear description of the change.

Please follow the existing code style (run `dart format`, use descriptive variable names, and keep UI logic in the screen widgets).

## License

MIT License – see the [LICENSE](LICENSE) file.

---

**College Attendance Client** – Quickly see your university attendance on any Android or iOS device. 🎓✨
