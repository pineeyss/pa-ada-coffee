import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dpwksursqcuyozdkgptb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwd2tzdXJzcWN1eW96ZGtncHRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTE3NDUsImV4cCI6MjA4OTkyNzc0NX0._gGuJ5BE5BEtLk-vWproUH0B-Cn13MJj8K-W-aCkmhY',
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}