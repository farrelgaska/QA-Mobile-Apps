@echo off
dart tool/pre_build.dart
if %errorlevel% neq 0 exit /b %errorlevel%
flutter run -d chrome
