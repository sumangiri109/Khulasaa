import 'package:flutter/material.dart';
import 'screen/submitreport.dart';

void main() {
  runApp(const MyApp());
}

// MyApp is now StatefulWidget so it can rebuild MaterialApp when theme changes
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Any widget can call MyApp.of(context).toggleTheme() to switch theme
  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  bool get isDark => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khulasaa',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0392B),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC0392B),
          brightness: Brightness.dark,
        ),
      ),
      home: SubmitReportScreen(onToggleTheme: toggleTheme),
    );
  }
}
