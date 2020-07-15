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

    /// Max length of buffers for simulated particles.
    private static let maxNumberOfParticles: Int = 100_000

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

    /// Pipeline state for simulation.
    private let simulatePipelineState: MTLComputePipelineState

    /// Pipeline state for rendering.
    private let renderPipelineState: MTLRenderPipelineState

    /// Simulated particle buffers.
    let particleBuffers: [MTLBuffer]

    /// Index to control triple buffering.
    private var currentBufferIndex: Int = 0

    private var simulatedBufferIndex: Int {
        (currentBufferIndex + 1) % Renderer.maxInFlightRenderingBuffers
    }

    /// Viewport size to render particles.
    private var viewportSize: vector_uint2 = .zero

    init(device: MTLDevice, view: MTKView) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue by device.makeCommandQueue().")
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to make library by device.makeDefaultLibrary().")
        }

        // --- Pipelines

        // simulatePipelineState
        do {
            guard let function = library.makeFunction(name: "simulate") else {
                fatalError("Failed to make function simulate.")
            }
            do {
                simulatePipelineState = try device.makeComputePipelineState(function: function)
            } catch {
                fatalError("Failed to make simutate pipeline state with error: \(error)")
            }
        }

        // renderPipelineState
        do {
            guard let vertexFunction = library.makeFunction(name: "particle_vertex") else {
                fatalError("Failed to make function particle_vertex.")
            }
            guard let fragmentFunction = library.makeFunction(name: "particle_fragment") else {
                fatalError("Failed to make function particle_fragment.")
            }

            let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineStateDescriptor.label = "draw_particles"
            renderPipelineStateDescriptor.sampleCount = view.sampleCount
            renderPipelineStateDescriptor.vertexFunction = vertexFunction
            renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
            renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            renderPipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
            renderPipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
            renderPipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
            renderPipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            renderPipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            renderPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            do {
                renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
            } catch {
                fatalError("Failed to make render pipeline state with error: \(error)")
            }
        }

        // --- Buffers

        // particleBuffers
        do {
            let length: Int = MemoryLayout<particle_t>.size * Renderer.maxNumberOfParticles
            var buffers: [MTLBuffer] = []
            for i in 0..<Renderer.maxInFlightRenderingBuffers {
                guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
                    fatalError("Failed make particle buffer(\(i)).")
                }
                buffer.label = "simulated_particle_buffer_\(i + 1)"
                buffers.append(buffer)
            }
            self.particleBuffers = buffers
        }
    }

    // MARK: - MTKViewDelegate

    private func simulate(in view: MTKView, commandBuffer: MTLCommandBuffer) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder(), numberOfParticles > 0 else {
            return
        }
        computeEncoder.label = "Simulation"

        let dispatchThreads = MTLSize(width: numberOfParticles, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: simulatePipelineState.threadExecutionWidth, height: 1, depth: 1)

        computeEncoder.setComputePipelineState(simulatePipelineState)
        computeEncoder.setBuffer(particleBuffers[currentBufferIndex], offset: 0, index: 0)
        computeEncoder.setBuffer(particleBuffers[simulatedBufferIndex], offset: 0, index: 1)
        computeEncoder.setBytes(&viewportSize, length: MemoryLayout<vector_float2>.size, index: 2)
        computeEncoder.setThreadgroupMemoryLength(simulatePipelineState.threadExecutionWidth * MemoryLayout<particle_t>.size, index: 0)
        computeEncoder.dispatchThreads(dispatchThreads, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }

    private func render(in view: MTKView, commandBuffer: MTLCommandBuffer) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        renderEncoder.label = "Particle Rendering"

        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(particleBuffers[simulatedBufferIndex], offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_float2>.size, index: 1)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: numberOfParticles)
        renderEncoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
    }

    func draw(in view: MTKView) {
        guard numberOfParticles > 0 else {
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
            simulate(in: view, commandBuffer: commandBuffer)
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
            render(in: view, commandBuffer: commandBuffer)
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
    }
}
