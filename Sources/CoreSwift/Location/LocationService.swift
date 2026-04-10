import CoreLocation

@Observable
@MainActor
public final class LocationService {
    public private(set) var currentLocation: CLLocation?
    public private(set) var currentHeading: CLHeading?
    public private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager: CLLocationManager
    private let coordinator: Coordinator

    public init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus

        let coordinator = Coordinator()
        self.coordinator = coordinator
        manager.delegate = coordinator

        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.headingFilter = 5
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true

        coordinator.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.currentLocation = location
            }
        }

        coordinator.onHeadingUpdate = { [weak self] heading in
            Task { @MainActor in
                self?.currentHeading = heading
            }
        }

        coordinator.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    public func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationService {
    final class Coordinator: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
        var onLocationUpdate: ((CLLocation) -> Void)?
        var onHeadingUpdate: ((CLHeading) -> Void)?
        var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            onLocationUpdate?(location)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            onHeadingUpdate?(newHeading)
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            onAuthorizationChange?(manager.authorizationStatus)
        }
    }
}
