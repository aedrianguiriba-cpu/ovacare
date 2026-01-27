# OvaCare - PCOS Health Companion App

A comprehensive Flutter application for managing PCOS (Polycystic Ovary Syndrome) health. This is a **hard-coded demo version** with all features implemented without a database backend.

## Features

### 🏥 Health Tracking
- **Menstrual Cycle Tracker**: Log and monitor menstrual cycles
- **Symptom Tracker**: Track mood, cramps, acne, bloating, and other symptoms
- **Hydration Tracker**: Monitor daily water intake with goals
- **Medication Tracker**: Keep track of medication adherence
- **Weight/BMI Tracker**: Log weight entries over time

### ⚠️ Risk Assessment
- AI-powered PCOS risk calculation
- Risk level indicators (Low, Moderate, High)
- Visual progress indicators
- Factor analysis (Irregular cycles, Weight status, Symptoms)

### 📚 Education
- Comprehensive PCOS educational library
- Articles on diet, exercise, mental health, and disease understanding
- Expert authored content

### 💪 Lifestyle & Wellness
- Mood-based recommendations
- Diet suggestions
- Exercise recommendations
- Stress management tips

### 👥 Community Forum
- General discussion threads
- Symptom support group
- Medication discussion
- Diet & exercise tips sharing
- Real-time forum interaction (simulated)

### 👨‍⚕️ Doctor Directory
- Searchable directory of PCOS specialists
- Doctor ratings and reviews
- Contact information
- Clinic details

### 📊 Data Reporting
- Health summary reports
- Menstrual cycle analysis
- Hydration tracking reports
- Weight tracking trends
- Medication adherence reports
- Export to PDF functionality

### 🔐 User Authentication
- Simple login/registration
- User profile management
- Admin dashboard access

### ⚙️ Admin Dashboard
- User management
- Content moderation
- Analytics
- **Claude Haiku 4.5 Integration** (Feature flagged and enabled)

## Project Structure

```
ovacare/
├── lib/
│   ├── main.dart                 # App entry point, providers, and main screens
│   └── additional_screens.dart   # Community, Doctor Directory, Reporting screens
├── test/
│   └── widget_test.dart          # Basic test suite
├── pubspec.yaml                  # Dependencies and project config
└── README.md                      # This file
```

## Getting Started

### Prerequisites
- Flutter SDK 3.1.0 or higher
- Dart 3.1.0 or higher

### Installation

1. **Clone the repository**
   ```bash
   cd d:\Documents\web\ovacare\ovacare
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Dependencies

- **provider**: ^6.0.0 - State management

## Data (Hard-Coded)

All data is hard-coded in the providers:
- **AuthProvider**: User authentication and profile data
- **HealthDataProvider**: All health tracking data including:
  - Menstrual cycles
  - Symptoms
  - Hydration entries
  - Medications
  - Weight entries
  - Risk assessment data

### Sample User Credentials
- **Name**: Any name you enter
- **Email**: Any email format
- **Admin**: Check the "Login as Admin" checkbox to access admin features

## Screens

1. **Login Screen** - Initial authentication
2. **Dashboard Overview** - Welcome and quick stats
3. **Health Tracking** - Tab-based interface for all health metrics
4. **Risk Assessment** - PCOS risk level and contributing factors
5. **Education** - Curated PCOS learning materials
6. **Lifestyle & Wellness** - Personalized recommendations
7. **Community Forum** - Discussion categories and posts
8. **Doctor Directory** - Search and view healthcare providers
9. **Data Reporting** - Generate health summary reports
10. **Admin Dashboard** - Admin-only features and Claude Haiku 4.5 integration

## Key Features

### Hard-Coded Data
- No backend database
- All data stored in memory
- Resets on app restart
- Perfect for demos and prototyping

### State Management
- Provider for reactive state updates
- MultiProvider setup for scalability
- ChangeNotifier for simple state management

### User Interface
- Material Design 3
- Pink color scheme (PCOS-themed)
- Responsive layouts
- Card-based UI components

### Admin Features
- Accessible with admin login flag
- Claude Haiku 4.5 integration (enabled)
- System settings and analytics

## Testing

Run the test suite:
```bash
flutter test
```

## Future Enhancements

To extend this app:
1. **Add Database**: Integrate Firebase/Firestore for persistent storage
2. **Real AI Integration**: Connect Claude Haiku 4.5 API for personalized insights
3. **Notifications**: Add push notifications for medication reminders
4. **Social Features**: Enable real community forum functionality
5. **Data Export**: Implement actual PDF export
6. **Charts & Graphs**: Add visualization libraries (fl_chart, charts)
7. **Multi-language**: Implement localization

## Technical Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **UI Framework**: Material Design 3
- **Testing**: Flutter Test

## Contributing

This is a demo application built for PCOS health management education and prototyping.

## License

This project is for educational purposes.

## Contact & Support

For questions about PCOS or health-related concerns, please consult with healthcare professionals.

---

**Note**: This is a hard-coded demo version. All health information should be verified by qualified healthcare professionals. OvaCare is not a substitute for professional medical advice.
