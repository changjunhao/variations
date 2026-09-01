//
//  ImagePipelineBootstrap.swift
//  Variations
//
//  Nuke 共享管线：命名 DataCache 磁盘缓存 200MB，接入设置页「清除缓存」。
//

import Nuke

enum ImagePipelineBootstrap {

    static let dataCacheName = "com.variations.nuke"
    static let dataCacheSizeLimit = 200 * 1024 * 1024

    static func configure() {
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
