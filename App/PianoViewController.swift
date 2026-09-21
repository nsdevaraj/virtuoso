import UIKit
import LittleA
import LittleAUI

final class PianoViewController: UIViewController {
    private struct Settings: Decodable { let fps: Double }
    private let piano = LittleAView(frame: .zero)
    private let errorLabel = UILabel()
    private let resumeButton = UIButton(type: .system)
    private var fullScreen = false
    private var failed = false

    override var prefersStatusBarHidden: Bool { fullScreen }
    override var prefersHomeIndicatorAutoHidden: Bool { fullScreen }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.914, green: 0.933, blue: 0.961, alpha: 1)
        piano.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(piano)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            piano.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            piano.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            piano.topAnchor.constraint(equalTo: safe.topAnchor),
            piano.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .systemRed
        errorLabel.backgroundColor = .systemBackground
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.accessibilityIdentifier = "piano-error"
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)
        resumeButton.configuration = .filled()
        resumeButton.setTitle("Resume piano", for: .normal)
        resumeButton.accessibilityIdentifier = "piano-resume"
        resumeButton.addTarget(self, action: #selector(resume), for: .touchUpInside)
        resumeButton.isHidden = true
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resumeButton)
        NSLayoutConstraint.activate([
            errorLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),
            errorLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            resumeButton.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            resumeButton.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
        ])
        piano.onError = { [weak self] error in self?.showError(error) }
        piano.onPlaybackChanged = { [weak self] playing in
            guard let self else { return }
            self.resumeButton.isHidden = playing || self.failed
        }
        piano.onEvents = { [weak self] events in
            guard let self else { return }
            for event in events {
                if event.name == "fullscreen" {
                    self.fullScreen.toggle()
                    self.setNeedsStatusBarAppearanceUpdate()
                    self.setNeedsUpdateOfHomeIndicatorAutoHidden()
                } else if event.name == "openLessonConverter" {
                    self.openLessonConverter()
                }
            }
        }
        do {
            guard let lab = Bundle.main.url(forResource: "game", withExtension: "lab", subdirectory: "Game"),
                  let config = Bundle.main.url(forResource: "game", withExtension: "json", subdirectory: "Game") else {
                throw LittleAError.apiFailure("The piano bundle is missing. Re-export the iOS app.")
            }
            let settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: config))
            try piano.load(bundleData: Data(contentsOf: lab), framesPerSecond: settings.fps)
        } catch { showError(error) }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !failed { resume() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pause()
    }

    func pause() { piano.pause() }
    func dispose() { piano.dispose() }

    private func openLessonConverter() {
        guard let url = URL(string: "https://pianolesson-tau.vercel.app/") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func resume() {
        do {
            try piano.play()
            piano.becomeFirstResponder()
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        failed = true
        piano.pause()
        resumeButton.isHidden = true
        errorLabel.text = "Unable to play piano: \(error.localizedDescription)"
        errorLabel.isHidden = false
        NSLog("[Virtuoso] %@", String(describing: error))
        UIAccessibility.post(notification: .announcement, argument: errorLabel.text)
    }
}
