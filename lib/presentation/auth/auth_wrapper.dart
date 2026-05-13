import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/main_navigation.dart';
import 'login_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Saat stream loading, cek session yang ada
        if (snapshot.connectionState == ConnectionState.waiting) {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) return const MainNavigation();
          return const LoginPage();
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const MainNavigation();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}