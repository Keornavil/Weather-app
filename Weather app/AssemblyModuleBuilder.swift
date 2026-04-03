import UIKit

// MARK: - Protocol
@MainActor
protocol AssemblyBuilderProtocol {
    func createMainViewModule(coordinator: CoordinatorProtocol) -> UIViewController
}

// MARK: - Assembly Builder
@MainActor
final class AssemblyBuilder: AssemblyBuilderProtocol {

    // MARK: - Public
    func createMainViewModule(coordinator: CoordinatorProtocol) -> UIViewController {
        let networkService = NetworkServiceWithAsync()
        let service = WeatherService(networkService: networkService)
        let repository = WeatherRepository(service: service)
        let locationService = LocationService()
        let viewModel = MainViewModel(
            repository: repository,
            locationService: locationService
        )
        let viewController = MainViewController(viewModel: viewModel)
        return viewController
    }
}
