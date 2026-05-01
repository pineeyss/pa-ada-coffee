import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
// Import AuthWrapper supaya dicek dulu status loginnya
import 'presentation/auth/auth_wrapper.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale untuk format mata uang
  await initializeDateFormatting('id_ID', null);

  // Ganti dengan URL dan Key asli kamu
  await Supabase.initialize(
    url: 'https://dpwksursqcuyozdkgptb.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwd2tzdXJzcWN1eW96ZGtncHRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTE3NDUsImV4cCI6MjA4OTkyNzc0NX0._gGuJ5BE5BEtLk-vWproUH0B-Cn13MJj8K-W-aCkmhY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ad.A Coffee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      // DI SINI KUNCINYA: Pakai AuthWrapper, jangan MainNavigation
      home: const AuthWrapper(), 
    );
  }
}