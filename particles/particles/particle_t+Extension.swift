//
//  ShaderTypes+Extension.swift
//  particles
//
//  Created by Naruki Chigira on 2020/07/18.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

import Foundation

extension particle_t {
    static func create(with setting: Setting, viewportSize: vector_uint2) -> particle_t {
        func createColor() -> vector_float4 {
            switch setting.coloring {
            case .colorful:
                switch arc4random_uniform(4) {
                case 0:
                    return vector_float4(1.0, 0.0, 0.0, 1.0)
                case 1:
                    return vector_float4(1.0, 0.6, 0.2, 1.0)
                case 2:
                    return vector_float4(0.0, 0.0, 1.0, 1.0)
                case 3:
                    return vector_float4(1.0, 0.0, 1.0, 1.0)
                default:
                    return vector_float4(0.0, 0.0, 0.0, 0.0)
                }
            case .monochrome:
                switch arc4random_uniform(4) {
                case 0:
                    return vector_float4(1.0, 1.0, 1.0, 0.2)
                case 1:
                    return vector_float4(1.0, 1.0, 1.0, 0.4)
                case 2:
                    return vector_float4(1.0, 1.0, 1.0, 0.6)
                case 3:
                    return vector_float4(1.0, 1.0, 1.0, 0.8)
                default:
                    return vector_float4(0.0, 0.0, 0.0, 0.0)
                }
            }
        }
        let rangex = Range<Float>(uncheckedBounds: (lower: Float(-(Int(viewportSize.x) / 2)), upper: Float(Int(viewportSize.x) / 2)))
        let rangey = Range<Float>(uncheckedBounds: (lower: Float(-(Int(viewportSize.y) / 2)), upper: Float(Int(viewportSize.y) / 2)))
        return particle_t(
            color: createColor(),
            position: vector_float2(Float.random(in: rangex), Float.random(in: rangey)),
            velocity: vector_float2(0, Float.random(in: -10...(-1))),
            phase: Float.random(in: -Float.pi...Float.pi)
        )
    }
}
