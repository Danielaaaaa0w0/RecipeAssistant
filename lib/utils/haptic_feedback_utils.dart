// lib/utils/haptic_feedback_utils.dart
import 'package:vibration/vibration.dart';
import 'package:logging/logging.dart';

final _hapticsLog = Logger('AppHaptics');

class AppHaptics {

  static void lightClick() {
    try {
      Vibration.vibrate(duration: 50, amplitude: 64); // Short and light
      // _hapticsLog.info("Haptic: Light Click - Vibrate called.");
    } catch (e, s) {
      _hapticsLog.severe("Error during lightClick vibration", e, s);
    }
  }

  static void mediumImpact() {
    try {
      Vibration.vibrate(duration: 60, amplitude: 128); // A bit stronger
      // _hapticsLog.info("Haptic: Medium Impact - Vibrate called.");
    } catch (e, s) {
      _hapticsLog.severe("Error during mediumImpact vibration", e, s);
    }
  }

  static void success() {
    try {
      Vibration.vibrate(pattern: [0, 30, 50, 60], intensities: [0, 80, 0, 120]);
      // _hapticsLog.info("Haptic: Success - Vibrate pattern called.");
    } catch (e, s) {
      _hapticsLog.severe("Error during success vibration pattern", e, s);
    }
  }

  static void error() {
    try {
      Vibration.vibrate(pattern: [0, 50, 100, 50], intensities: [0, 150, 0, 150]);
      // _hapticsLog.info("Haptic: Error - Vibrate pattern called.");
    } catch (e, s) {
      _hapticsLog.severe("Error during error vibration pattern", e, s);
    }
  }
}