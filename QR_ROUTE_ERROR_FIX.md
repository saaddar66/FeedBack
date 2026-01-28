# URGENT FIX: QR Code Route Error

## Problem
- Error: `GOException: no routes for location:/public?`
- QR codes were hardcoded to `/survey` in two places

## What I Fixed

### 1. Updated Welcome Screen QR Code ✅
Changed from:
```dart
baseUrl = '.../#/survey';
```
To:
```dart
baseUrl = '.../#/public';
```

### 2. Updated Dashboard QR Code ✅
Already updated in previous step.

### 3. Added Route Registration ✅
Routes are properly registered in `main.dart`.

## CRITICAL: You MUST Stop and Restart the App

**Hot Reload (`r`) and Hot Restart (`R`) will NOT work for new routes!**

### Step-by-Step Fix:

1. **Stop the current app**:
   ```
   In the terminal running `flutter run`:
   Press Ctrl+C
   ```

2. **Restart the app**:
   ```bash
   flutter run
   ```

3. **Wait for app to fully start**
   - Don't press `r` or `R`
   - Let it complete the full build

4. **Test the route manually first**:
   - Navigate to the dashboard
   - Try to manually go to `/public` route
   - If this works, the QR code will work

## Why This Happens

GoRouter caches routes at startup. New routes require a **full app restart**, not just:
- ❌ Hot Reload (`r`)
- ❌ Hot Restart (`R`)
- ✅ Full Stop + Restart (Ctrl+C then `flutter run`)

## Verification Steps

After restarting:

1. **Check Welcome Screen**:
   - Go to `/` (welcome screen)
   - Look at QR code
   - Should show URL with `/public` at bottom

2. **Check Dashboard**:
   - Login and go to dashboard
   - Click "Show QR" button
   - Should show URL with `/public` at bottom

3. **Test Manual Navigation**:
   ```dart
   // Try this in your app:
   context.go('/public');
   ```
   - Should show landing page with two options
   - No error

4. **Test QR Code**:
   - Scan the QR code
   - Should land on public landing page
   - See "View Menu" and "Leave Feedback" options

## Expected Behavior

### QR Code URL Format:
```
http://localhost:port/#/public?uid=userId123
```

### Landing Page Shows:
```
┌─────────────────────────────┐
│        Welcome!             │
│                             │
│  🍽️  View Menu              │
│  Browse our delicious...    │
│                             │
│  💬  Leave Feedback         │
│  Share your experience...   │
└─────────────────────────────┘
```

## If Still Not Working

### Option 1: Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

### Option 2: Check for Typos
Verify in `route_paths.dart`:
```dart
static const String publicLanding = '/public';  // No spaces!
static const String publicMenu = '/public/menu';
```

### Option 3: Check Imports
Verify in `main.dart`:
```dart
import 'package:feedy/presentation/screens/public/public_landing_screen.dart';
import 'package:feedy/presentation/screens/public/public_menu_viewer_screen.dart';
```

### Option 4: Check Route Registration
Verify in `main.dart` routes list:
```dart
GoRoute(
  path: RoutePaths.publicLanding,  // '/public'
  builder: (context, state) => const PublicLandingScreen(),
),
```

## Debug Output

After restart, you should see in terminal:
```
✓ Built build\web\main.dart.js
Launching lib\main.dart on Chrome in debug mode...
```

No errors about routes.

## Summary

✅ Fixed: Welcome screen QR code now points to `/public`
✅ Fixed: Dashboard QR code now points to `/public`
✅ Fixed: Routes are properly registered
⚠️ **ACTION REQUIRED**: Stop app (Ctrl+C) and restart (`flutter run`)

The route error will disappear after a full restart!
