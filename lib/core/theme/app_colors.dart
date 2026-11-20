import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds - Atmospheric tabletop dark palette
  static const Color darkBackground = Color(0xFF111215);
  static const Color darkSurface = Color(0xFF181A20);
  static const Color darkCard = Color(0xFF20232B);
  static const Color darkCardBorder = Color(0xFF2E333F);

  // Accents - Warm, refined, authentic fantasy RPG palette
  static const Color primaryGold = Color(0xFFE5B869); // Warm dragon gold
  static const Color secondaryAmber = Color(0xFFD98E32); // Deep torchlight amber
  static const Color accentCrimson = Color(0xFFE05353); // Punchy crimson
  static const Color accentGreen = Color(0xFF42B86E); // Vibrant forest emerald
  static const Color accentBlue = Color(0xFF4A90E2); // Arcane royal blue
  static const Color accentFaction = Color(0xFFDE7C38); // Pathfinder terracotta crest
  static const Color epicPurple = Color(0xFFA855F7); // Luminous epic purple
  static const Color epicCardBg = Color(0xFF261E34); // Mystical deep violet

  // Statuses
  static const Color statusConnected = Color(0xFF42B86E);
  static const Color statusReconnecting = Color(0xFFE5A93C);
  static const Color statusDisconnected = Color(0xFFE05353);

  // Typography
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFFA6ABB9);
  static const Color textMuted = Color(0xFF6F768A);
  static const Color textUndone = Color(0xFF4D5363);
}
