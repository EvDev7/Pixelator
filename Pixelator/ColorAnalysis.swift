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

extension Color {
    func toRGBColor() -> RGBColor {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBColor(r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
    }
}
