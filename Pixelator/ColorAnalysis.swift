//
//  ColorAnalysis.swift
//  Pixelator
//
//  Created by Evan Rinehart on 8/28/26.
//

import SwiftUI

struct RGBColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

func distanceSquared(_ a: RGBColor, _ b: (r: Int, g: Int, b: Int)) -> Int {
    let dr = Int(a.r) - b.r
    let dg = Int(a.g) - b.g
    let db = Int(a.b) - b.b
    return dr * dr + dg * dg + db * db
}

func closestColor(to avg: (r: Int, g: Int, b: Int), in palette: [RGBColor]) -> RGBColor {
    var best = palette[0]
    var bestDist = distanceSquared(best, avg)

    for color in palette.dropFirst() {
        let dist = distanceSquared(color, avg)
        if dist < bestDist {
            best = color
            bestDist = dist
        }
    }
    return best
}

extension Color {
    func toRGBColor() -> RGBColor {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBColor(r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
    }
}
