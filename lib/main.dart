import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ ADD THIS
import 'screens/login_screen.dart';
import 'utils/colors.dart';
import 'dart:async';

// ✅ Main function with Supabase initialization
void main() {
  runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // ✅ Initialize Supabase with your credentials
      await Supabase.initialize(
        url: 'https://wdeatczsfxczijfvnnoo.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndkZWF0Y3pzZnhjemlqZnZubm9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxODM0NzksImV4cCI6MjA3MDc1OTQ3OX0.cE9EtndVpWqxpY54vVLBNUq4RlgPuMvVq2iGCBMYcDg',
      );
      
      debugPrint('✅ Supabase initialized successfully');
      runApp(const VoicePickingApp());
    } catch (e) {
      debugPrint('❌ Main app error: $e');
    }
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

// ✅ Add this getter for easy Supabase access
final supabase = Supabase.instance.client;

class VoicePickingApp extends StatelessWidget {
  const VoicePickingApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      // Set status bar style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      return MaterialApp(
        title: 'Voice Picking App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.pink,
          primaryColor: AppColors.primaryPink,
          fontFamily: 'System',
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.primaryPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const LoginScreen(),
        // ✅ Error page builder
        builder: (context, child) {
          try {
            return child ?? const Center(
              child: Text('Loading...'),
            );
          } catch (e) {
            debugPrint('App builder error: $e');
            return const Center(
              child: Text(
                'App Error',
                style: TextStyle(color: Colors.red),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('MaterialApp build error: $e');
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Critical Error',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
        ),
      );
    }
  }
}
