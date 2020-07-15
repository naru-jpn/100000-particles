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

final class MetalViewController: UIViewController {
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
        metalView.device = device

        renderer = Renderer(device: device, view: metalView)
        renderer?.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)

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
                self?.metalView.isPaused = false
            }
            .store(in: &cancellables)
    }
}
