import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  final _supabase = SupabaseConfig.client;

  void _init() {
    final currentUser = _supabase.auth.currentUser;
    state = AsyncValue.data(currentUser);

    _supabase.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']!;

      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google ID Token is null');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _supabase.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    final userId = _supabase.auth.currentUser!.id;

    // 스토리지 영상 삭제
    try {
      final files =
          await _supabase.storage.from('climbing-videos').list(path: userId);
      if (files.isNotEmpty) {
        final paths = files.map((f) => '$userId/${f.name}').toList();
        await _supabase.storage.from('climbing-videos').remove(paths);
      }
    } catch (_) {
      // 스토리지 삭제 실패해도 계속 진행
    }

    // 등반 기록 삭제
    await _supabase.from('climbing_records').delete().eq('user_id', userId);

    // 사용자가 생성한 암장 삭제
    await _supabase.from('climbing_gyms').delete().eq('created_by', userId);

    // auth.users에서 계정 삭제 (SECURITY DEFINER 함수)
    await _supabase.rpc('delete_own_user');

    await GoogleSignIn().signOut();
    state = const AsyncValue.data(null);
  }
}
