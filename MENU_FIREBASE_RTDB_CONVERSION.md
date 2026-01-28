# Menu Feature - Firebase RTDB Conversion

## Issue
The menu feature was initially implemented using Cloud Firestore, but the project uses Firebase Realtime Database (RTDB). This caused a permission error:

```
Cloud Firestore API has not been used in project feedy-cebf6 before or it is disabled.
```

## Solution
Converted MenuProvider from Firestore to Firebase Realtime Database to match the existing survey implementation.

## Changes Made

### MenuProvider (`lib/presentation/providers/menu_provider.dart`)

#### Before (Firestore)
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Loading menus
Query query = _firestore.collection('menu_sections');
final snapshot = await query.get();
_menus = snapshot.docs.map((doc) => MenuSection.fromMap(doc.data())).toList();

// Saving menu
await _firestore.collection('menu_sections').doc(id).set(data, SetOptions(merge: true));

// Deleting menu
await _firestore.collection('menu_sections').doc(menuId).delete();
```

#### After (Firebase RTDB)
```dart
import 'package:firebase_database/firebase_database.dart';

final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

// Loading menus
final snapshot = await _databaseRef.child('menu_sections').get();
// Parse Map/List structure
if (value is Map) {
  for (var entry in value.entries) {
    final map = Map<String, dynamic>.from(entry.value as Map);
    map['id'] = entry.key.toString();
    menusList.add(MenuSection.fromMap(map));
  }
}

// Saving menu
await _databaseRef.child('menu_sections').child(id).set(data);

// Deleting menu
await _databaseRef.child('menu_sections').child(menuId).remove();
```

## Key Differences

| Aspect | Firestore | Firebase RTDB |
|--------|-----------|---------------|
| Import | `cloud_firestore` | `firebase_database` |
| Instance | `FirebaseFirestore.instance` | `FirebaseDatabase.instance.ref()` |
| Path | `.collection('name').doc(id)` | `.child('name').child(id)` |
| Read | `.get()` returns `QuerySnapshot` | `.get()` returns `DataSnapshot` |
| Data Format | Documents in collections | Nested JSON structure |
| Write | `.set(data, SetOptions(merge: true))` | `.set(data)` |
| Update | `.update({...})` with `FieldValue.serverTimestamp()` | `.update({...})` with `DateTime.now().toIso8601String()` |
| Delete | `.delete()` | `.remove()` |
| Parsing | `snapshot.docs.map((doc) => doc.data())` | Parse Map/List structure manually |

## Database Structure

### Firebase RTDB Path: `menu_sections/{menuId}`
```json
{
  "menu_sections": {
    "-NXyZ123abc": {
      "id": "-NXyZ123abc",
      "title": "Appetizers",
      "description": "Start your meal right",
      "dishes": [
        {
          "id": "1234567890",
          "name": "Spring Rolls",
          "description": "Crispy vegetable rolls",
          "price": 5.99,
          "isAvailable": true,
          "createdAt": "2026-01-26T16:30:00.000Z"
        }
      ],
      "isActive": true,
      "createdAt": "2026-01-26T16:00:00.000Z",
      "updatedAt": "2026-01-26T16:30:00.000Z",
      "ownerId": "user123"
    }
  }
}
```

## Implementation Pattern

The conversion follows the same pattern used for surveys in `firebase_database_impl.dart`:

1. **Read**: Get snapshot, check if exists, parse Map/List structure
2. **Write**: Use `.set()` with full data object
3. **Update**: Use `.update()` with specific fields
4. **Delete**: Use `.remove()`
5. **ID Generation**: Use `.push().key` for new IDs
6. **Error Handling**: Add developer logs for debugging

## Testing

The menu feature now works with Firebase RTDB:
- ✅ Create new menu sections
- ✅ Add/edit/delete dishes
- ✅ Save to Firebase RTDB
- ✅ Load from Firebase RTDB
- ✅ Toggle active status
- ✅ Delete menu sections
- ✅ User-scoped data (ownerId filtering)

## Benefits

1. **Consistency**: All features now use the same database (RTDB)
2. **No API Conflicts**: No need to enable Firestore API
3. **Offline Support**: RTDB has built-in offline persistence
4. **Real-time Updates**: Can easily add real-time listeners if needed
5. **Cost Effective**: RTDB is included in Firebase free tier

## Notes

- The menu models (`MenuSection`, `MenuDish`) remain unchanged
- The UI screens remain unchanged
- Only the provider's database interaction layer was modified
- The conversion maintains full feature parity with the Firestore version
