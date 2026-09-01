//
//  UploadTests.swift
//  VariationsTests
//
//  ImageCompressor 下采样/坏图路径；OSSUploader 直传/重试路径。
//

import UIKit
import XCTest
@testable import Variations

final class ImageCompressorTests: XCTestCase {

    private func bigImagePNG(side: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side * 0.75), format: format)
        let data = renderer.pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side * 0.75))
        }
        return data
    }

    func testDownsampleLongEdgeTo2048() async throws {
        let png = bigImagePNG(side: 4000)
        let output = try await ImageCompressor.compress(data: png)
        XCTAssertEqual(output.pixelWidth, 2048)
        XCTAssertEqual(output.pixelHeight, 1536)
        // JPEG 魔数 FF D8
        XCTAssertEqual(output.data[0], 0xFF)
        XCTAssertEqual(output.data[1], 0xD8)
    }

    func testSmallImageKeepsSize() async throws {
        let png = bigImagePNG(side: 800)
        let output = try await ImageCompressor.compress(data: png)
        XCTAssertEqual(output.pixelWidth, 800)
        XCTAssertEqual(output.pixelHeight, 600)
    }

    func testInvalidDataThrows() async {
        do {
            _ = try await ImageCompressor.compress(data: Data("not an image".utf8))
            XCTFail("should throw")
        } catch let error as AppError {
            guard case .invalidImage = error else { return XCTFail("wrong case") }
        } catch {
            XCTFail("wrong error")
        }
    }
}

final class OSSUploaderTests: XCTestCase {

    /// refetch 计数器：refetchTicket 为 @Sendable 并发闭包，捕获可变局部变量会告警，用锁保护
    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func increment() {
            lock.lock(); defer { lock.unlock() }
            count += 1
        }

        var value: Int {
            lock.lock(); defer { lock.unlock() }
            return count
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func ticket(_ n: Int) -> UploadTicket {
        UploadTicket(
            uploadUrl: "https://oss.example.com/put/\(n)",
            fileUrl: "https://oss.example.com/get/\(n)",
            contentType: "image/jpeg",
            expiresAt: "2026-08-16T12:00:00Z"
        )
    }

    func testUploadSuccessSendsContentType() async throws {
        StubURLProtocol.reset { _ in .init(status: 200, data: Data()) }
        let result = try await OSSUploader.upload(
            jpeg: Data([0xFF, 0xD8]),
            ticket: ticket(1),
            session: makeSession(),
            progress: { _ in }
        ) { throw AppError.notConfigured }
        XCTAssertEqual(result.fileUrl, "https://oss.example.com/get/1")
        let request = StubURLProtocol.recorded[0]
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
    }

    func testUpload403RefetchesTicketAndRetries() async throws {
        let calls = CallCounter()
        StubURLProtocol.reset { request in
            request.url!.path.contains("put/1")
                ? .init(status: 403, data: Data())
                : .init(status: 200, data: Data())
        }
        let result = try await OSSUploader.upload(
            jpeg: Data([0xFF, 0xD8]),
            ticket: ticket(1),
            session: makeSession(),
            progress: { _ in }
        ) {
            calls.increment()
            return self.ticket(2)
        }
        XCTAssertEqual(calls.value, 1)
        XCTAssertEqual(result.fileUrl, "https://oss.example.com/get/2")
        XCTAssertEqual(StubURLProtocol.recorded.count, 2)
    }

    func testUploadAlwaysFailingThrows() async {
        StubURLProtocol.reset { _ in .init(status: 500, data: Data()) }
        do {
            _ = try await OSSUploader.upload(
                jpeg: Data([0xFF, 0xD8]),
                ticket: ticket(1),
                session: makeSession(),
                progress: { _ in }
            ) { self.ticket(2) }
            XCTFail("should throw")
        } catch let error as AppError {
            guard case .uploadFailed(let status) = error else { return XCTFail("wrong case") }
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("wrong error")
        }
    }
}
