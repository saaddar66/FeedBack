import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// Migration script to copy data from Firebase Realtime Database to Cloud Firestore
/// Run this once to migrate all existing data
Future<void> main() async {
  print('🚀 Starting data migration from RTDB to Firestore...\n');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final rtdb = FirebaseDatabase.instance.ref();
  final firestore = FirebaseFirestore.instance;
  
  int totalMigrated = 0;
  
  try {
    // Migrate Users
    print('📋 Migrating users...');
    final usersSnapshot = await rtdb.child('users').get();
    if (usersSnapshot.exists && usersSnapshot.value != null) {
      final usersData = usersSnapshot.value as Map;
      
      for (var entry in usersData.entries) {
        final userId = entry.key.toString();
        final userData = Map<String, dynamic>.from(entry.value as Map);
        
        await firestore.collection('users').doc(userId).set(userData);
        print('  ✓ Migrated user: $userId');
        totalMigrated++;
      }
    }
    print('✅ Users migration complete\n');
    
    // Migrate Menu Sections
    print('📋 Migrating menu sections...');
    final menusSnapshot = await rtdb.child('menu_sections').get();
    if (menusSnapshot.exists && menusSnapshot.value != null) {
      final menusData = menusSnapshot.value as Map;
      
      for (var entry in menusData.entries) {
        final menuId = entry.key.toString();
        final menuData = Map<String, dynamic>.from(entry.value as Map);
        
        // Handle dishes array/map
        if (menuData['dishes'] != null) {
          if (menuData['dishes'] is Map) {
            // Convert map to list
            final dishesMap = menuData['dishes'] as Map;
            menuData['dishes'] = dishesMap.values.toList();
          }
        }
        
        await firestore.collection('menu_sections').doc(menuId).set(menuData);
        print('  ✓ Migrated menu: ${menuData['title'] ?? menuId}');
        totalMigrated++;
      }
    }
    print('✅ Menu sections migration complete\n');
    
    // Migrate Surveys
    print('📋 Migrating surveys...');
    final surveysSnapshot = await rtdb.child('surveys').get();
    if (surveysSnapshot.exists && surveysSnapshot.value != null) {
      final surveysData = surveysSnapshot.value as Map;
      
      for (var entry in surveysData.entries) {
        final surveyId = entry.key.toString();
        final surveyData = Map<String, dynamic>.from(entry.value as Map);
        
        // Handle questions map -> convert to list
        if (surveyData['questions'] != null && surveyData['questions'] is Map) {
          final questionsMap = surveyData['questions'] as Map;
          final questionsList = questionsMap.entries.map((e) {
            final q = Map<String, dynamic>.from(e.value as Map);
            q['id'] = e.key.toString();
            return q;
          }).toList();
          surveyData['questions'] = questionsList;
        }
        
        await firestore.collection('surveys').doc(surveyId).set(surveyData);
        print('  ✓ Migrated survey: ${surveyData['title'] ?? surveyId}');
        totalMigrated++;
      }
    }
    print('✅ Surveys migration complete\n');
    
    // Migrate Feedback
    print('📋 Migrating feedback...');
    final feedbackSnapshot = await rtdb.child('feedback').get();
    if (feedbackSnapshot.exists && feedbackSnapshot.value != null) {
      final feedbackData = feedbackSnapshot.value as Map;
      
      for (var entry in feedbackData.entries) {
        final feedbackId = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value as Map);
        
        await firestore.collection('feedback').doc(feedbackId).set(data);
        print('  ✓ Migrated feedback: $feedbackId');
        totalMigrated++;
      }
    }
    print('✅ Feedback migration complete\n');
    
    // Migrate Survey Responses
    print('📋 Migrating survey responses...');
    final responsesSnapshot = await rtdb.child('survey_responses').get();
    if (responsesSnapshot.exists && responsesSnapshot.value != null) {
      final responsesData = responsesSnapshot.value as Map;
      
      for (var entry in responsesData.entries) {
        final responseId = entry.key.toString();
        final data = Map<String, dynamic>.from(entry.value as Map);
        
        await firestore.collection('survey_responses').doc(responseId).set(data);
        print('  ✓ Migrated response: $responseId');
        totalMigrated++;
      }
    }
    print('✅ Survey responses migration complete\n');
    
    print('🎉 Migration complete! Total items migrated: $totalMigrated');
    print('\n✅ You can now use Firestore instead of RTDB');
    print('💡 Remember to update Firestore security rules in Firebase Console');
    
  } catch (e, stack) {
    print('❌ Error during migration: $e');
    print(stack);
  }
}
