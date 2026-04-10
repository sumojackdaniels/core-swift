import XCTest
@testable import CoreSwift
import CoreLocation

final class HeadingCalculatorTests: XCTestCase {

    // MARK: - bearingBetween

    func testBearingNYCtoLA() {
        // NYC: 40.7128° N, 74.0060° W → LA: 34.0522° N, 118.2437° W
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let la = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let bearing = HeadingCalculator.bearingBetween(from: nyc, to: la)

        // Should be roughly 273° (westward)
        XCTAssertEqual(bearing, 273, accuracy: 3, "Bearing from NYC to LA should be roughly 273°")
        print("✓ testBearingNYCtoLA")
    }

    func testBearingNYCtoMiami() {
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let miami = CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)
        let bearing = HeadingCalculator.bearingBetween(from: nyc, to: miami)

        // Should be roughly 198° (south-southwest)
        XCTAssertEqual(bearing, 198, accuracy: 3, "Bearing from NYC to Miami should be roughly 198°")
        print("✓ testBearingNYCtoMiami")
    }

    // MARK: - distanceBetween

    func testDistanceNYCtoLA() {
        let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let la = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let distance = HeadingCalculator.distanceBetween(from: nyc, to: la)

        // Should be roughly 3,944 km = 3,944,000 m
        XCTAssertEqual(distance, 3_944_000, accuracy: 50_000, "Distance from NYC to LA should be roughly 3,944 km")
        print("✓ testDistanceNYCtoLA")
    }

    // MARK: - compassDirection

    func testCompassDirectionAllEight() {
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 0), "N")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 45), "NE")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 90), "E")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 135), "SE")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 180), "S")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 225), "SW")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 270), "W")
        XCTAssertEqual(HeadingCalculator.compassDirection(degrees: 315), "NW")
        print("✓ testCompassDirectionAllEight")
    }

    // MARK: - relativeBearing

    func testRelativeBearingRight() {
        let result = HeadingCalculator.relativeBearing(currentHeading: 0, bearing: 90)
        XCTAssertEqual(result, 90, accuracy: 0.01, "Heading 0° bearing 90° should be +90° (right)")
        print("✓ testRelativeBearingRight")
    }

    func testRelativeBearingLeft() {
        let result = HeadingCalculator.relativeBearing(currentHeading: 90, bearing: 0)
        XCTAssertEqual(result, -90, accuracy: 0.01, "Heading 90° bearing 0° should be -90° (left)")
        print("✓ testRelativeBearingLeft")
    }

    // MARK: - formatDistance

    func testFormatDistanceShort() {
        let result = HeadingCalculator.formatDistance(160.9)
        XCTAssertEqual(result, "0.1 mi")
        print("✓ testFormatDistanceShort")
    }

    func testFormatDistanceOneMile() {
        let result = HeadingCalculator.formatDistance(1609.3)
        XCTAssertEqual(result, "1.0 mi")
        print("✓ testFormatDistanceOneMile")
    }

    func testFormatDistanceTenMiles() {
        let result = HeadingCalculator.formatDistance(16093)
        XCTAssertEqual(result, "10.0 mi")
        print("✓ testFormatDistanceTenMiles")
    }
}
