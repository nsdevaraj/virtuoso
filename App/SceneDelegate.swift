import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = PianoViewController()
        window?.makeKeyAndVisible()

    }

    func sceneWillResignActive(_ scene: UIScene) {
        (window?.rootViewController as? PianoViewController)?.pause()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        (window?.rootViewController as? PianoViewController)?.dispose()
    }
}
