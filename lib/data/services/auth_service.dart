import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password.trim(),
    );

    final user = response.user;

    if (user != null) {
      await supabase.from('profiles').insert({
        'id': user.id,
        'email': email.trim(),
        'role': role,
      });
    }

    return response;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}