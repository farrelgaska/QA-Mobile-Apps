import 'package:flutter/material.dart';

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double card = 24.0;
  static const double cardLarge = 28.0;
  static const double circular = 100.0;

  static BorderRadius get smBorderRadius => BorderRadius.circular(sm);
  static BorderRadius get mdBorderRadius => BorderRadius.circular(md);
  static BorderRadius get lgBorderRadius => BorderRadius.circular(lg);
  static BorderRadius get cardBorderRadius => BorderRadius.circular(card);
  static BorderRadius get cardLargeBorderRadius => BorderRadius.circular(cardLarge);
  static BorderRadius get circularBorderRadius => BorderRadius.circular(circular);
}
