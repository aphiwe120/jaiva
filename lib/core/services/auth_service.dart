import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Get the Supabase client instance
  final _supabase = Supabase.instance.client;

  // 🆔 Get Current User ID (Used by the AI DJ and Hugging Face)
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // 📝 SIGN UP
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // 🔓 SIGN IN
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // 🚪 SIGN OUT
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out. Please try again.');
    }
  }

  // 🛠️ Helper method to make error messages human-readable
  String _handleAuthError(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }
    return 'An unexpected error occurred.';
  }
}