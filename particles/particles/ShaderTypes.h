//
//  ShaderTypes.h
//  particles
//
//  Created by Naruki Chigira on 2020/07/16.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct {
    vector_float4 color;
    vector_float2 position;
    vector_float2 velocity;
    float phase;
} particle_t;

#endif /* ShaderTypes_h */
