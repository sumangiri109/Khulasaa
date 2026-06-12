import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: To run the application, ensure to configure Firebase core initializers:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..signInAnonymously()),
        ChangeNotifierProvider(create: (_) => FirebaseService()),
      ],
      child: const KhulasaaApp(),
    ),
  );
}

class KhulasaaApp extends StatelessWidget {
  const KhulasaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Khulasaa - Speak the Truth. Stay Hidden.',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF06B6D4),
          brightness: Brightness.dark,
          primary: const Color(0xFF06B6D4),
          secondary: const Color(0xFF10B981),
          error: const Color(0xFFEF4444),
          background: const Color(0xFF08070D),
          surface: const Color(0xFF16141F),
        ),
        textTheme: const TextTheme(
          displayMedium: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF16141F).withOpacity(0.7),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
