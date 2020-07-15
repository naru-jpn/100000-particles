//
//  Functions.metal
//  particles
//
//  Created by Naruki Chigira on 2020/07/16.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// MARK: Simulation

constant float PHASE_INTERVAL = 0.05f;

/// Simulate particles.
kernel void
simulate(device particle_t* currentParticles [[ buffer(0) ]],
         device particle_t* newParticles [[ buffer(1) ]],
         constant vector_uint2 *viewportSize [[ buffer(2) ]],
         const uint gid [[ thread_position_in_grid ]])
{
    float2 position = currentParticles[gid].position;
    float2 velocity = currentParticles[gid].velocity;
    float4 color = currentParticles[gid].color;
    float phase = currentParticles[gid].phase;
    float end = (vector_float2(*viewportSize) / 2.0).y;

    position.x += sin(phase);
    if (position.y < -end) {
        position.y = end;
    }

    newParticles[gid].color = color;
    newParticles[gid].position = position + velocity;
    newParticles[gid].velocity = velocity;
    newParticles[gid].phase = phase + PHASE_INTERVAL;
}

// MARK: Rendering

constant float PARTICLE_SIZE = 5.0f;

struct Point {
    float4 position [[position]];
    float size [[point_size]];
    float4 color;
};

/// Vertex function to draw particles.
vertex Point
particle_vertex(const device particle_t* particles [[ buffer(0) ]],
                constant vector_uint2 *viewportSizePointer [[ buffer(1) ]],
                unsigned int vid [[ vertex_id ]])
{
    Point out;
    out.position = vector_float4(0.0f, 0.0f, 0.0f, 1.0f);
    out.position.xy = particles[vid].position / (vector_float2(*viewportSizePointer) / 2.0f);
    out.size = PARTICLE_SIZE;
    out.color = particles[vid].color;
    return out;
}

/// Fragment function to draw particles.
fragment float4
particle_fragment(Point in [[stage_in]])
{
    return in.color;
};
