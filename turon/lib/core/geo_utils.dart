import 'dart:math' as math;

/// Pure geographic math utilities: Haversine distance, forward bearing,
/// midpoint, bounding box calculation, and Qarshi default camera constants.
class GeoUtils {
  GeoUtils._();

  /// Qarshi city center coordinates (Step 4 section 2).
  static const double qarshiLat = 38.8606;
  static const double qarshiLng = 65.7898;
  static const double qarshiDefaultZoom = 13.0;

  static const double _earthRadiusMeters = 6371000.0;

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
  static double _radToDeg(double rad) => rad * (180.0 / math.pi);

  /// Calculates the great-circle distance in meters between two WGS84 points
  /// using the Haversine formula (matches PostGIS ST_Distance sphere approx).
  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final rLat1 = _degToRad(lat1);
    final rLat2 = _degToRad(lat2);

    final sinDLat = math.sin(dLat / 2.0);
    final sinDLng = math.sin(dLng / 2.0);

    final a =
        sinDLat * sinDLat +
        math.cos(rLat1) * math.cos(rLat2) * sinDLng * sinDLng;
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1.0 - a)));
    return _earthRadiusMeters * c;
  }

  /// Calculates Haversine distance rounded to 2 decimal places (matches DB round(..., 2)).
  static double haversineMetersRounded(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final raw = haversineMeters(lat1, lng1, lat2, lng2);
    return (raw * 100.0).roundToDouble() / 100.0;
  }

  /// Calculates WGS84 ellipsoidal (Vincenty) distance in meters, matching
  /// PostGIS `ST_Distance(geography, geography)` on the WGS84 spheroid.
  static double spheroidMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    if (lat1 == lat2 && lng1 == lng2) return 0.0;
    const double a = 6378137.0;
    const double f = 1.0 / 298.257223563;
    const double b = (1.0 - f) * a;

    final phi1 = _degToRad(lat1);
    final phi2 = _degToRad(lat2);
    final l = _degToRad(lng2 - lng1);

    final u1 = math.atan((1.0 - f) * math.tan(phi1));
    final u2 = math.atan((1.0 - f) * math.tan(phi2));
    final sinU1 = math.sin(u1);
    final cosU1 = math.cos(u1);
    final sinU2 = math.sin(u2);
    final cosU2 = math.cos(u2);

    var lambda = l;
    double sinSigma = 0.0;
    double cosSigma = 0.0;
    double sigma = 0.0;
    double sinAlpha = 0.0;
    double cosSqAlpha = 0.0;
    double cos2SigmaM = 0.0;

    for (var i = 0; i < 100; i++) {
      final sinLambda = math.sin(lambda);
      final cosLambda = math.cos(lambda);
      final term1 = cosU2 * sinLambda;
      final term2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;
      sinSigma = math.sqrt(term1 * term1 + term2 * term2);
      if (sinSigma == 0.0) return 0.0;
      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = math.atan2(sinSigma, cosSigma);
      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cosSqAlpha = 1.0 - sinAlpha * sinAlpha;
      cos2SigmaM = cosSqAlpha != 0.0
          ? cosSigma - 2.0 * sinU1 * sinU2 / cosSqAlpha
          : 0.0;
      final c = f / 16.0 * cosSqAlpha * (4.0 + f * (4.0 - 3.0 * cosSqAlpha));
      final lambdaPrev = lambda;
      lambda =
          l +
          (1.0 - c) *
              f *
              sinAlpha *
              (sigma +
                  c *
                      sinSigma *
                      (cos2SigmaM +
                          c * cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM)));
      if ((lambda - lambdaPrev).abs() <= 1e-12) break;
    }

    final uSq = cosSqAlpha * (a * a - b * b) / (b * b);
    final bigA =
        1.0 +
        uSq / 16384.0 * (4096.0 + uSq * (-768.0 + uSq * (320.0 - 175.0 * uSq)));
    final bigB =
        uSq / 1024.0 * (256.0 + uSq * (-128.0 + uSq * (74.0 - 47.0 * uSq)));
    final deltaSigma =
        bigB *
        sinSigma *
        (cos2SigmaM +
            bigB /
                4.0 *
                (cosSigma * (-1.0 + 2.0 * cos2SigmaM * cos2SigmaM) -
                    bigB /
                        6.0 *
                        cos2SigmaM *
                        (-3.0 + 4.0 * sinSigma * sinSigma) *
                        (-3.0 + 4.0 * cos2SigmaM * cos2SigmaM)));
    final dist = b * bigA * (sigma - deltaSigma);
    return dist.isNaN ? haversineMeters(lat1, lng1, lat2, lng2) : dist;
  }

  /// Calculates WGS84 spheroid distance rounded to 2 decimal places.
  static double spheroidMetersRounded(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final raw = spheroidMeters(lat1, lng1, lat2, lng2);
    return (raw * 100.0).roundToDouble() / 100.0;
  }

  /// Formats length in meters: `>= 1000` -> `'441.9 km'`, `< 1000` -> `'48.3 m'`.
  static String formatLength(double meters) => _formatLengthImpl(meters);

  /// Calculates forward azimuth (initial bearing) in degrees [0, 360)
  /// from (lat1, lng1) to (lat2, lng2), where 0 = North, 90 = East, 180 = South, 270 = West.
  static double bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = _degToRad(lat1);
    final phi2 = _degToRad(lat2);
    final deltaLambda = _degToRad(lng2 - lng1);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final theta = math.atan2(y, x);
    return (_radToDeg(theta) + 360.0) % 360.0;
  }

  /// Midpoint between two coordinates (arithmetic mean suitable for short city segments).
  static ({double lat, double lng}) midpoint(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return (lat: (lat1 + lat2) / 2.0, lng: (lng1 + lng2) / 2.0);
  }

  /// Computes bounding box (southWestLat, southWestLng, northEastLat, northEastLng)
  /// for a list of (lat, lng) coordinates. Returns null if points is empty.
  static ({
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  })? boundingBox(Iterable<({double lat, double lng})> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) return null;

    var minLat = iterator.current.lat;
    var maxLat = iterator.current.lat;
    var minLng = iterator.current.lng;
    var maxLng = iterator.current.lng;

    while (iterator.moveNext()) {
      final p = iterator.current;
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    return (minLat: minLat, minLng: minLng, maxLat: maxLat, maxLng: maxLng);
  }

  /// Computes the camera target (lat, lng) so that [objectLat], [objectLng]
  /// is centered in the unobstructed visible map area above a bottom sheet of
  /// height [bottomSheetHeightDp] (and/or left of a side overlay of width
  /// [rightPanelWidthDp]) at the given [zoom].
  static ({double lat, double lng}) offsetCameraTargetForSheet({
    required double objectLat,
    required double objectLng,
    required double zoom,
    required double bottomSheetHeightDp,
    double rightPanelWidthDp = 0.0,
  }) {
    final worldPixelsDp = 256.0 * math.pow(2.0, zoom);
    final degLngPerDp = 360.0 / worldPixelsDp;
    final degLatPerDp =
        (360.0 * math.cos(_degToRad(objectLat))) / worldPixelsDp;

    final shiftSouthDp = bottomSheetHeightDp / 2.0;
    final shiftEastDp = rightPanelWidthDp / 2.0;

    return (
      lat: (objectLat - shiftSouthDp * degLatPerDp).clamp(-85.0, 85.0),
      lng: objectLng + shiftEastDp * degLngPerDp,
    );
  }
}

/// Shared length formatter: `>= 1000` -> `'441.9 km'`, `< 1000` -> `'48.3 m'`.
String formatLength(double meters) => _formatLengthImpl(meters);

String _formatLengthImpl(double meters) {
  if (meters.abs() >= 1000.0) {
    return '${(meters / 1000.0).toStringAsFixed(1)} km';
  }
  return '${meters.toStringAsFixed(1)} m';
}
