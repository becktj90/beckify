import Accelerate
import CoreImage
import UIKit
import Vision

/// On-device preprocess before Vision OCR. Perspective-flattens a strong
/// page rectangle when one exists, then lifts faded ink and compresses
/// glare. A missing rectangle is a no-op on the crop — contrast still runs.
///
/// `CIAdaptiveThreshold` is not a public Core Image filter. Local contrast
/// uses `CIHighlightShadowAdjust`, `CIColorControls`, `CIDocumentEnhancer`
/// when the OS provides it, and a vImage local-mean stretch.
enum ImageSanitizer {
    struct Result {
        var cgImage: CGImage
        var orientation: CGImagePropertyOrientation
        /// True when a document rectangle was perspective-corrected.
        var didFlatten: Bool
    }

    /// Safe to call off the main thread. No shared context.
    static func sanitize(_ image: UIImage) -> Result? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = cgImageOrientation(from: image.imageOrientation)
        var working = CIImage(cgImage: cgImage).oriented(forExifOrientation: Int32(orientation.rawValue))
        var didFlatten = false

        if let quad = detectRectangle(cgImage: cgImage, orientation: orientation),
           isActionable(quad),
           let corrected = perspectiveCorrect(working, observation: quad) {
            working = corrected
            didFlatten = true
        }

        working = enhance(working)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        working = adaptiveContrast(working, context: context) ?? working

        let extent = working.extent.integral
        guard extent.width > 1, extent.height > 1,
              let rendered = context.createCGImage(working, from: extent) else {
            return Result(cgImage: cgImage, orientation: orientation, didFlatten: false)
        }
        return Result(cgImage: rendered, orientation: .up, didFlatten: didFlatten)
    }

    // MARK: - Rectangle

    private static func detectRectangle(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1
        request.minimumSize = 0.18
        request.maximumObservations = 4
        request.minimumConfidence = 0.55
        request.quadratureTolerance = 30
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let rects = (request.results as? [VNRectangleObservation]) ?? []
        return rects
            .filter { observation in
                let area = observation.boundingBox.width * observation.boundingBox.height
                return area > 0.12 && area < 0.995 && observation.confidence >= 0.55
            }
            .max { lhs, rhs in
                let left = lhs.boundingBox.width * lhs.boundingBox.height
                let right = rhs.boundingBox.width * rhs.boundingBox.height
                return left < right
            }
    }

    /// A strong quad is either inset from the frame (a page inside the photo)
    /// or skewed enough that its corners leave the bounding box.
    private static func isActionable(_ observation: VNRectangleObservation) -> Bool {
        let box = observation.boundingBox
        let area = box.width * box.height
        guard area > 0.15, area < 0.995, observation.confidence >= 0.6 else { return false }
        let corners = [
            observation.topLeft,
            observation.topRight,
            observation.bottomRight,
            observation.bottomLeft,
        ]
        let ideal = [
            CGPoint(x: box.minX, y: box.maxY),
            CGPoint(x: box.maxX, y: box.maxY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.minX, y: box.minY),
        ]
        let deviation = zip(corners, ideal).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
        return area < 0.92 || deviation > 0.02
    }

    private static func perspectiveCorrect(_ image: CIImage, observation: VNRectangleObservation) -> CIImage? {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return nil }
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(
                x: extent.minX + point.x * extent.width,
                y: extent.minY + point.y * extent.height
            )
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector(observation.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(observation.topRight), forKey: "inputTopRight")
        filter.setValue(vector(observation.bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(vector(observation.bottomRight), forKey: "inputBottomRight")
        guard let output = filter.outputImage, output.extent.width > 8, output.extent.height > 8 else {
            return nil
        }
        return output
    }

    // MARK: - Contrast / glare

    private static func enhance(_ input: CIImage) -> CIImage {
        let finite = input.extent.integral
        guard finite.width > 1, finite.height > 1 else { return input }
        var image = input.cropped(to: finite)
        func apply(_ name: String, _ configure: (CIFilter) -> Void) {
            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(image, forKey: kCIInputImageKey)
            configure(filter)
            if let output = filter.outputImage {
                image = output.cropped(to: finite)
            }
        }
        apply("CIHighlightShadowAdjust") { filter in
            filter.setValue(0.7, forKey: "inputHighlightAmount")
            filter.setValue(0.4, forKey: "inputShadowAmount")
        }
        apply("CIColorControls") { filter in
            filter.setValue(1.28, forKey: kCIInputContrastKey)
            filter.setValue(0.02, forKey: kCIInputSaturationKey)
            filter.setValue(0.03, forKey: kCIInputBrightnessKey)
        }
        apply("CIDocumentEnhancer") { filter in
            filter.setValue(1.4, forKey: "inputAmount")
        }
        apply("CISharpenLuminance") { filter in
            filter.setValue(0.3, forKey: kCIInputSharpnessKey)
        }
        return image
    }

    /// Local-mean stretch. Dark ink on a bright, uneven page gets darker
    /// relative to its neighborhood; specular wash stays near white.
    private static func adaptiveContrast(_ image: CIImage, context: CIContext) -> CIImage? {
        let extent = image.extent.integral
        guard extent.width > 32, extent.height > 32 else { return nil }
        let maxDimension: CGFloat = 1800
        let scale = min(1, maxDimension / max(extent.width, extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let bounds = scaled.extent.integral
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        guard width > 32, height > 32 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 255, count: width * height)
        pixels.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            context.render(
                scaled,
                toBitmap: base,
                rowBytes: width,
                bounds: bounds,
                format: .L8,
                colorSpace: colorSpace
            )
        }

        var blurred = pixels
        let kernel: UInt32 = 31
        let convolveError: vImage_Error = pixels.withUnsafeMutableBytes { sourceRaw in
            blurred.withUnsafeMutableBytes { destRaw in
                var source = vImage_Buffer(
                    data: sourceRaw.baseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width
                )
                var dest = vImage_Buffer(
                    data: destRaw.baseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width
                )
                return vImageBoxConvolve_Planar8(
                    &source,
                    &dest,
                    nil,
                    0,
                    0,
                    kernel,
                    kernel,
                    0,
                    vImage_Flags(kvImageEdgeExtend)
                )
            }
        }
        guard convolveError == kvImageNoError else { return nil }

        for index in 0..<pixels.count {
            let local = Int(blurred[index])
            let pixel = Int(pixels[index])
            let stretched = local + (pixel - local) * 2
            pixels[index] = UInt8(clamping: stretched)
        }
        let mean = pixels.reduce(0) { $0 + Int($1) } / max(pixels.count, 1)
        // A failed bitmap render is a flat field. Keep the Core Image result.
        if mean < 8 || mean > 247 { return nil }

        let data = Data(pixels)
        let gray = CIImage(
            bitmapData: data,
            bytesPerRow: width,
            size: CGSize(width: width, height: height),
            format: .L8,
            colorSpace: colorSpace
        )
        let fitted = gray.transformed(by: CGAffineTransform(translationX: bounds.minX, y: bounds.minY))
        if scale < 0.999 {
            return fitted.transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
        }
        return fitted
    }

    static func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
