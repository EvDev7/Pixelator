//
//  ContentView.swift
//  Pixelator
//
//  Created by Evan Rinehart on 8/28/26.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var palette: [Color] = [
        Color(red: 0.0, green: 0.0, blue: 0.0),
        Color(red: 0.2, green: 0.2, blue: 0.2),
        Color(red: 0.4, green: 0.4, blue: 0.4),
        Color(red: 0.6, green: 0.6, blue: 0.6),
        Color(red: 0.8, green: 0.8, blue: 0.8),
        Color(red: 1.0, green: 1.0, blue: 1.0),
    ]
    @State private var newColor: Color = .green
    @State private var blockCount: Double = 30.0
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var pixelatedImage: UIImage?
    @State private var fullScreenTarget: FullScreenTarget?

    var body: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
            
            imagePreviews
            
            if let pixelatedImage {
                ShareLink(
                    item: PixelatedImage(image: pixelatedImage),
                    preview: SharePreview("Pixelated image", image: Image(uiImage: pixelatedImage))
                ) {
                    Label("Share / Save", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
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
                    runPixelation(usePalette: true)
                }
                .buttonStyle(.borderedProminent)

                Button("Pixelate") {
                    runPixelation(usePalette: false)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .fullScreenCover(item: $fullScreenTarget) { target in
            switch target {
            case .original:
                if let selectedImage {
                    FullScreenImageView(image: selectedImage, isPixelated: false)
                }
            case .pixelated:
                if let pixelatedImage {
                    FullScreenImageView(image: pixelatedImage, isPixelated: true)
                }
            }
        }
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
    
    private var isPortrait: Bool {
        guard let size = selectedImage?.size else { return false }
        return size.height > size.width
    }

    private var imagePreviews: some View {
        let layout = isPortrait
            ? AnyLayout(HStackLayout(spacing: 12))
            : AnyLayout(VStackLayout(spacing: 12))
        return layout {
            previewImage(selectedImage, placeholder: "No photo selected")
                .onTapGesture {
                    if selectedImage != nil { fullScreenTarget = .original }
                }
            previewImage(pixelatedImage, placeholder: "Tap Pixelate to preview")
                .onTapGesture {
                    if pixelatedImage != nil { fullScreenTarget = .pixelated }
                }
        }
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage?, placeholder: String) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 250)
        } else {
            Text(placeholder)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: 250)
        }
    }
    
    private func runPixelation(usePalette: Bool) {
        guard let sourceCGImage = selectedImage?.cgImage else {
            print("No image selected or failed to buffer it")
            return
        }
        guard let pixelator = MetalPixelator.shared,
              let resultCGImage = pixelator.pixelate(
                cgImage: sourceCGImage,
                blockCount: blockCount,
                palette: usePalette ? palette : nil
              ) else {
            print("Pixelation failed")
            return
        }
        pixelatedImage = UIImage(cgImage: resultCGImage)
    }
}

enum FullScreenTarget: Identifiable {
    case original, pixelated
    var id: Self { self }
}

// Tells ShareLink how to export the image: always as PNG, so block edges stay sharp.
struct PixelatedImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    let isPixelated: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .interpolation(isPixelated ? .none : .high)   // crisp blocks for pixelated, smooth for the original photo
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = max(1, lastScale * value.magnification)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale <= 1 { resetZoom() }
                        }
                        .simultaneously(with:
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                )
                .onTapGesture(count: 2) {
                    withAnimation { resetZoom() }
                }

            HStack {
                Button("Done") { dismiss() }
                Spacer()
                if isPixelated {
                    ShareLink(
                        item: PixelatedImage(image: image),
                        preview: SharePreview("Pixelated image", image: Image(uiImage: image))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .padding()
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
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

#Preview {
    ContentView()
}
