import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHealthService {
  SupabaseHealthService(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchMenstrualCycles(String userId) async {
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
  }

  Future<void> replaceMenstrualCycles(
    String userId,
    List<Map<String, dynamic>> cycles,
  ) async {
    await _client.from('menstrual_cycles').delete().eq('user_id', userId);

    if (cycles.isEmpty) return;

    final payload = cycles.map((cycle) {
      final start = cycle['start'] as DateTime;
      final end = cycle['end'] as DateTime;
      return {
        'user_id': userId,
        'start_date': _toIsoDate(start),
        'end_date': _toIsoDate(end),
        'flow': (cycle['flow'] as num?)?.toInt() ?? 0,
        'notes': cycle['notes']?.toString() ?? '',
      };
    }).toList();

    await _client.from('menstrual_cycles').insert(payload);
  }

  Future<List<Map<String, dynamic>>> fetchSymptoms(String userId) async {
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
  }

  Future<Map<String, dynamic>> insertSymptom(
    String userId,
    Map<String, dynamic> symptom,
  ) async {
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
  }

  Future<List<Map<String, dynamic>>> fetchMedications(String userId) async {
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
  }

  Future<Map<String, dynamic>> insertMedication(
    String userId,
    Map<String, dynamic> medication,
  ) async {
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
  }

  Future<void> updateMedicationTaken(
    int medicationId,
    List<bool> taken,
  ) async {
    await _client.from('medications').update({
      'taken': taken,
    }).eq('id', medicationId);
  }

  Future<List<Map<String, dynamic>>> fetchHydration(String userId) async {
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
  }

  Future<Map<String, dynamic>> insertHydration(
    String userId,
    Map<String, dynamic> hydration,
  ) async {
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
  }

  Future<List<Map<String, dynamic>>> fetchWeightEntries(String userId) async {
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
  }

  Future<Map<String, dynamic>> insertWeightEntry(
    String userId,
    Map<String, dynamic> weightEntry,
  ) async {
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
  }

  String _toIsoDate(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.toIso8601String().split('T').first;
  }
}
