import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds - Sleek, grayish, neutral dark palette
  static const Color darkBackground = Color(0xFF131416);
  static const Color darkSurface = Color(0xFF1C1E22);
  static const Color darkCard = Color(0xFF24272D);
  static const Color darkCardBorder = Color(0xFF333740);

  // Accents - Muted, professional, no oversaturated AI-slop
  static const Color primaryGold = Color(0xFFDCDFE6); // Titanium / clean platinum
  static const Color secondaryAmber = Color(0xFF9096A2); // Cool neutral slate
  static const Color accentCrimson = Color(0xFFCC5A57); // Muted dark crimson
  static const Color accentGreen = Color(0xFF62A368); // Muted sage green
  static const Color accentBlue = Color(0xFF5A7E9C); // Steel blue
  static const Color epicPurple = Color(0xFF7A8090); // Slate badge
  static const Color epicCardBg = Color(0xFF22242A);

  // Statuses
  static const Color statusConnected = Color(0xFF62A368);
  static const Color statusReconnecting = Color(0xFFB5935A);
  static const Color statusDisconnected = Color(0xFFCC5A57);

  // Typography
  static const Color textPrimary = Color(0xFFEDEDF0);
  static const Color textSecondary = Color(0xFFA1A6B4);
  static const Color textMuted = Color(0xFF6B707E);
  static const Color textUndone = Color(0xFF505460);
}
