import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertService {
  static Future<void> triggerEmergencyWorkflow(String detectedSound, String contactNumber) async {
    String locationText = "Location unavailable.";

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (serviceEnabled && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        locationText = "I am here: https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
      }
    } catch (e) {
      debugPrint("Location fetch failed: $e");
    }

    String message = "EMERGENCY: EchoGuard detected a potentially dangerous sound ($detectedSound). $locationText";

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: contactNumber,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      debugPrint("Could not open SMS composer.");
    }
  }
}