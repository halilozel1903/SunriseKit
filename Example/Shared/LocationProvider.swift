import CoreLocation
import Foundation
import Observation

/// The device's location, asked for only when someone taps "Use My Location". Optional: the fixed cities work
/// without it, and the screenshot scenes never ask.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var city: City?
    private(set) var isLocating = false
    private(set) var message: String?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        message = nil
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            denied()
        default:
            manager.requestLocation()
        }
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        guard isLocating else { return }
        switch status {
        case .notDetermined:
            break
        case .denied, .restricted:
            denied()
        default:
            manager.requestLocation()
        }
    }

    private func denied() {
        isLocating = false
        message = "Location access is off. Turn it on in Settings to see the sun where you are."
    }

    private func located(latitude: Double, longitude: Double) {
        isLocating = false
        city = City.current(latitude: latitude, longitude: longitude)
    }

    private func failed(_ text: String) {
        isLocating = false
        message = text
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor in self.located(latitude: latitude, longitude: longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let text = error.localizedDescription
        Task { @MainActor in self.failed(text) }
    }
}
