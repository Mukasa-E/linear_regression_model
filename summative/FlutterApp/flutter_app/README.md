# Salary Predictor — Flutter App

Flutter frontend for the Nairobi Tech Hiring Tool.  
Connects to the FastAPI salary prediction endpoint and displays results in USD and KES.

---

## Setup & Run

```bash
# 1. Go into the FlutterApp folder
cd summative/FlutterApp

# 2. Get dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run

# 4. Build APK for Android
flutter build apk --release
```

---

## API Configuration

The API URL is set in `lib/main.dart`:

```dart
static const String _apiBase = 'https://salary-prediction-api-lbh8.onrender.com';
```

Change this to your Render URL if your service name is different.

---

## App Features

- 4 input fields matching the model's exact features
- Dropdown selectors for Gender, Education Level, Job Title
- Numeric field with range validation (0–50 years) for Experience
- Real-time form validation before sending to API
- Animated result card showing predicted salary in USD + KES (annual & monthly)
- Clear error display for API errors or out-of-range values
- Loading indicator while API call is in progress

---

## Folder Structure

```
FlutterApp/
├── lib/
│   └── main.dart                 ← Full app (single file)
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml  ← Internet permission
├── pubspec.yaml                 ← Dependencies
└── README.md
```