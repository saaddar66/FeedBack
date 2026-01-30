# Firebase Realtime Database to Cloud Firestore Migration Guide

## ✅ Completed Steps

### 1. Created Firestore Implementation
- **File**: `lib/data/database/firestore_database_impl.dart`
- Fully implements `BaseDatabase` interface using Cloud Firestore
- No more type casting issues on web
- Better query performance and scalability

### 2. Updated Main.dart
- **File**: `lib/main.dart`
- Changed from `FirebaseDatabaseImpl()` to `FirestoreDatabaseImpl()`
- Import updated to use Firestore implementation

### 3. Updated MenuProvider
- **File**: `lib/presentation/providers/menu_provider.dart`
- Converted all CRUD operations to Firestore
- Uses `collection()` and `doc()` instead of `child()`
- ID generation uses `doc().id` instead of `push().key`

## 🔄 Remaining Manual Steps

### Step 4: Update PublicMenuViewerScreen

Replace the import and database reference in `lib/presentation/screens/public/public_menu_viewer_screen.dart`:

**Line 3** - Change:
```dart
import 'package:firebase_database/firebase_database.dart';
```
To:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

**Line 18** - Change:
```dart
final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
```
To:
```dart
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
```

**Lines 45-95** - Replace the entire `_loadPublicMenus` method body with:
```dart
try {
  final state = GoRouterState.of(context);
  final ownerId = state.uri.queryParameters['uid'];

  developer.log('Loading public menus for owner: $ownerId', name: 'PublicMenuDebug');

  Query<Map<String, dynamic>> query = _firestore.collection('menu_sections');
  
  if (ownerId != null && ownerId.isNotEmpty) {
    query = query.where('ownerId', isEqualTo: ownerId);
  }
  
  query = query.where('isActive', isEqualTo: true);
  
  final snapshot = await query.get();
  
  List<MenuSection> menusList = [];
  for (var doc in snapshot.docs) {
    try {
      final data = doc.data();
      data['id'] = doc.id;
      menusList.add(MenuSection.fromMap(data));
    } catch (e) {
      developer.log('Skipping invalid menu: ${doc.id}', error: e);
    }
  }

  if (mounted) {
    setState(() {
      _menus = menusList;
      _isLoading = false;
    });
  }
} catch (e) {
  developer.log('Error loading menus: $e', error: e);
  if (mounted) {
    setState(() {
      _hasError = true;
      _errorMessage = e.toString();
      _isLoading = false;
    });
  }
}
```

## 📊 Data Migration

### Option 1: Manual Migration (Recommended for Small Datasets)
1. Export data from RTDB using Firebase Console
2. Transform the data structure if needed
3. Import into Firestore using Firebase Console

### Option 2: Automated Migration Script
Create a migration script in `lib/scripts/migrate_to_firestore.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateData() async {
  await Firebase.initializeApp();
  
  final rtdb = FirebaseDatabase.instance.ref();
  final firestore = FirebaseFirestore.instance;
  
  // Migrate menu_sections
  final menusSnapshot = await rtdb.child('menu_sections').get();
  if (menusSnapshot.exists && menusSnapshot.value != null) {
    final menusData = menusSnapshot.value as Map;
    
    for (var entry in menusData.entries) {
      final menuId = entry.key.toString();
      final menuData = Map<String, dynamic>.from(entry.value as Map);
      
      await firestore.collection('menu_sections').doc(menuId).set(menuData);
      print('Migrated menu: $menuId');
    }
  }
  
  // Migrate surveys
  final surveysSnapshot = await rtdb.child('surveys').get();
  if (surveysSnapshot.exists && surveysSnapshot.value != null) {
    final surveysData = surveysSnapshot.value as Map;
    
    for (var entry in surveysData.entries) {
      final surveyId = entry.key.toString();
      final surveyData = Map<String, dynamic>.from(entry.value as Map);
      
      await firestore.collection('surveys').doc(surveyId).set(surveyData);
      print('Migrated survey: $surveyId');
    }
  }
  
  // Migrate feedback
  final feedbackSnapshot = await rtdb.child('feedback').get();
  if (feedbackSnapshot.exists && feedbackSnapshot.value != null) {
    final feedbackData = feedbackSnapshot.value as Map;
    
    for (var entry in feedbackData.entries) {
      final feedbackId = entry.key.toString();
      final data = Map<String, dynamic>.from(entry.value as Map);
      
      await firestore.collection('feedback').doc(feedbackId).set(data);
      print('Migrated feedback: $feedbackId');
    }
  }
  
  print('Migration complete!');
}
```

Run with: `dart run lib/scripts/migrate_to_firestore.dart`

## 🔒 Firestore Security Rules

Update your Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Menu sections - public read for active menus, owner write
    match /menu_sections/{menuId} {
      allow read: if resource.data.isActive == true || 
                     (request.auth != null && request.auth.uid == resource.data.ownerId);
      allow write: if request.auth != null && request.auth.uid == request.resource.data.ownerId;
    }
    
    // Surveys - public read for active, owner write
    match /surveys/{surveyId} {
      allow read: if resource.data.isActive == true || 
                     (request.auth != null && request.auth.uid == resource.data.creatorId);
      allow write: if request.auth != null && request.auth.uid == request.resource.data.creatorId;
    }
    
    // Feedback - owner read, public write
    match /feedback/{feedbackId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.owner_id;
      allow create: if true; // Allow anonymous feedback submission
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.owner_id;
    }
    
    // Survey responses - owner read, public write
    match /survey_responses/{responseId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.owner_id;
      allow create: if true; // Allow anonymous survey responses
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.owner_id;
    }
  }
}
```

## ✅ Benefits of Firestore

1. **No Type Casting Issues**: Native web support without minified type errors
2. **Better Queries**: Compound queries, array operations, full-text search
3. **Automatic Indexing**: Better performance for complex queries
4. **Offline Support**: Built-in offline persistence
5. **Scalability**: Better for larger datasets
6. **Real-time Updates**: More efficient listeners

## 🧪 Testing Checklist

- [ ] Login/Signup works
- [ ] Menu CRUD operations work
- [ ] Survey CRUD operations work
- [ ] Feedback submission works
- [ ] Public menu viewer loads correctly
- [ ] QR code generation works
- [ ] Dashboard displays data correctly

## 🚀 Deployment

```bash
# Build for web
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy
```

## 📝 Notes

- Firestore has different pricing than RTDB (pay per read/write/delete)
- Consider implementing pagination for large datasets
- Use Firestore indexes for complex queries
- Monitor usage in Firebase Console
