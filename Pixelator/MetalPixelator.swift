//
//  MetalPixelator.swift
//  Pixelator
//
//  Created by Evan Rinehart on 9/9/26.
//

import Metal
import MetalKit
import CoreImage
import SwiftUI

final class MetalPixelator {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    private let ciContext: CIContext   // reused across calls (creating one is expensive)

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "pixelatePalette") else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
        }
    }

    func pixelate(cgImage: CGImage, blockCount: Double, palette: [Color]) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        let shorterSide = min(width, height)
        // Clamp so blockCount < 1 or > shorterSide can't cause divide-by-zero / blockSize == 0
        let blockSize = max(1, shorterSide / max(1, Int(blockCount)))
        let rgbPalette = palette.map { $0.toRGBColor() }

        let textureLoader = MTKTextureLoader(device: device)
        guard let inTexture = try? textureLoader.newTexture(cgImage: cgImage, options: [
            .SRGB: false
        ]) else { return nil }

        let outDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false)
        outDescriptor.usage = [.shaderWrite, .shaderRead]
        guard let outTexture = device.makeTexture(descriptor: outDescriptor) else { return nil }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inTexture, index: 0)
        encoder.setTexture(outTexture, index: 1)

        var blockSizeU32 = UInt32(blockSize)
        encoder.setBytes(&blockSizeU32, length: MemoryLayout<UInt32>.size, index: 0)

        // Convert palette to float4 array (normalize UInt8 0-255 -> 0.0-1.0)
        var paletteFloats: [SIMD4<Float>] = rgbPalette.map {
            SIMD4<Float>(Float($0.r) / 255.0, Float($0.g) / 255.0, Float($0.b) / 255.0, 1.0)
        }
        var paletteCount = UInt32(paletteFloats.count)
        if paletteFloats.isEmpty {
            paletteFloats = [SIMD4<Float>(0, 0, 0, 0)] // dummy, buffer can't be zero-length
        }
        encoder.setBytes(&paletteFloats, length: MemoryLayout<SIMD4<Float>>.stride * paletteFloats.count, index: 1)
        encoder.setBytes(&paletteCount, length: MemoryLayout<UInt32>.size, index: 2)

        // One thread per BLOCK (not per pixel). The kernel averages its block,
        // snaps to the palette once, then fills the block in the output.
        let blocksX = (width + blockSize - 1) / blockSize
        let blocksY = (height + blockSize - 1) / blockSize

        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupCount = MTLSize(
            width: (blocksX + 15) / 16,
            height: (blocksY + 15) / 16,
            depth: 1)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return makeCGImage(from: outTexture)
    }

    private func makeCGImage(from texture: MTLTexture) -> CGImage? {
        let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpaceCreateDeviceRGB()])
        guard let ciImage = ciImage else { return nil }
        // Metal textures are flipped vertically relative to CGImage — correct orientation
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        return ciContext.createCGImage(flipped, from: flipped.extent)
    }
}
