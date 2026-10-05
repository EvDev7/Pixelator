//
//  Pixelate.metal
//  Pixelator
//
//  Created by Evan Rinehart on 9/9/26.
//

#include <metal_stdlib>
using namespace metal;

kernel void pixelatePalette(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant uint &blockSize [[buffer(0)]],
    constant float4 *palette [[buffer(1)]],
    constant uint &paletteCount [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]])   // grid = one thread per block
{
    uint width = inTexture.get_width();
    uint height = inTexture.get_height();
    uint2 origin = gid * blockSize;
    if (origin.x >= width || origin.y >= height) return;

    uint2 end = min(origin + blockSize, uint2(width, height));

    float4 sum = float4(0);
    for (uint y = origin.y; y < end.y; y++)
        for (uint x = origin.x; x < end.x; x++)
            sum += inTexture.read(uint2(x, y));
    float4 avg = sum / float((end.x - origin.x) * (end.y - origin.y));

    float4 color = avg;
    if (paletteCount > 0) {
        float best = INFINITY;
        for (uint i = 0; i < paletteCount; i++) {
            float3 d = avg.rgb - palette[i].rgb;
            float dist = dot(d, d);
            if (dist < best) { best = dist; color = float4(palette[i].rgb, avg.a); }
        }
    }

    for (uint y = origin.y; y < end.y; y++)
        for (uint x = origin.x; x < end.x; x++)
            outTexture.write(color, uint2(x, y));
}
