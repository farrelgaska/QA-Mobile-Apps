import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

<<<<<<< HEAD
class MyApp extends StatelessWidget {
  const MyApp({super.key});
=======
class MainApp extends StatelessWidget {
  const MainApp({super.key});
>>>>>>> a001c6019b186ea06a08ff79d40b71fe5a9c3a4f

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // follows device setting
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
