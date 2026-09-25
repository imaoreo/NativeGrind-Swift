//
//  loginWithQR.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 17/07/2026.
//

import SwiftUI
import NativeGrindCore
import CoreImage.CIFilterBuiltins

struct loginWithQRView: View {
    
    @State private var code: String? = nil

    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }
    
    private var textSize: Font.TextStyle {
        #if os(tvOS)
            return .title3
        #else
            return .title
        #endif
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Please scan the QR Code below")
                    .font(.system(textSize, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Inside NativeGrind, or your camera app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            if let activeCode = code, !activeCode.isEmpty {
                let qrImage = generateQRCode(from: "nativegrind:/login?code=\(activeCode)")
                
                Image(platformImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                
                Text(activeCode)
                    .font(.title2.monospaced())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            } else {
                ProgressView()
                    .frame(width: 200, height: 200)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: containerWidth, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                await getQRCode()
                
                // 80 seconds
                try? await Task.sleep(nanoseconds: 80_000_000_000)
            }
        }
    }
    
    private func getQRCode() async {
        let response = await wsController.shared.sendAndWait(request: .generateLinkCode(), expectedEvent: .onCodeLinkGenerated)
        if (response?.code == nil) {
            errorManager.shared.error("Login With QR", response?.message ?? "Time Out")
        } else {
            code = response?.code
        }
    }
    
    private func generateQRCode(from string: String) -> PlatformImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                #if canImport(UIKit)
                    return UIImage(cgImage: cgimg)
                #elseif canImport(AppKit)
                    return NSImage(cgImage: cgimg, size: outputImage.extent.size)
                #endif
            }
        }
        
        #if canImport(UIKit)
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        #elseif canImport(AppKit)
            return NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) ?? NSImage()
        #endif
    }
}

#Preview {
    loginWithQRView()
}
