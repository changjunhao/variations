//
//  ImagePipelineBootstrap.swift
//  Variations
//
//  Nuke 共享管线：命名 DataCache 磁盘缓存 200MB，接入设置页「清除缓存」。
//  内存缓存显式封顶：iPad 多窗口下两套网格同时驻留缩略图，靠默认值容易推高内存峰值。
//

import Foundation
import Nuke

enum ImagePipelineBootstrap {

    static let dataCacheName = "com.variations.nuke"
    static let dataCacheSizeLimit = 200 * 1024 * 1024

    /// 内存缓存上限：物理内存 8% 与 96MB 取小。
    /// 多窗口时缓存是进程级共享的，上限按“整个 App”而非“单个窗口”拟定
    static var memoryCacheCostLimit: Int {
        let byShare = Int(Double(ProcessInfo.processInfo.physicalMemory) * 0.08)
        return min(byShare, 96 * 1024 * 1024)
    }

    static func configure() {
        ImageCache.shared.costLimit = memoryCacheCostLimit

        ImagePipeline.shared = ImagePipeline {
            if let cache = try? DataCache(name: dataCacheName) {
                cache.sizeLimit = dataCacheSizeLimit
                $0.dataCache = cache
            }
            $0.isStoringPreviewsInMemoryCache = true
        }
    }

    /// 设置页「清除缓存」调用
    static func clearDiskCache() {
        ImagePipeline.shared.configuration.dataCache?.removeAll()
        ImagePipeline.shared.cache.removeAll()
    }
}
