import Foundation
import ImageIO
@testable import FamilyRoutine
import Testing
import UIKit
import UniformTypeIdentifiers

struct ProfilePhotoNormalizerTests {
    private let normalizer = ProfilePhotoNormalizer()

    @Test("SPEC-002 CA-10 resizes images above 1600 px preserving aspect ratio and re-encodes as JPEG")
    func resizesLargeImages() async throws {
        let output = try await normalizer.normalize(try makeJPEG(width: 3200, height: 1600))

        let size = try pixelSize(of: output)
        #expect(size.width == 1600)
        #expect(size.height == 800)
        #expect(output.count <= ProfilePhotoNormalizer.maxBytes)
        #expect(try imageType(of: output) == UTType.jpeg.identifier)
    }

    @Test("SPEC-002 CA-10 keeps small images at their size")
    func keepsSmallImages() async throws {
        let output = try await normalizer.normalize(try makeJPEG(width: 200, height: 100))

        let size = try pixelSize(of: output)
        #expect(size.width == 200)
        #expect(size.height == 100)
    }

    @Test("SPEC-002 CA-10 accepts other decodable formats such as PNG")
    func convertsPNGToJPEG() async throws {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }

        let output = try await normalizer.normalize(png)

        #expect(try imageType(of: output) == UTType.jpeg.identifier)
    }

    @Test("SPEC-002 CA-10 strips EXIF and GPS metadata")
    func stripsMetadata() async throws {
        let source = try makeJPEG(width: 100, height: 100, withMetadata: true)
        let sourceProperties = try properties(of: source)
        #expect(sourceProperties[kCGImagePropertyGPSDictionary] != nil)

        let output = try await normalizer.normalize(source)

        let outputProperties = try properties(of: output)
        #expect(outputProperties[kCGImagePropertyGPSDictionary] == nil)
        let exif = outputProperties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
    }

    @Test("SPEC-002 CA-10 rejects data that is not an image")
    func rejectsInvalidData() async {
        await #expect(throws: ProfilePhotoError.unreadableImage) {
            try await normalizer.normalize(Data("not an image".utf8))
        }
    }

    private func makeJPEG(width: Int, height: Int, withMetadata: Bool = false) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard withMetadata, let cgImage = image.cgImage else {
            return try #require(image.jpegData(compressionQuality: 0.9))
        }

        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let metadata: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 10.5,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 20.5,
                kCGImagePropertyGPSLongitudeRef: "E",
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private"],
        ]
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let values = try properties(of: data)
        return (
            try #require(values[kCGImagePropertyPixelWidth] as? Int),
            try #require(values[kCGImagePropertyPixelHeight] as? Int)
        )
    }

    private func imageType(of data: Data) throws -> String? {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return CGImageSourceGetType(source) as String?
    }
}
