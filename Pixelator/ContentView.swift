//
//  ContentView.swift
//  Pixelator
//
//  Created by Evan Rinehart on 8/28/26.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var palette: [Color] = [
        Color(red: 0.0, green: 0.0, blue: 0.0),
        Color(red: 0.25, green: 0.25, blue: 0.25),
        Color(red: 0.5, green: 0.5, blue: 0.5),
        Color(red: 0.75, green: 0.75, blue: 0.75),
        Color(red: 1.0, green: 1.0, blue: 1.0),
    ]
    @State private var newColor: Color = .green
    @State private var blockCount: Double = 30.0
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var pixelatedImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
            } else {
                Text("No photo selected")
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: 250)
            }

            if let pixelatedImage {
                Image(uiImage: pixelatedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
            } else {
                Text("Tap Pixelate to preview")
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: 250)
            }

            VStack {
                Text("Block Count: \(Int(blockCount))")
                Slider(value: $blockCount, in: 10...150, step: 1)
            }

            List {
                Section("Palette") {
                    ForEach(palette.indices, id: \.self) { i in
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(palette[i])
                                .frame(width: 44, height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                )
                            Text("Color \(i + 1)")
                            Spacer()
                            ColorPicker("", selection: $palette[i])
                                .labelsHidden()
                        }
                    }
                    .onDelete { palette.remove(atOffsets: $0) }
                }
            }
            .frame(height: 180)

            HStack {
                ColorPicker("New color", selection: $newColor)
                Button {
                    palette.append(newColor)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }

            HStack {
                Button("Pixelate with Palette") {
                    runPixelation()
                }
                .buttonStyle(.borderedProminent)

                Button("Pixelate") {
                    runStandardPixelation()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage.normalizedOrientation()
                    pixelatedImage = nil
                }
            }
        }
    }

    private func runPixelation() {
        guard let sourceCGImage = selectedImage?.cgImage,
              let buffer = pixelBuffer(from: sourceCGImage) else {
            print("No image selected or failed to buffer it")
            return
        }
        let pixelator = MetalPixelator()
        let result = pixelator?.pixelate(cgImage: sourceCGImage, blockSize: 40, palette: palette)
        //let result = pixelateFromPalette(buffer, blockCount: blockCount, palette: palette)
        guard let resultCGImage = result else {
            print("Failed to convert pixel buffer back to CGImage")
            return
        }
        pixelatedImage = UIImage(cgImage: resultCGImage)
    }

    private func runStandardPixelation() {
        guard let sourceCGImage = selectedImage?.cgImage,
              let buffer = pixelBuffer(from: sourceCGImage) else {
            print("No image selected or failed to buffer it")
            return
        }
        let result = pixelate(buffer, blockCount: blockCount)
        guard let resultCGImage = cgImage(from: result) else {
            print("Failed to convert pixel buffer back to CGImage")
            return
        }
        pixelatedImage = UIImage(cgImage: resultCGImage)
    }
}

#Preview {
    ContentView()
}
