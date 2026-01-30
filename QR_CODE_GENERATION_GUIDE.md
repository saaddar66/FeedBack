# QR Code Generation - Complete Flow

## 📍 Two Locations Where QR Codes Are Created

### 1️⃣ Dashboard Screen (Admin)
**File**: `lib/presentation/screens/admin/dashboard_screen.dart`
**Lines**: 726-815

### 2️⃣ Welcome Screen (Public)
**File**: `lib/presentation/screens/welcome_screen.dart`
**Lines**: 62-87, 148-153

---

## 🔄 QR Code Generation Flow

### Dashboard Screen Flow

```
User clicks "Show QR" button in bottom nav
         ↓
_showQrCodeDialog(context) called (line 727)
         ↓
┌─────────────────────────────────────────┐
│ Step 1: Determine Base URL             │
│                                         │
│ if (kIsWeb) {                          │
│   // Running on web                    │
│   uri = Uri.base                       │
│   baseUrl = 'http://localhost:port/#/public' │
│ } else {                               │
│   // Running on mobile/desktop         │
│   baseUrl = 'https://feedy-cebf6.web.app/#/public' │
│ }                                      │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Step 2: Get User Information           │
│                                         │
│ authProvider = context.read<AuthProvider>() │
│ user = authProvider.user               │
│ ownerId = user?.id                     │
│ businessName = user?.businessName      │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Step 3: Build Final URL                │
│                                         │
│ if (ownerId != null && ownerId.isNotEmpty) { │
│   qrData = '$baseUrl?uid=$ownerId'    │
│   // Example: http://localhost:8080/#/public?uid=abc123 │
│ } else {                               │
│   qrData = baseUrl                     │
│   // Example: http://localhost:8080/#/public │
│ }                                      │
└─────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────┐
│ Step 4: Display QR Code Dialog         │
│                                         │
│ showDialog(                            │
│   QrImageView(                         │
│     data: qrData,  ← THE QR CODE URL  │
│     size: responsive size,             │
│   )                                    │
│ )                                      │
└─────────────────────────────────────────┘
```

---

## 📝 Code Breakdown

### Dashboard QR Code (Lines 726-746)

```dart
void _showQrCodeDialog(BuildContext context) {
  // STEP 1: Build base URL
  String baseUrl;
  if (kIsWeb) {
    // Web: Use current browser URL
    final uri = Uri.base;
    baseUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/#/public';
    // Example: http://localhost:8080/#/public
  } else {
    // Mobile/Desktop: Use production URL
    baseUrl = 'https://feedy-cebf6.web.app/#/public';
  }

  // STEP 2: Get logged-in user info
  final authProvider = context.read<AuthProvider>();
  final user = authProvider.user;
  final ownerId = user?.id;              // e.g., "abc123"
  final businessName = user?.businessName; // e.g., "Joe's Pizza"

  // STEP 3: Add ownerId as query parameter
  final qrData = (ownerId != null && ownerId.isNotEmpty) 
      ? '$baseUrl?uid=$ownerId'  // http://localhost:8080/#/public?uid=abc123
      : baseUrl;                  // http://localhost:8080/#/public

  // STEP 4: Display in dialog
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: Column(
        children: [
          Text('Scan to Give Feedback'),
          QrImageView(
            data: qrData,  // ← This is what gets encoded in QR
            version: QrVersions.auto,
            size: qrSize,
            backgroundColor: Colors.white,
          ),
          // Debug: Show the URL
          SelectableText(qrData), // Shows the actual URL
        ],
      ),
    ),
  );
}
```

---

## 🌐 URL Examples

### Development (Web)
```
Running on: http://localhost:8080

QR Code URL:
http://localhost:8080/#/public?uid=user123

Breakdown:
├─ http://localhost:8080  ← Current browser URL
├─ /#/public              ← Flutter route
└─ ?uid=user123           ← Query parameter (owner ID)
```

### Production (Web)
```
Deployed to: https://feedy-cebf6.web.app

QR Code URL:
https://feedy-cebf6.web.app/#/public?uid=user123

Breakdown:
├─ https://feedy-cebf6.web.app  ← Firebase hosting URL
├─ /#/public                     ← Flutter route
└─ ?uid=user123                  ← Query parameter (owner ID)
```

### Mobile/Desktop
```
QR Code URL:
https://feedy-cebf6.web.app/#/public?uid=user123

Note: Mobile apps generate QR codes that point to the web app
```

---

## 🎯 How Query Parameters Work

### URL Structure
```
https://example.com/#/public?uid=abc123&name=test
                    │       │          │
                    │       │          └─ Additional params
                    │       └─ First query param
                    └─ Route path
```

### In Flutter (GoRouter)
```dart
// Route definition (main.dart)
GoRoute(
  path: '/public',  // ← Matches ONLY the path part
  builder: (context, state) {
    // Access query parameters inside builder
    final uid = state.uri.queryParameters['uid'];  // "abc123"
    final name = state.uri.queryParameters['name']; // "test"
    
    return PublicLandingScreen();
  },
),
```

### In Screen (public_landing_screen.dart)
```dart
@override
Widget build(BuildContext context) {
  // Get query parameters
  final state = GoRouterState.of(context);
  final ownerId = state.uri.queryParameters['uid'];
  
  // Use ownerId to filter data
  print('Owner ID: $ownerId'); // "abc123"
  
  // Pass to next screen
  onTap: () {
    context.go('/public/menu?uid=$ownerId');
  }
}
```

---

## 🔍 Debug: See What's in the QR Code

### In Dashboard Dialog
Look at the bottom of the QR dialog - there's a gray box showing the exact URL:

```
┌─────────────────────────────────────┐
│   Scan to Give Feedback             │
│                                     │
│   [QR CODE IMAGE]                   │
│                                     │
│   Linked to: Joe's Pizza            │
│   ┌───────────────────────────────┐ │
│   │ http://localhost:8080/#/      │ │ ← THIS SHOWS THE URL
│   │ public?uid=abc123             │ │
│   └───────────────────────────────┘ │
│                                     │
│   [Close]                           │
└─────────────────────────────────────┘
```

---

## 📱 What Happens When QR Code is Scanned

```
1. User scans QR code
   ↓
2. Phone reads URL: http://localhost:8080/#/public?uid=abc123
   ↓
3. Phone opens browser with that URL
   ↓
4. Flutter app loads
   ↓
5. GoRouter sees path: /public
   ↓
6. GoRouter matches route and calls PublicLandingScreen()
   ↓
7. PublicLandingScreen reads uid from query params
   ↓
8. Screen shows two options:
   - View Menu (passes uid to /public/menu?uid=abc123)
   - Leave Feedback (passes uid to /survey?uid=abc123)
```

---

## 🛠️ Key Variables

### In Dashboard QR Generation

| Variable | Type | Example | Purpose |
|----------|------|---------|---------|
| `kIsWeb` | bool | `true` | Checks if running on web |
| `Uri.base` | Uri | `http://localhost:8080/` | Current browser URL |
| `baseUrl` | String | `http://localhost:8080/#/public` | Base route URL |
| `ownerId` | String? | `"abc123"` | Current user's ID |
| `businessName` | String? | `"Joe's Pizza"` | Business name |
| `qrData` | String | `http://localhost:8080/#/public?uid=abc123` | Final QR URL |
| `qrSize` | double | `250.0` | QR code size in pixels |

---

## ✅ Current Status

Both QR code locations now correctly generate:

```
http://localhost:8080/#/public?uid=abc123
                       ^^^^^^^ ← Points to public landing page
                               ^^^^^^^^^ ← Includes user ID
```

**Before (OLD):**
```
http://localhost:8080/#/survey?uid=abc123
                       ^^^^^^^ ← Went directly to survey
```

**After (NEW):**
```
http://localhost:8080/#/public?uid=abc123
                       ^^^^^^^ ← Goes to landing page with choices
```

---

## 🎨 Visual Flow

```
┌──────────────────────────────────────────────────────────┐
│                    QR CODE GENERATION                    │
└──────────────────────────────────────────────────────────┘
                           ↓
        ┌──────────────────┴──────────────────┐
        ↓                                     ↓
┌───────────────────┐              ┌──────────────────┐
│  Dashboard QR     │              │  Welcome QR      │
│  (Admin logged in)│              │  (Public view)   │
└───────────────────┘              └──────────────────┘
        ↓                                     ↓
┌───────────────────┐              ┌──────────────────┐
│ Get user.id       │              │ Get last active  │
│ from AuthProvider │              │ user from prefs  │
└───────────────────┘              └──────────────────┘
        ↓                                     ↓
        └──────────────────┬──────────────────┘
                           ↓
              ┌────────────────────────┐
              │ Build URL:             │
              │ baseUrl + ?uid=ownerId │
              └────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │ QrImageView(           │
              │   data: qrData         │
              │ )                      │
              └────────────────────────┘
                           ↓
              ┌────────────────────────┐
              │ Display QR Code        │
              │ Show URL for debug     │
              └────────────────────────┘
```

---

## 🔧 Troubleshooting

### Problem: QR shows old URL (/#/survey)
**Solution**: App needs full restart (Ctrl+C, then `flutter run`)

### Problem: QR has no uid parameter
**Solution**: User not logged in or no user data available

### Problem: QR code doesn't scan
**Solution**: Check QR code size, ensure good contrast

### Problem: Route error after scan
**Solution**: App not restarted with new routes

---

## 📚 Summary

**QR Code URL Format:**
```
[protocol]://[host]:[port]/#/[route]?[query-params]
```

**Example:**
```
http://localhost:8080/#/public?uid=abc123
│      │          │    │       │
│      │          │    │       └─ Query params (user ID)
│      │          │    └─ Route path
│      │          └─ Port
│      └─ Host
└─ Protocol
```

**The QR code encodes the full URL, which when scanned, opens the browser and navigates to the public landing page with the user's ID as a query parameter.**
