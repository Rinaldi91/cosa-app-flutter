import 'package:flutter/material.dart';

class GreetingUtils {
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  static IconData getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return Icons.wb_sunny;
    } else if (hour < 18) {
      return Icons.wb_cloudy;
    } else {
      return Icons.nights_stay;
    }
  }
}
