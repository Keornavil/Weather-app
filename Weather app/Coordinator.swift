import UIKit

// MARK: - Protocols
@MainActor
protocol CoordinatorMain: AnyObject {
    var navigationController: UINavigationController? { get set }
    var assemblyBuilder: AssemblyBuilderProtocol? { get set }
}

@MainActor
protocol CoordinatorProtocol: CoordinatorMain {
    func initialMainViewController()
}

// MARK: - Coordinator
@MainActor
final class Coordinator: CoordinatorProtocol {

    // MARK: - Properties
    var navigationController: UINavigationController?
    var assemblyBuilder: AssemblyBuilderProtocol?

    // MARK: - Init
    init(navigationController: UINavigationController, assemblyBuilder: AssemblyBuilderProtocol) {
        self.navigationController = navigationController
        self.assemblyBuilder = assemblyBuilder
    }

    // MARK: - Public
    func initialMainViewController() {
        guard let navigationController,
              let mainViewController = assemblyBuilder?.createMainViewModule(coordinator: self) else {
            return
        }
        navigationController.viewControllers = [mainViewController]
    }
}
