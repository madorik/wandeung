import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/climbing_record.dart';
import '../models/user_climbing_stats.dart';

// 필터 상태 (카테고리별 단일 선택)
final selectedColorFilterProvider = StateProvider<String?>((ref) => null);
final selectedStatusFilterProvider = StateProvider<String?>((ref) => null);
final selectedTagFilterProvider = StateProvider<String?>((ref) => null);
final selectedGymFilterProvider = StateProvider<String?>((ref) => null);

final recordsByDateProvider =
    FutureProvider.family<List<ClimbingRecord>, DateTime>((ref, date) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final dateStr = date.toIso8601String().split('T')[0];

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select()
      .eq('user_id', userId)
      .eq('recorded_at', dateStr)
      .isFilter('parent_record_id', null)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 캘린더 마커용: 월별 기록이 있는 날짜 목록
final recordDatesProvider =
    FutureProvider.family<Set<DateTime>, DateTime>((ref, month) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at')
      .eq('user_id', userId)
      .gte('recorded_at', firstDay.toIso8601String().split('T')[0])
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0])
      .isFilter('parent_record_id', null);

  return (response as List)
      .map((e) => DateTime.parse(e['recorded_at']))
      .toSet();
});

/// 캘린더 배지용: 월별 날짜 → 필터 적용된 기록 개수 맵
final recordCountsByDateProvider =
    FutureProvider.family<Map<DateTime, int>, DateTime>((ref, month) async {
  final color = ref.watch(selectedColorFilterProvider);
  final status = ref.watch(selectedStatusFilterProvider);
  final tag = ref.watch(selectedTagFilterProvider);
  final gymName = ref.watch(selectedGymFilterProvider);

  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at, status, difficulty_color, gym_name, tags')
      .eq('user_id', userId)
      .gte('recorded_at', firstDay.toIso8601String().split('T')[0])
      .lte('recorded_at', lastDay.toIso8601String().split('T')[0])
      .isFilter('parent_record_id', null);

  final counts = <DateTime, int>{};
  for (final row in response as List) {
    if (color != null && row['difficulty_color'] != color) continue;
    if (status != null && row['status'] != status) continue;
    if (gymName != null && row['gym_name'] != gymName) continue;
    if (tag != null) {
      final tags = (row['tags'] as List?)?.cast<String>() ?? [];
      if (!tags.contains(tag)) continue;
    }

    final date = DateTime.parse(row['recorded_at']);
    final normalized = DateTime(date.year, date.month, date.day);
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }
  return counts;
});

/// 내보내기 영상 목록 (원본 기록 기준)
final exportedRecordsProvider =
    FutureProvider.family<List<ClimbingRecord>, String>((ref, parentId) async {
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select()
      .eq('parent_record_id', parentId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 홈 탭 요약 통계 (최근 30일 기준)
final userStatsProvider = FutureProvider<UserClimbingStats>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final thirtyDaysAgoStr = thirtyDaysAgo.toIso8601String().split('T')[0];

  // 최근 30일 기록만 조회
  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('id, status, recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .gte('recorded_at', thirtyDaysAgoStr);

  final rows = response as List;
  final totalClimbs = rows.length;
  final totalCompleted =
      rows.where((r) => r['status'] == 'completed').length;
  final totalInProgress =
      rows.where((r) => r['status'] == 'in_progress').length;
  final completionRate =
      totalClimbs > 0 ? (totalCompleted / totalClimbs * 100) : 0.0;
  final inProgressRate =
      totalClimbs > 0 ? (totalInProgress / totalClimbs * 100) : 0.0;

  // 이번 달 등반 횟수
  final monthlyClimbs = rows.where((r) {
    final date = DateTime.parse(r['recorded_at']);
    return date.year == now.year && date.month == now.month;
  }).length;

  // 연속 등반일수 (streak) — 전체 기록 기준
  final allResponse = await SupabaseConfig.client
      .from('climbing_records')
      .select('recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null);

  final allDates = (allResponse as List)
      .map((r) => DateTime.parse(r['recorded_at']))
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  int streak = 0;
  var checkDate = DateTime(now.year, now.month, now.day);
  if (!allDates.contains(checkDate)) {
    checkDate = checkDate.subtract(const Duration(days: 1));
  }
  while (allDates.contains(checkDate)) {
    streak++;
    checkDate = checkDate.subtract(const Duration(days: 1));
  }

  return UserClimbingStats(
    totalClimbs: totalClimbs,
    totalCompleted: totalCompleted,
    totalInProgress: totalInProgress,
    completionRate: completionRate,
    inProgressRate: inProgressRate,
    currentStreak: streak,
    monthlyClimbs: monthlyClimbs,
  );
});

/// 홈 탭 최근 기록 (최신 5개)
final recentRecordsProvider =
    FutureProvider<List<ClimbingRecord>>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select()
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .order('recorded_at', ascending: false)
      .order('created_at', ascending: false)
      .limit(5);

  return (response as List)
      .map((e) => ClimbingRecord.fromMap(e))
      .toList();
});

/// 홈 탭 최근 방문 암장 (최근 기록에서 추출, 중복 제거)
final recentGymsProvider = FutureProvider<List<String>>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('gym_name, recorded_at')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_name', 'is', null)
      .order('recorded_at', ascending: false)
      .limit(50);

  final seen = <String>{};
  final gyms = <String>[];
  for (final row in response as List) {
    final name = row['gym_name'] as String;
    if (seen.add(name)) gyms.add(name);
    if (gyms.length >= 5) break;
  }
  return gyms;
});

/// 사용자가 방문한 모든 암장 이름 (필터용)
final userVisitedGymsProvider = FutureProvider<List<String>>((ref) async {
  final userId = SupabaseConfig.client.auth.currentUser!.id;

  final response = await SupabaseConfig.client
      .from('climbing_records')
      .select('gym_name')
      .eq('user_id', userId)
      .isFilter('parent_record_id', null)
      .not('gym_name', 'is', null);

  final gyms = (response as List)
      .map((e) => e['gym_name'] as String)
      .toSet()
      .toList()
    ..sort();

  return gyms;
});

class RecordService {
  static final _supabase = SupabaseConfig.client;

  /// 기록 저장 (영상은 로컬 경로로 보관)
  static Future<ClimbingRecord> saveRecord({
    required String videoPath,
    required String grade,
    required String difficultyColor,
    required String status,
    String? gymId,
    String? gymName,
    String? thumbnailPath,
    List<String> tags = const [],
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final record = ClimbingRecord(
      userId: userId,
      gymId: gymId,
      gymName: gymName,
      grade: grade,
      difficultyColor: difficultyColor,
      status: status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: tags,
      recordedAt: DateTime.now(),
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 수정
  static Future<ClimbingRecord> updateRecord({
    required String recordId,
    required String grade,
    required String difficultyColor,
    required String status,
    String? gymId,
    String? gymName,
    List<String> tags = const [],
  }) async {
    final response = await _supabase
        .from('climbing_records')
        .update({
          'grade': grade,
          'difficulty_color': difficultyColor,
          'status': status,
          'gym_id': gymId,
          'gym_name': gymName,
          'tags': tags,
        })
        .eq('id', recordId)
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 내보내기 영상 저장 (원본 기록의 메타데이터를 복사)
  static Future<ClimbingRecord> saveExport({
    required String parentRecordId,
    required ClimbingRecord parentRecord,
    required String videoPath,
    String? thumbnailPath,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    final record = ClimbingRecord(
      userId: userId,
      gymId: parentRecord.gymId,
      gymName: parentRecord.gymName,
      grade: parentRecord.grade,
      difficultyColor: parentRecord.difficultyColor,
      status: parentRecord.status,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      tags: parentRecord.tags,
      recordedAt: parentRecord.recordedAt,
      parentRecordId: parentRecordId,
    );

    final response = await _supabase
        .from('climbing_records')
        .insert(record.toInsertMap())
        .select()
        .single();

    return ClimbingRecord.fromMap(response);
  }

  /// 기록 삭제
  static Future<void> deleteRecord(String recordId) async {
    await _supabase
        .from('climbing_records')
        .delete()
        .eq('id', recordId);
  }
}
