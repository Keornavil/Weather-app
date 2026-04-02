import Foundation
import CoreLocation
import Combine

// MARK: - Protocol
protocol LocationServiceProtocol {
    func requestLocation() -> AnyPublisher<CLLocationCoordinate2D?, Never>
}

// MARK: - Service
final class LocationService: NSObject, LocationServiceProtocol {

    // MARK: - Properties
    private let manager: CLLocationManager
    private let subject = PassthroughSubject<CLLocationCoordinate2D?, Never>()
    private var didEmit = false

    // MARK: - Init
    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    // MARK: - Public
    func requestLocation() -> AnyPublisher<CLLocationCoordinate2D?, Never> {
        didEmit = false
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .notDetermined:
                self.manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                self.subject.send(nil)
            @unknown default:
                self.subject.send(nil)
            }
        }

        return subject.prefix(1).eraseToAnyPublisher()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !didEmit else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            didEmit = true
            subject.send(nil)
        case .notDetermined:
            break
        @unknown default:
            didEmit = true
            subject.send(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !didEmit else { return }
        didEmit = true
        subject.send(locations.first?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !didEmit else { return }
        didEmit = true
        subject.send(nil)
    }
}
