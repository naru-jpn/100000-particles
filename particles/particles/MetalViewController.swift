//
//  MetalViewController.swift
//  particles
//
//  Created by Naruki Chigira on 2020/07/16.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

import Combine
import MetalKit
import UIKit

final class MetalViewController: UIViewController, RendererDelegate, SettingsViewControllerDelegate {
    @IBOutlet private var settingButton: UIButton! {
        didSet {
            settingButton.titleLabel?.layer.shadowOffset = .zero
            settingButton.titleLabel?.layer.shadowRadius = 1.2
            settingButton.titleLabel?.layer.shadowOpacity = 0.5
            settingButton.titleLabel?.layer.shadowColor = UIColor.black.cgColor
        }
    }

    private var renderer: Renderer?

    private var metalView: MTKView {
        view as! MTKView
    }

    private var cancellables: [AnyCancellable] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get device from MTLCreateSystemDefaultDevice().")
        }
        metalView.isPaused = true
        metalView.device = device

        renderer = Renderer(device: device, view: metalView)
        renderer?.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        renderer?.delegate = self

        metalView.delegate = renderer

        // Prevent executing metal commands when application is in background.
        // Reference: https://developer.apple.com/documentation/metal/preparing_your_metal_app_to_run_in_the_background
        NotificationCenter.Publisher(center: .default, name: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.metalView.isPaused = true
            }
            .store(in: &cancellables)
        NotificationCenter.Publisher(center: .default, name: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.metalView.isPaused = self?.presentedViewController != nil
            }
            .store(in: &cancellables)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentSettings()
    }

    @IBAction private func didTapSettingButton(_ sender: UIButton) {
        presentSettings()
    }

    private func presentSettings() {
        metalView.isPaused = true
        let viewController = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "SettingsViewController") as! SettingsViewController
        viewController.delegate = self
        present(viewController, animated: true)
    }

    // MARK: RendererDelegate

    func rendererDidCompleteConfigure(_ renderer: Renderer) {
        metalView.isPaused = false
    }

    // MARK: SettingsViewControllerDelegate

    func settingsViewControllerDidComplete(_ viewController: SettingsViewController, setting: Setting) {
        viewController.dismiss(animated: true)
        DispatchQueue.global().async {
            self.renderer?.configure(setting: setting)
        }
    }
}
