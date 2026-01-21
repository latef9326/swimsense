import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// Service for real-time location tracking during swimming
class LocationService {
  /// Get continuous position updates with 0.5-meter filter
  /// Returns a stream of Position objects for distance calculation
  Stream<Position> getPositionStream() {
    debugPrint('📍 LocationService.getPositionStream() called');
    // Check and request location permissions
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // ✅ 0 = no distance filter, rely on GPS accuracy filtering in cubit
        // ✅ REMOVED: timeLimit - GPS timeout was KILLING stream in buildings!
      ),
    ).handleError((error) {
      if (kDebugMode) {
        debugPrint('🔴 Location Service Error: $error');
      }
      // ✅ Don't return null - let error propagate to listener
      throw error;
    });
  }

  /// Request location permissions before starting stream
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        debugPrint('📍 Location Permission Result: $result');
        return result == LocationPermission.whileInUse || 
               result == LocationPermission.always;
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('🔴 Location permission denied forever - opening settings');
        await Geolocator.openLocationSettings();
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Error requesting location permission: $e');
      return false;
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
