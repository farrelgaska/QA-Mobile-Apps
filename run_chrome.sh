#!/bin/bash
dart tool/pre_build.dart
if [ $? -ne 0 ]; then
  exit 1
fi
flutter run -d chrome
