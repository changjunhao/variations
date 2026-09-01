//
//  ArtifactsStore.swift
//  Variations
//
//  结果图/缩略图文件存储：Application Support/Variations/{results,thumbs}。
//

import Foundation

enum ArtifactsStore {

    enum Kind: String {
        case results
        case thumbs
    }

    static let rootURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Variations", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    /// 落盘并返回相对路径（DB 存储值）
    @discardableResult
    static func save(data: Data, kind: Kind, name: String = UUID().uuidString, ext: String = "jpg") throws -> String {
        let dir = rootURL.appendingPathComponent(kind.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let rel = "\(kind.rawValue)/\(name).\(ext)"
        try data.write(to: rootURL.appendingPathComponent(rel), options: .atomic)
        return rel
    }

    static func url(relative: String) -> URL {
        rootURL.appendingPathComponent(relative)
    }

    /// 删除单个产物文件（nil 安全；文件不存在静默）
    static func remove(relative: String?) {
        guard let relative else { return }
        try? FileManager.default.removeItem(at: url(relative: relative))
    }

    // 注意：产物是用户内容（变奏集），不提供整体清除；清空语义走记录删除流（逐条连带 remove）
}
