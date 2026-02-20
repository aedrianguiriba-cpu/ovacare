import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHealthService {
  SupabaseHealthService(this._client);

  final SupabaseClient _client;

  /// Check if the Supabase client is properly initialized
  bool get isInitialized => _client != null;

  Future<List<Map<String, dynamic>>> fetchMenstrualCycles(String userId) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return [];
      }
      
      final rows = await _client
          .from('menstrual_cycles')
          .select('*')
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      return rows
          .map<Map<String, dynamic>>((row) => {
                'id': row['id'],
                'start': DateTime.parse(row['start_date'].toString()),
                'end': DateTime.parse(row['end_date'].toString()),
                'flow': (row['flow'] as num?)?.toInt() ?? 0,
                'notes': row['notes']?.toString() ?? '',
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching menstrual cycles: $e');
      return [];
    }
  }

  /// Test if menstrual_cycles table exists and RLS is working
  Future<Map<String, dynamic>> testMenstrualCyclesRLS(String userId) async {
    final result = {
      'table_exists': false,
      'can_read': false,
      'can_write': false,
      'error': 'Not tested',
    };

    try {
      print('🧪 Testing menstrual_cycles table access...');
      
      // Test 1: Can we query the table?
      try {
        await _client
            .from('menstrual_cycles')
            .select()
            .eq('user_id', userId)
            .limit(1);
        
        result['table_exists'] = true;
        result['can_read'] = true;
        print('✅ Table exists and SELECT works');
      } catch (e) {
        print('❌ Cannot SELECT from table: $e');
        result['error'] = e.toString();
        return result;
      }
      
      // Test 2: Try a test INSERT/DELETE
      try {
        final today = DateTime.now();
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        
        final testData = {
          'user_id': userId,
          'start_date': dateStr,
          'end_date': dateStr,
          'flow': 0,
          'notes': 'TEST ENTRY - DELETE ME',
        };
        
        print('🧪 Testing INSERT...');
        final insertResult = await _client
            .from('menstrual_cycles')
            .insert([testData])
            .select();
        
        result['can_write'] = true;
        print('✅ INSERT works! RLS policies are configured correctly');
        
        // Clean up test entry
        if (insertResult.isNotEmpty) {
          final testId = insertResult[0]['id'];
          await _client.from('menstrual_cycles').delete().eq('id', testId);
          print('🧹 Cleaned up test entry');
        }
      } catch (insertError) {
        print('❌ Cannot INSERT to table: $insertError');
        result['error'] = insertError.toString();
      }
      
      return result;
    } catch (e) {
      print('❌ Unexpected error in RLS test: $e');
      result['error'] = e.toString();
      return result;
    }
  }

  Future<void> replaceMenstrualCycles(
    String userId,
    List<Map<String, dynamic>> cycles,
  ) async {
    try {
      if (!isInitialized) {
        print('❌ Supabase client not initialized');
        throw Exception('Supabase client not initialized');
      }
      
      if (userId.isEmpty) {
        print('❌ User ID is empty');
        throw Exception('User ID is empty');
      }
      
      print('🔄 Deleting existing menstrual cycles for user: $userId');
      try {
        await _client.from('menstrual_cycles').delete().eq('user_id', userId);
        print('✅ Deleted existing records');
      } catch (deleteError) {
        // Don't fail on delete - just warn and continue
        print('⚠️ Delete failed (RLS may not allow DELETE): $deleteError');
      }

      if (cycles.isEmpty) {
        print('⚠️ No cycles to insert');
        return;
      }

      final payload = cycles.map((cycle) {
        try {
          // Safely get and convert dates
          final startValue = cycle['start'];
          final endValue = cycle['end'];
          
          if (startValue == null) {
            throw Exception('Start date is null in cycle: $cycle');
          }
          if (endValue == null) {
            throw Exception('End date is null in cycle: $cycle');
          }
          
          // Handle both DateTime and String types
          final start = startValue is DateTime 
              ? startValue 
              : DateTime.parse(startValue.toString());
          final end = endValue is DateTime 
              ? endValue 
              : DateTime.parse(endValue.toString());
          
          final data = {
            'user_id': userId,
            'start_date': _toIsoDate(start),
            'end_date': _toIsoDate(end),
            'flow': (cycle['flow'] as num?)?.toInt() ?? 0,
            'notes': cycle['notes']?.toString() ?? '',
          };
          print('  📅 Preparing: ${data['start_date']} to ${data['end_date']} (flow: ${data['flow']})');
          return data;
        } catch (e) {
          print('❌ Error processing cycle: $cycle');
          print('   Details: $e');
          rethrow;
        }
      }).toList();

      print('📤 Inserting ${payload.length} cycles into database...');
      final response = await _client.from('menstrual_cycles').insert(payload).select();
      print('✅ Successfully inserted ${payload.length} menstrual cycle entries');
      print('   Response: ${response.length} records confirmed');
    } catch (e) {
      print('\n❌ === ERROR REPLACING MENSTRUAL CYCLES ===');
      print('Error: $e');
      print('Type: ${e.runtimeType}');
      print('\n💡 LIKELY CAUSES:');
      print('   1. RLS policies not configured in Supabase');
      print('   2. menstrual_cycles table does not exist');
      print('   3. User does not have INSERT permission');
      print('\n✅ FIX:');
      print('   1. Go to Supabase Dashboard → SQL Editor');
      print('   2. Run: SUPABASE_MENSTRUAL_CYCLES_RLS.sql');
      print('   3. Or call testDatabase() to diagnose');
      print('❌ === END ERROR ===\n');
      
      // Re-throw so caller knows it failed
      rethrow;
    }
  }

  /// Insert a single menstrual cycle (alternative method that doesn't delete existing)
  Future<Map<String, dynamic>> insertMenstrualCycle(
    String userId,
    Map<String, dynamic> cycle,
  ) async {
    try {
      if (!isInitialized) {
        print('❌ Supabase client not initialized');
        return {};
      }
      
      final start = cycle['start'] as DateTime;
      final end = cycle['end'] as DateTime;
      
      final payload = {
        'user_id': userId,
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
        'flow': (cycle['flow'] as num?)?.toInt() ?? 0,
        'notes': cycle['notes']?.toString() ?? '',
      };
      
      print('📤 Inserting single cycle: ${payload['start_date']} to ${payload['end_date']}');
      final response = await _client
          .from('menstrual_cycles')
          .insert(payload)
          .select()
          .single();
      
      print('✅ Successfully inserted menstrual cycle');
      return response;
    } catch (e) {
      print('❌ Error inserting menstrual cycle: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchSymptoms(String userId) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return [];
      }
      
      final rows = await _client
          .from('symptoms')
          .select('*')
          .eq('user_id', userId)
          .order('logged_at', ascending: false);

      return rows
          .map<Map<String, dynamic>>((row) => {
                'id': row['id'],
                'date': DateTime.parse(row['logged_at'].toString()),
                'mood': row['mood']?.toString() ?? '',
                'cramps': (row['cramps'] as num?)?.toInt() ?? 0,
                'acne': row['acne'] == true,
                'bloating': row['bloating'] == true,
                'hairGrowth': row['hair_growth'] == true,
                'irregular': row['irregular'] == true,
                'severity': (row['severity'] as num?)?.toInt() ?? 1,
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching symptoms: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertSymptom(
    String userId,
    Map<String, dynamic> symptom,
  ) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return {};
      }
      
      final inserted = await _client
          .from('symptoms')
          .insert({
            'user_id': userId,
            'logged_at': (symptom['date'] as DateTime?)?.toIso8601String(),
            'mood': symptom['mood']?.toString() ?? '',
            'cramps': (symptom['cramps'] as num?)?.toInt() ?? 0,
            'acne': symptom['acne'] == true,
            'bloating': symptom['bloating'] == true,
            'hair_growth': symptom['hairGrowth'] == true,
            'irregular': symptom['irregular'] == true,
            'severity': (symptom['severity'] as num?)?.toInt() ?? 1,
          })
          .select()
          .single();

      return {
        'id': inserted['id'],
        'date': DateTime.parse(inserted['logged_at'].toString()),
        'mood': inserted['mood']?.toString() ?? '',
        'cramps': (inserted['cramps'] as num?)?.toInt() ?? 0,
        'acne': inserted['acne'] == true,
        'bloating': inserted['bloating'] == true,
        'hairGrowth': inserted['hair_growth'] == true,
        'irregular': inserted['irregular'] == true,
        'severity': (inserted['severity'] as num?)?.toInt() ?? 1,
      };
    } catch (e) {
      print('❌ Error inserting symptom: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchMedications(String userId) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return [];
      }
      
      final rows = await _client
          .from('medications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return rows
          .map<Map<String, dynamic>>((row) => {
                'id': row['id'],
                'name': row['name']?.toString() ?? '',
                'dose': row['dose']?.toString() ?? '',
                'times': (row['times'] as List<dynamic>? ?? []).cast<String>(),
                'taken': (row['taken'] as List<dynamic>? ?? [])
                    .map((value) => value == true)
                    .toList(),
                'date': DateTime.parse(row['created_at'].toString()),
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching medications: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertMedication(
    String userId,
    Map<String, dynamic> medication,
  ) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return {};
      }
      
      final inserted = await _client
          .from('medications')
          .insert({
            'user_id': userId,
            'name': medication['name']?.toString() ?? '',
            'dose': medication['dose']?.toString() ?? '',
            'times': (medication['times'] as List<dynamic>? ?? []).cast<String>(),
            'taken': (medication['taken'] as List<dynamic>? ?? [])
                .map((value) => value == true)
                .toList(),
          })
          .select()
          .single();

      return {
        'id': inserted['id'],
        'name': inserted['name']?.toString() ?? '',
        'dose': inserted['dose']?.toString() ?? '',
        'times': (inserted['times'] as List<dynamic>? ?? []).cast<String>(),
        'taken': (inserted['taken'] as List<dynamic>? ?? [])
            .map((value) => value == true)
            .toList(),
        'date': DateTime.parse(inserted['created_at'].toString()),
      };
    } catch (e) {
      print('❌ Error inserting medication: $e');
      return {};
    }
  }

  Future<void> updateMedicationTaken(
    int medicationId,
    List<bool> taken,
  ) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return;
      }
      
      await _client.from('medications').update({
        'taken': taken,
      }).eq('id', medicationId);
      print('✅ Medication status updated');
    } catch (e) {
      print('❌ Error updating medication status: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHydration(String userId) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return [];
      }
      
      final rows = await _client
          .from('hydration')
          .select('*')
          .eq('user_id', userId)
          .order('logged_at', ascending: false);

      return rows
          .map<Map<String, dynamic>>((row) => {
                'id': row['id'],
                'date': DateTime.parse(row['logged_at'].toString()),
                'ml': (row['amount'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching hydration data: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertHydration(
    String userId,
    Map<String, dynamic> hydration,
  ) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return {};
      }
      
      final inserted = await _client
          .from('hydration')
          .insert({
            'user_id': userId,
            'amount': (hydration['amount'] as num?)?.toDouble() ?? 0.0,
            'unit': hydration['unit']?.toString() ?? 'ml',
            'logged_at': (hydration['date'] as DateTime?)?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return {
        'id': inserted['id'],
        'date': DateTime.parse(inserted['logged_at'].toString()),
        'ml': (inserted['amount'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      print('❌ Error inserting hydration data: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeightEntries(String userId) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return [];
      }
      
      final rows = await _client
          .from('weight_entries')
          .select('*')
          .eq('user_id', userId)
          .order('logged_at', ascending: false);

      return rows
          .map<Map<String, dynamic>>((row) => {
                'id': row['id'],
                'date': DateTime.parse(row['logged_at'].toString()),
                'weight': (row['weight'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();
    } catch (e) {
      print('❌ Error fetching weight entries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> insertWeightEntry(
    String userId,
    Map<String, dynamic> weightEntry,
  ) async {
    try {
      if (!isInitialized) {
        print('⚠️ Supabase client not initialized');
        return {};
      }
      
      final inserted = await _client
          .from('weight_entries')
          .insert({
            'user_id': userId,
            'weight': (weightEntry['weight'] as num?)?.toDouble() ?? 0.0,
            'unit': weightEntry['unit']?.toString() ?? 'kg',
            'logged_at': (weightEntry['date'] as DateTime?)?.toIso8601String() ??
                DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return {
        'id': inserted['id'],
        'date': DateTime.parse(inserted['logged_at'].toString()),
        'weight': (inserted['weight'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      print('❌ Error inserting weight entry: $e');
      return {};
    }
  }

  /// Test the Supabase connection and table availability
  Future<bool> testConnection() async {
    try {
      if (!isInitialized) {
        print('❌ Supabase client not initialized');
        return false;
      }
      
      print('🔍 Testing Supabase connection...');
      
      // Try a simple query to check if table exists
      await _client
          .from('menstrual_cycles')
          .select('*')
          .limit(1);
      
      print('✅ Supabase connection successful');
      print('   menstrual_cycles table is accessible');
      return true;
    } catch (e) {
      print('❌ Supabase connection test failed: $e');
      return false;
    }
  }

  String _toIsoDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.toIso8601String().split('T').first;
  }
}
