import AVFoundation
import BeckifyMath
import CoreText
import Foundation
import UIKit
import UniformTypeIdentifiers

// Crew Talk pixel animations and shareable clips.
// Sprite sheets are pre-made (ios/Art/CrewTalk/build_sprites.py) and live in the asset catalog.
// Nothing is generated per request except the video that stitches those frames to the spoken line.

/// Loads a crew member's sheet once and hands out individual frames.
final class CrewSpriteLibrary {
    static let shared = CrewSpriteLibrary()

    struct Sheet {
        let spec: CrewSpriteSheetSpec
        let frames: [CGImage]
        func frame(_ index: Int) -> CGImage? {
            frames.indices.contains(index) ? frames[index] : frames.first
        }
    }

    private var sheets: [CrewTalkMember: Sheet] = [:]
    private let lock = NSLock()

    func sheet(for crew: CrewTalkMember) -> Sheet? {
        lock.lock(); defer { lock.unlock() }
        if let cached = sheets[crew] { return cached }
        let name = crew.spriteSheetAssetName
        guard
            let data = NSDataAsset(name: crew.spriteTimingAssetName)?.data,
            let spec = try? CrewSpriteSheetSpec.decode(data),
            spec.isConsistent,
            let image = UIImage(named: name)?.cgImage
        else { return nil }
        // Asset catalog may hand back @1x pixels; compute the real cell size from the bitmap.
        let scale = max(1, image.width / max(spec.columns * spec.frameSize, 1))
        let cell = spec.frameSize * scale
        let frames: [CGImage] = (0..<spec.frameCount).compactMap { i in
            let o = spec.origin(ofFrame: i)
            return image.cropping(to: CGRect(x: o.x * scale, y: o.y * scale, width: cell, height: cell))
        }
        guard frames.count == spec.frameCount else { return nil }
        let sheet = Sheet(spec: spec, frames: frames)
        sheets[crew] = sheet
        return sheet
    }
}

enum CrewTalkClipError: LocalizedError {
    case noSprites, noAudio, noLine, writerFailed(String)
    var errorDescription: String? {
        switch self {
        case .noSprites: return "This character has no clip animation yet."
        case .noAudio: return "Couldn’t get this character’s voice for the clip. Check your connection and try again."
        case .noLine: return "Translate a line first, then make a clip."
        case .writerFailed(let detail): return "Couldn’t make the clip (\(detail)). Try again."
        }
    }
}

/// Builds a square H.264/AAC .mp4: pixel character talking for exactly the length of the spoken line,
/// the line as a caption, and the same voice recording. Cached per character + line + recording.
actor CrewTalkClipBuilder {
    static let shared = CrewTalkClipBuilder()

    static let side = 720
    private static let navy = UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1)
    private static let grid = UIColor(red: 0.25, green: 0.88, blue: 1.0, alpha: 0.07)
    private static let cyan = UIColor(red: 0.25, green: 0.88, blue: 1.0, alpha: 1)

    private var folder: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrewTalkClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Renders (or reuses) the clip. `progress` gets frames written / total, off the main thread.
    /// Cancelling the calling Task cancels the render and removes the partial file.
    func clip(
        crew: CrewTalkMember,
        line: String,
        audioURL: URL,
        progress: @escaping @Sendable (CrewClipProgress) -> Void = { _ in }
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: audioURL.path) else { throw CrewTalkClipError.noAudio }
        let key = CrewClipKey.make(crew: crew, line: line, audioFileName: audioURL.lastPathComponent)
        let out = folder.appendingPathComponent("\(crew.firstName)-\(key).mp4")
        if FileManager.default.fileExists(atPath: out.path) {
            progress(CrewClipProgress(framesDone: 1, totalFrames: 1))
            return out
        }
        return try await Self.render(crew: crew, line: line, audioURL: audioURL, to: out, progress: progress)
    }

    // MARK: Render

    /// Nonisolated + static: runs on the cooperative pool, never on the main actor.
    private static func render(
        crew: CrewTalkMember, line: String, audioURL: URL, to out: URL,
        progress: @escaping @Sendable (CrewClipProgress) -> Void
    ) async throws -> URL {
        guard let sheet = CrewSpriteLibrary.shared.sheet(for: crew) else { throw CrewTalkClipError.noSprites }
        let audio = AVURLAsset(url: audioURL)
        guard let audioTrack = try await audio.loadTracks(withMediaType: .audio).first else { throw CrewTalkClipError.noAudio }
        let audioSeconds = try await audio.load(.duration).seconds
        guard audioSeconds.isFinite, audioSeconds > 0 else { throw CrewTalkClipError.noAudio }
        let timeline = CrewClipTimeline(audioDuration: audioSeconds)

        let tmp = out.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try? FileManager.default.removeItem(at: out)

        let writer = try AVAssetWriter(outputURL: tmp, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: side,
            AVVideoHeightKey: side,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 900_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: CrewClipTimeline.framesPerSecond * 2,
            ],
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: side,
            kCVPixelBufferHeightKey as String: side,
        ])
        var mono = AudioChannelLayout()
        mono.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44_100,
            AVEncoderBitRateKey: 96_000,
            AVChannelLayoutKey: Data(bytes: &mono, count: MemoryLayout<AudioChannelLayout>.size),
        ])
        audioInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else { throw CrewTalkClipError.writerFailed("inputs") }
        writer.add(videoInput)
        writer.add(audioInput)

        // Decode to 44.1 kHz mono PCM so the AAC encoder never has to guess the source layout
        // (ElevenLabs MP3 and Apple-voice exports differ).
        let reader = try AVAssetReader(asset: audio)
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        readerOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(readerOutput) else { throw CrewTalkClipError.writerFailed("reader") }
        reader.add(readerOutput)

        guard reader.startReading() else {
            throw CrewTalkClipError.writerFailed(reader.error?.localizedDescription ?? "reader start")
        }
        guard writer.startWriting() else {
            reader.cancelReading()
            throw CrewTalkClipError.writerFailed(writer.error?.localizedDescription ?? "start")
        }
        writer.startSession(atSourceTime: .zero)

        let backdrop = makeBackdrop(crew: crew, line: line)
        let fps = Int32(CrewClipTimeline.framesPerSecond)
        let total = timeline.frameCount
        let offset = CMTime(seconds: timeline.audioStart, preferredTimescale: 44_100)

        // Root-cause fix: interleave. The old code appended every video frame first; the writer
        // stops accepting video once it's ~1 s ahead of audio, so the loop waited forever.
        var frameIndex = 0
        var audioDone = false
        var audioTime = 0.0
        var lastReported = -1
        do {
            loop: while true {
                try Task.checkCancellation()
                if writer.status == .failed {
                    throw CrewTalkClipError.writerFailed(writer.error?.localizedDescription ?? "writer")
                }
                let step = CrewClipMux.next(
                    videoRemaining: frameIndex < total, videoReady: videoInput.isReadyForMoreMediaData,
                    videoTime: timeline.time(ofFrame: frameIndex),
                    audioRemaining: !audioDone, audioReady: audioInput.isReadyForMoreMediaData,
                    audioTime: audioTime
                )
                switch step {
                case .finish:
                    break loop
                case .wait:
                    try await Task.sleep(nanoseconds: 2_000_000)
                case .video:
                    guard let pool = adaptor.pixelBufferPool else { throw CrewTalkClipError.writerFailed("pool") }
                    var buffer: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
                    guard let buffer else { throw CrewTalkClipError.writerFailed("buffer") }
                    let t = timeline.time(ofFrame: frameIndex)
                    draw(into: buffer, backdrop: backdrop, sprite: sheet.frame(timeline.frame(at: t, spec: sheet.spec)))
                    guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: fps)) else {
                        throw CrewTalkClipError.writerFailed(writer.error?.localizedDescription ?? "append video")
                    }
                    frameIndex += 1
                    if frameIndex == total { videoInput.markAsFinished() }
                    if frameIndex - lastReported >= 3 || frameIndex == total {
                        lastReported = frameIndex
                        progress(CrewClipProgress(framesDone: frameIndex, totalFrames: total))
                    }
                case .audio:
                    guard let sample = readerOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            throw CrewTalkClipError.writerFailed(reader.error?.localizedDescription ?? "read audio")
                        }
                        audioDone = true
                        audioInput.markAsFinished()
                        continue
                    }
                    var timing = CMSampleTimingInfo()
                    CMSampleBufferGetSampleTimingInfo(sample, at: 0, timingInfoOut: &timing)
                    timing.presentationTimeStamp = CMTimeAdd(timing.presentationTimeStamp, offset)
                    timing.decodeTimeStamp = .invalid
                    var shifted: CMSampleBuffer?
                    CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample, sampleTimingEntryCount: 1,
                                                          sampleTimingArray: &timing, sampleBufferOut: &shifted)
                    guard let shifted else { throw CrewTalkClipError.writerFailed("audio timing") }
                    guard audioInput.append(shifted) else {
                        throw CrewTalkClipError.writerFailed(writer.error?.localizedDescription ?? "append audio")
                    }
                    let end = CMTimeAdd(timing.presentationTimeStamp, CMSampleBufferGetDuration(shifted))
                    audioTime = end.isNumeric ? end.seconds : audioTime + 0.02
                }
            }
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }

        writer.endSession(atSourceTime: CMTime(seconds: timeline.totalDuration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw CrewTalkClipError.writerFailed(writer.error?.localizedDescription ?? "finish")
        }
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.moveItem(at: tmp, to: out)
        return out
    }

    /// Static layers drawn once: navy field, faint cyan grid, name plate, caption.
    private static func makeBackdrop(crew: CrewTalkMember, line: String) -> CGImage? {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            navy.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            grid.setFill()
            for x in stride(from: 0, to: side, by: 24) { ctx.fill(CGRect(x: x, y: 0, width: 1, height: side)) }
            for y in stride(from: 0, to: side, by: 24) { ctx.fill(CGRect(x: 0, y: y, width: side, height: 1)) }
            let plate = NSAttributedString(string: crew.firstName.uppercased(), attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 30, weight: .heavy),
                .foregroundColor: cyan,
                .kern: 3,
            ])
            plate.draw(at: CGPoint(x: 32, y: 26))
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineBreakMode = .byWordWrapping
            var fontSize: CGFloat = 34
            let box = CGRect(x: 36, y: 520, width: CGFloat(side) - 72, height: 168)
            var caption = NSAttributedString()
            repeat {
                caption = NSAttributedString(string: line, attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: para,
                ])
                fontSize -= 2
            } while caption.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
                                         options: .usesLineFragmentOrigin, context: nil).height > box.height && fontSize > 16
            UIColor.black.withAlphaComponent(0.35).setFill()
            UIBezierPath(roundedRect: box.insetBy(dx: -14, dy: -10), cornerRadius: 18).fill()
            caption.draw(with: box, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        }
        return image.cgImage
    }

    /// Composite backdrop + one sprite frame (nearest-neighbor, 5x) into the video buffer.
    private static func draw(into buffer: CVPixelBuffer, backdrop: CGImage?, sprite: CGImage?) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }
        let full = CGRect(x: 0, y: 0, width: side, height: side)
        if let backdrop { ctx.draw(backdrop, in: full) }
        guard let sprite else { return }
        ctx.interpolationQuality = .none
        // 96 px cell × 5 = 480. Sits above the caption (CG origin is bottom-left).
        let s: CGFloat = 480
        ctx.draw(sprite, in: CGRect(x: (CGFloat(side) - s) / 2, y: CGFloat(side) - 30 - s, width: s, height: s))
    }

    // MARK: Pasteboard

    @MainActor
    static func copyToPasteboard(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw CrewTalkClipError.writerFailed("empty file") }
        UIPasteboard.general.setItems([[UTType.mpeg4Movie.identifier: data]])
    }
}
