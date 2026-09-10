//
//  ImageLoader.swift
//  Pixelator
//
//  Created by Evan Rinehart on 8/28/26.
//

import SwiftUI
import UIKit

struct PixelBuffer {
    var pixels: [UInt8] // RGBA8, row-major
    let width: Int
    let height: Int
    let bytesPerRow: Int
}

func pixelBuffer(from cgImage: CGImage) -> PixelBuffer? {
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8

    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue // RGBA

    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return PixelBuffer(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
}

func printPixel(_ buffer: PixelBuffer, x: Int, y: Int) {
    let idx = y * buffer.bytesPerRow + x * 4
    let r = buffer.pixels[idx]
    let g = buffer.pixels[idx + 1]
    let b = buffer.pixels[idx + 2]
    let a = buffer.pixels[idx + 3]
    print("Pixel (\(x), \(y)): R=\(r) G=\(g) B=\(b) A=\(a)")
}

func pixelateFromPalette(_ buffer: PixelBuffer, blockSize: Int, palette: [Color]? = nil) -> PixelBuffer {
    var output = buffer.pixels
    let bpp = 4
    let rgbPalette = palette?.map { $0.toRGBColor() }

    var y = 0
    while y < buffer.height {
        var x = 0
        while x < buffer.width {
            let blockW = min(blockSize, buffer.width - x)
            let blockH = min(blockSize, buffer.height - y)

            var sums = [Int](repeating: 0, count: 4)
            var count = 0
            for by in 0..<blockH {
                for bx in 0..<blockW {
                    let idx = (y + by) * buffer.bytesPerRow + (x + bx) * bpp
                    for c in 0..<4 { sums[c] += Int(buffer.pixels[idx + c]) }
                    count += 1
                }
            }

            let avgR = sums[0] / count
            let avgG = sums[1] / count
            let avgB = sums[2] / count
            let avgA = UInt8(sums[3] / count)

            let finalColor: RGBColor
            if let rgbPalette = rgbPalette, !rgbPalette.isEmpty {
                finalColor = closestColor(to: (avgR, avgG, avgB), in: rgbPalette)
            } else {
                finalColor = RGBColor(r: UInt8(avgR), g: UInt8(avgG), b: UInt8(avgB))
            }

            for by in 0..<blockH {
                for bx in 0..<blockW {
                    let idx = (y + by) * buffer.bytesPerRow + (x + bx) * bpp
                    output[idx] = finalColor.r
                    output[idx + 1] = finalColor.g
                    output[idx + 2] = finalColor.b
                    output[idx + 3] = avgA
                }
            }
            x += blockSize
        }
        y += blockSize
    }

    return PixelBuffer(pixels: output, width: buffer.width, height: buffer.height, bytesPerRow: buffer.bytesPerRow)
}

func pixelate(_ buffer: PixelBuffer, blockSize: Int) -> PixelBuffer {
    var output = buffer.pixels
    let bpp = 4

    var y = 0
    while y < buffer.height {
        var x = 0
        while x < buffer.width {
            let blockW = min(blockSize, buffer.width - x)
            let blockH = min(blockSize, buffer.height - y)

            // Average the block
            var sums = [Int](repeating: 0, count: 4)
            var count = 0
            for by in 0..<blockH {
                for bx in 0..<blockW {
                    let idx = (y + by) * buffer.bytesPerRow + (x + bx) * bpp
                    for c in 0..<4 { sums[c] += Int(buffer.pixels[idx + c]) }
                    count += 1
                }
            }
            let avg = sums.map { UInt8($0 / count) }

            // Write the average back to every pixel in the block
            for by in 0..<blockH {
                for bx in 0..<blockW {
                    let idx = (y + by) * buffer.bytesPerRow + (x + bx) * bpp
                    for c in 0..<4 { output[idx + c] = avg[c] }
                }
            }
            x += blockSize
        }
        y += blockSize
    }

    return PixelBuffer(pixels: output, width: buffer.width, height: buffer.height, bytesPerRow: buffer.bytesPerRow)
}

func cgImage(from buffer: PixelBuffer) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let providerRef = CGDataProvider(data: Data(buffer.pixels) as CFData) else { return nil }

    return CGImage(
        width: buffer.width,
        height: buffer.height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: buffer.bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
        provider: providerRef,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

extension UIImage {
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
