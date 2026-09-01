//
//  OSSUploader.swift
//  Variations
//
//  OSS 预签名直传：PUT 必须带 ticket.contentType（已绑签名）；
//  失败按后端约定「重取 ticket 重传」×2，不做分片续传。
//

import Foundation

enum OSSUploader {

    /// 上传成功返回最终使用的 ticket（fileUrl 即后续 imageUrl）
    nonisolated static func upload(
        jpeg: Data,
        ticket: UploadTicket,
        session: URLSession = .shared,
        progress: @MainActor @escaping (Double) -> Void,
        refetchTicket: @Sendable () async throws -> UploadTicket
    ) async throws -> UploadTicket {
        var current = ticket
        var lastStatus = 0
        for attempt in 0...2 {
            if attempt > 0 {
                current = try await refetchTicket()
            }
            guard let url = URL(string: current.uploadUrl) else { throw AppError.uploadFailed(status: 0) }
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(current.contentType, forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = APIClient.requestTimeout

            let delegate = ProgressDelegate(progress: progress)
            do {
                let (_, response) = try await session.upload(for: request, from: jpeg, delegate: delegate)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    await progress(1)
                    return current
                }
                lastStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            } catch {
                lastStatus = 0
            }
        }
        throw AppError.uploadFailed(status: lastStatus)
    }
}

/// 上传进度 delegate：URLSession 队列回调 →  hop 回 MainActor
final class ProgressDelegate: NSObject, URLSessionTaskDelegate {
    private let progress: @MainActor (Double) -> Void

    init(progress: @escaping @MainActor (Double) -> Void) {
        self.progress = progress
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend totalExpected: Int64
    ) {
        guard totalExpected > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalExpected)
        let callback = progress
        Task { @MainActor in callback(fraction) }
    }
}
