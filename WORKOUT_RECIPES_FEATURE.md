# Exercise & Recipe Tutorials Feature

## Overview
Added a new **"Workout"** section to the OvaCare navigation bar where users can discover personalized exercise and food recipe tutorials based on their health data.

## What's New

### Navigation Bar Update
- **New Tab**: "Workout" button (green icon) added to the bottom navigation bar
- **Location**: Between "Learn" and "Forum" tabs
- **Icon**: Fitness center icon with green color theme

### Features

#### Exercise Tutorials Section
- **4 Sample Workouts**:
  1. Low-Impact Cardio Workout (20 mins, Beginner)
  2. Yoga for PCOS (30 mins, Beginner)
  3. Strength Training Basics (25 mins, Intermediate)
  4. HIIT Workout for Weight Loss (20 mins, Advanced)

- **Difficulty Filter**: Filter workouts by difficulty level (All, Beginner, Intermediate, Advanced)
- **Details Include**:
  - Duration and difficulty level
  - Step-by-step instructions
  - Health benefits for PCOS management
  - Video tutorial links (ready for integration)

#### Recipe Tutorials Section
- **4 Sample Recipes**:
  1. Quinoa Buddha Bowl (15 min prep, Easy)
  2. Grilled Chicken with Sweet Potato (10 min prep, Easy)
  3. Green Smoothie Bowl (5 min prep, Easy)
  4. Baked Salmon with Vegetables (10 min prep, Intermediate)

- **Recipe Details Include**:
  - Prep and cook times
  - Servings information
  - Detailed ingredient lists
  - Step-by-step cooking instructions
  - Health benefits specific to PCOS management
  - Cooking tutorial links (ready for integration)

### UI/UX Highlights
- **Beautiful Card Design**: Each workout/recipe displayed in an elegant card with color-coded icons
- **Modal Bottom Sheet**: Tap any card to view full details in a draggable sheet
- **Tab Navigation**: Switch between Exercises and Recipes tabs
- **Responsive Design**: Works smoothly on different screen sizes
- **Health-Focused**: All recommendations tailored for PCOS management

### Data Personalization
The screen shows:
- "Based on your health data and preferences" message
- Ready to integrate with user's menstrual cycle, weight, and symptom data
- Can be enhanced to show recommendations based on user's specific health profile

### Video Integration Ready
- Each workout and recipe has a `videoUrl` field
- Ready to integrate with YouTube, Vimeo, or custom video streaming
- Watch button opens tutorials (currently shows placeholder snackbar)

## Technical Implementation
- **Widget Type**: StatefulWidget with TabController
- **Tab Support**: 2-tab interface (Exercises + Recipes)
- **State Management**: Uses existing AuthProvider and HealthDataProvider
- **Responsive Layout**: Horizontal scrolling navigation, vertical scrolling content

## Files Modified
- `ovacare/lib/main.dart`: Added ExerciseRecipeTutorialsScreen class and updated DashboardScreen

## How to Enhance Further

### 1. Connect to User Data
```dart
// Filter recommendations based on user health metrics
final userAge = auth.userAge;
final userBMI = (auth.userWeight / (auth.userHeight * auth.userHeight));
```

### 2. Add Video Streaming
Replace the placeholder with actual video player integration:
```dart
// Open YouTube or custom video player
await launchUrl(Uri.parse(exercise['videoUrl']));
```

### 3. Add User Progress Tracking
- Track completed workouts
- Save favorite recipes
- Log workout completion with calendar view

### 4. Integrate with Backend
- Fetch dynamic content from Kaggle or custom API
- Store user preferences and completed workouts
- Get AI-powered recommendations

## Next Steps
- Integrate with actual video streaming service
- Connect to Kaggle datasets for expanded exercise/recipe library
- Add workout calendar and progress tracking
- Implement favorite/bookmark functionality
- Add nutritional information calculations for recipes
