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
    uint2 gid [[thread_position_in_grid]])
{
    uint width = inTexture.get_width();
    uint height = inTexture.get_height();
    if (gid.x >= width || gid.y >= height) return;

    // Snap this thread's pixel to its block's origin
    uint2 blockOrigin = uint2((gid.x / blockSize) * blockSize,
                               (gid.y / blockSize) * blockSize);

    // Average the block (every thread in the block redundantly computes this —
    // simple and fast enough for typical block sizes; see note below for optimizing)
    float4 sum = float4(0);
    uint count = 0;
    for (uint y = 0; y < blockSize; y++) {
        for (uint x = 0; x < blockSize; x++) {
            uint2 coord = blockOrigin + uint2(x, y);
            if (coord.x < width && coord.y < height) {
                sum += inTexture.read(coord);
                count++;
            }
        }
    }
    float4 avg = sum / float(count);

    // Snap to nearest palette color, if a palette was provided
    float4 finalColor = avg;
    if (paletteCount > 0) {
        float bestDist = INFINITY;
        for (uint i = 0; i < paletteCount; i++) {
            float3 diff = avg.rgb - palette[i].rgb;
            float dist = dot(diff, diff);
            if (dist < bestDist) {
                bestDist = dist;
                finalColor = float4(palette[i].rgb, avg.a);
            }
        }
    }

    outTexture.write(finalColor, gid);
}
