import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ProfilePhotoError: Error, Equatable {
    case unreadableImage
    case tooLarge
}

nonisolated struct ProfilePhotoNormalizer: ProfilePhotoNormalizing {
    static let maxDimension = 1600
    static let maxBytes = 5_242_880

    func normalize(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try Self.normalizeSynchronously(data)
        }.value
    }

    private static func normalizeSynchronously(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ProfilePhotoError.unreadableImage
        }
        // Thumbnail creation applies EXIF orientation and drops source metadata (EXIF/GPS).
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProfilePhotoError.unreadableImage
        }

        for quality in [0.85, 0.7, 0.5, 0.3] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output, UTType.jpeg.identifier as CFString, 1, nil
            ) else {
                throw ProfilePhotoError.unreadableImage
            }
            CGImageDestinationAddImage(
                destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination) else {
                throw ProfilePhotoError.unreadableImage
            }
            if output.length <= maxBytes {
                return output as Data
            }
        }
        throw ProfilePhotoError.tooLarge
    }
}
