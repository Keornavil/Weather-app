import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties
    var window: UIWindow?

    // MARK: - UIWindowSceneDelegate
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let navigationController = UINavigationController()
        let assemblyBuilder = AssemblyBuilder()
        let coordinator = Coordinator(navigationController: navigationController, assemblyBuilder: assemblyBuilder)
        coordinator.initialMainViewController()

        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Intentionally left empty.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Intentionally left empty.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Intentionally left empty.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Intentionally left empty.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Intentionally left empty.
    }
}
