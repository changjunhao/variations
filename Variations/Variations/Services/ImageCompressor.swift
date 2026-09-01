//
//  ImageCompressor.swift
//  Variations
//
//  上传前压缩：ImageIO 下采样（长边≤2048）、JPEG 0.85、EXIF 摆正。
//  nonisolated async → 跑全局并发执行器，不占主线程（工程默认 MainActor 隔离）。
//

import ImageIO
import UIKit

nonisolated enum ImageCompressor {

    static let maxPixelSize: CGFloat = 2048
    static let jpegQuality: CGFloat = 0.85

    /// 压缩结果：JPEG 数据 + 像素尺寸（供 UI 展示大小）
    struct Output: Sendable {
        let data: Data
        let pixelWidth: Int
        let pixelHeight: Int
    }

    nonisolated static func compress(
        data: Data,
        maxPixelSize: CGFloat = ImageCompressor.maxPixelSize,
        quality: CGFloat = ImageCompressor.jpegQuality
    ) async throws -> Output {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // EXIF 摆正
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            throw AppError.invalidImage
        }
        let image = UIImage(cgImage: cgImage)
        guard let jpeg = image.jpegData(compressionQuality: quality) else {
            throw AppError.invalidImage
        }
        return Output(data: jpeg, pixelWidth: cgImage.width, pixelHeight: cgImage.height)
    }
}
