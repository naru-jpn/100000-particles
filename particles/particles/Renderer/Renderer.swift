//
//  Renderer.swift
//  particles
//
//  Created by Naruki Chigira on 2020/07/16.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

import Foundation
import MetalKit

final class Renderer: NSObject, MTKViewDelegate {
    /// Thread control factor for simulation.
    ///
    /// Simulation can not be computed in parallel because input of simulation is depend on output by previous result of simulation.
    private static let maxInFlightSimulationBuffers: Int = 1

    /// Thread control factor for rendering.
    ///
    /// Render with triple buffering. (https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html)
    private static let maxInFlightRenderingBuffers: Int = 3

    /// Device
    let device: MTLDevice

    /// CommandQueue
    let commandQueue: MTLCommandQueue

    /// Semaphore to control simulation.
    let simulationInFlightSemaphore = DispatchSemaphore(value: Renderer.maxInFlightSimulationBuffers)

    /// Semaphore to control whole steps of drawing.
    let inFlightSemaphore = DispatchSemaphore(value: Renderer.maxInFlightRenderingBuffers)

    /// Number of particles.
    private var numberOfParticles: Int = 0

    /// Texture descriptor for renderingTextures.
    private let renderingTextureDescriptor: MTLTextureDescriptor

    /// Texture drawn particles.
    private var renderingTextures: [MTLTexture] = []

    /// Index to control triple buffering.
    private var currentBufferIndex: Int = 0

    /// Viewport size to render particles.
    private var viewportSize: vector_uint2 = .zero

    init(device: MTLDevice, view: MTKView) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue with device.makeCommandQueue().")
        }
        self.commandQueue = commandQueue

        // --- Buffers

        // --- Textures

        renderingTextureDescriptor = MTLTextureDescriptor()
        renderingTextureDescriptor.textureType = .type2D
        renderingTextureDescriptor.pixelFormat = view.colorPixelFormat
        renderingTextureDescriptor.usage = [.renderTarget, .shaderRead]
    }

    // MARK: - MTKViewDelegate

    func draw(in view: MTKView) {
        guard renderingTextures.count == Renderer.maxInFlightRenderingBuffers else {
            return
        }

        let semaphore = inFlightSemaphore
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)

        // Simulatation
        do {
            let simulateSemaphore = simulationInFlightSemaphore
            _ = simulateSemaphore.wait(timeout: DispatchTime.distantFuture)

            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                fatalError("Failed to make command buffer.")
            }
            // TODO: simulation
            commandBuffer.addCompletedHandler { _ in
                simulateSemaphore.signal()
            }
            commandBuffer.commit()
        }

        // Rendering
        do {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                fatalError("Failed to make command buffer.")
            }
            // TODO: Rendering
            commandBuffer.addCompletedHandler { _ in
                semaphore.signal()
            }
            commandBuffer.commit()
        }

        currentBufferIndex = (currentBufferIndex + 1) % Renderer.maxInFlightRenderingBuffers
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize.x = uint(size.width)
        viewportSize.y = uint(size.height)

        // Resize rendering textures
        renderingTextureDescriptor.width = Int(viewportSize.x)
        renderingTextureDescriptor.height = Int(viewportSize.y)
        do {
            var textures: [MTLTexture] = []
            (0..<Renderer.maxInFlightRenderingBuffers).forEach { _ in
                guard let texture = device.makeTexture(descriptor: renderingTextureDescriptor) else {
                    fatalError("Failed to make rendering texture.")
                }
                textures.append(texture)
            }
            renderingTextures = textures
        }
    }
}
