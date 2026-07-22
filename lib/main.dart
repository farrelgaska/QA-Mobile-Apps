import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.validateConfiguration();
  runApp(const MainApp());
}
