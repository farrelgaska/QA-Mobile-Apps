import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
