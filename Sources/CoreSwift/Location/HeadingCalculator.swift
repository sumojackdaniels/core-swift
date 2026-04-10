import CoreLocation
import Foundation

public enum HeadingCalculator {
    /// Returns the bearing in degrees (0-360) from one coordinate to another.
    public static func bearingBetween(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let dLon = (to.longitude - from.longitude).radians

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).degrees

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Returns the distance in meters between two coordinates using the Haversine formula.
    public static func distanceBetween(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0 // meters

        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let dLat = (to.latitude - from.latitude).radians
        let dLon = (to.longitude - from.longitude).radians

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }

    /// Returns one of 8 compass directions for a given bearing in degrees.
    public static func compassDirection(degrees: Double) -> String {
        let normalized = (degrees + 360).truncatingRemainder(dividingBy: 360)
        switch normalized {
        case 337.5..<360, 0..<22.5:
            return "N"
        case 22.5..<67.5:
            return "NE"
        case 67.5..<112.5:
            return "E"
        case 112.5..<157.5:
            return "SE"
        case 157.5..<202.5:
            return "S"
        case 202.5..<247.5:
            return "SW"
        case 247.5..<292.5:
            return "W"
        case 292.5..<337.5:
            return "NW"
        default:
            return "N"
        }
    }

    /// Returns the relative bearing from -180 to 180. Positive = right, negative = left.
    public static func relativeBearing(currentHeading: Double, bearing: Double) -> Double {
        var diff = bearing - currentHeading
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }

    /// Formats a distance in meters as miles (e.g. "0.3 mi", "1.2 mi").
    public static func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        return String(format: "%.1f mi", miles)
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
