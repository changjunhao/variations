//
//  DTOTests.swift
//  VariationsTests
//
//  四接口 DTO 解码单测：样本 JSON 与 variations-serve-go/internal/handlers/ 响应 DTO 对齐。
//

import XCTest
@testable import Variations

final class DTOTests: XCTestCase {

    func testDecodeSkills() throws {
        let json = """
        [{"id":"scene-distillation-zine","name":"scene-distillation-zine",
          "description":"把照片蒸馏成场景志","displayName":"油画变奏",
          "shortDescription":"厚涂笔触 · 古典光影","defaultPrompt":"将照片转化为一幅古典油画",
          "sampleImageUrl":"https://oss.example.com/samples/a.jpg","sampleImageAspect":1.6667,"size":"960*1600"}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([SkillCard].self, from: json)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].displayName, "油画变奏")
        XCTAssertEqual(cards[0].sampleImageUrl, "https://oss.example.com/samples/a.jpg")
        XCTAssertEqual(cards[0].sampleImageAspect, 1.6667)
        XCTAssertEqual(cards[0].size, "960*1600")
    }

    func testDecodeSkillsNullableSample() throws {
        // 无 size 键（旧缓存/未设画幅）应解码为 nil，保持向后兼容
        let json = """
        [{"id":"x","name":"x","description":"","displayName":"","shortDescription":"","defaultPrompt":"","sampleImageUrl":null}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([SkillCard].self, from: json)
        XCTAssertNil(cards[0].sampleImageUrl)
        XCTAssertNil(cards[0].sampleImageAspect)
        XCTAssertNil(cards[0].size)
        XCTAssertNil(cards[0].instructionTemplate)
    }

    func testDecodeSkillsInstructionTemplate() throws {
        // 结构化附加指令模板：枚举标签带 options，自由标签带 placeholder
        let json = """
        [{"id":"photo-relic-editorial","name":"photo-relic-editorial","description":"","displayName":"拾影",
          "shortDescription":"","defaultPrompt":"","sampleImageUrl":null,"size":"x2",
          "instructionTemplate":[{"label":"标题语言","options":["英文","中文","无字"]},
                                 {"label":"标题文字","placeholder":"留空则自动起题"}]}]
        """.data(using: .utf8)!
        let cards = try JSONDecoder().decode([SkillCard].self, from: json)
        let template = try XCTUnwrap(cards[0].instructionTemplate)
        XCTAssertEqual(template.count, 2)
        XCTAssertEqual(template[0].label, "标题语言")
        XCTAssertEqual(template[0].options, ["英文", "中文", "无字"])
        XCTAssertNil(template[0].placeholder)
        XCTAssertEqual(template[1].label, "标题文字")
        XCTAssertEqual(template[1].placeholder, "留空则自动起题")
        XCTAssertNil(template[1].options)
    }

    func testDecodeUploadTicket() throws {
        let json = """
        {"uploadUrl":"https://bucket.oss-cn-hangzhou.aliyuncs.com/in/a.jpg?sign=1",
         "fileUrl":"https://bucket.oss-cn-hangzhou.aliyuncs.com/in/a.jpg?sign=2",
         "contentType":"image/jpeg",
         "expiresAt":"2026-08-16T12:00:00.000Z"}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(UploadTicket.self, from: json)
        XCTAssertEqual(ticket.contentType, "image/jpeg")
    }

    func testDecodeCompileAndImage() throws {
        let compile = try JSONDecoder().decode(CompileResult.self, from: #"{"prompt":"p"}"#.data(using: .utf8)!)
        XCTAssertEqual(compile.prompt, "p")
        let image = try JSONDecoder().decode(ImageResult.self, from: #"{"urls":["u1","u2"]}"#.data(using: .utf8)!)
        XCTAssertEqual(image.urls, ["u1", "u2"])
    }

    func testDecodeFileTicket() throws {
        let json = """
        {"fileUrl":"https://bucket.oss-cn-hangzhou.aliyuncs.com/uploads/a.jpg?sign=3",
         "expiresAt":"2026-08-16T12:00:00.000Z"}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(FileTicket.self, from: json)
        XCTAssertEqual(ticket.fileUrl, "https://bucket.oss-cn-hangzhou.aliyuncs.com/uploads/a.jpg?sign=3")
    }

    func testSourceRefParse() {
        let hash = String(repeating: "a", count: 64)
        // 标准预签名 URL（带 query）→ 解析出 hash/ext
        let ref = SourceRef.parse("https://bucket.oss-cn-hangzhou.aliyuncs.com/uploads/\(hash).jpg?x-oss-signature=1")
        XCTAssertEqual(ref?.hash, hash)
        XCTAssertEqual(ref?.ext, "jpg")
        // 其余白名单扩展名
        XCTAssertEqual(SourceRef.parse("https://b.o.com/uploads/\(hash).webp")?.ext, "webp")
        // 非法形态：大写哈希 / 非法扩展名 / 非 uploads 对象键 / 非法 URL
        XCTAssertNil(SourceRef.parse("https://b.o.com/uploads/\(hash.uppercased()).jpg"))
        XCTAssertNil(SourceRef.parse("https://b.o.com/uploads/\(hash).gif"))
        XCTAssertNil(SourceRef.parse("https://b.o.com/samples/a.jpg"))
        XCTAssertNil(SourceRef.parse("not a url"))
    }

    /// 410 SOURCE_FILE_GONE → sourceFileGone（「不可变奏」文案，不得降级文生图）
    func testAppErrorSourceFileGone() {
        let error = AppError(status: 410, body: APIErrorBody(code: "SOURCE_FILE_GONE", message: "源图已超过 48 小时保留期被清理"))
        guard case .sourceFileGone = error else { return XCTFail("410 应映射 sourceFileGone") }
        XCTAssertTrue(error.localizedDescription.contains("不可变奏"))
    }

    func testDecodeErrorBody() throws {
        let body = try JSONDecoder().decode(APIErrorBody.self, from: #"{"code":"BAD_REQUEST","message":"prompt 必填"}"#.data(using: .utf8)!)
        XCTAssertEqual(body.code, "BAD_REQUEST")
    }

    func testSizeOptionApiValues() {
        XCTAssertEqual(SizeOption.square.apiValue, "1280*1280")
        XCTAssertEqual(SizeOption.portrait.apiValue, "1152*1536")
        XCTAssertEqual(SizeOption.wide.apiValue, "896*1600")
    }

    func testServerURLValidation() {
        XCTAssertTrue(ServerURLValidator.isValid("https://api.example.com"))
        XCTAssertTrue(ServerURLValidator.isValid("http://localhost:8787"))
        XCTAssertTrue(ServerURLValidator.isValid("http://127.0.0.1:8787"))
        // 真机局域网联调：私有网段 / .local
        XCTAssertTrue(ServerURLValidator.isValid("http://192.168.1.10:8787"))
        XCTAssertTrue(ServerURLValidator.isValid("http://10.0.0.5:8787"))
        XCTAssertTrue(ServerURLValidator.isValid("http://172.20.1.1:8787"))
        XCTAssertTrue(ServerURLValidator.isValid("http://ifable-mac.local:8787"))
        // 公网 http 仍拒绝
        XCTAssertFalse(ServerURLValidator.isValid("http://8.8.8.8:8787"))
        XCTAssertFalse(ServerURLValidator.isValid("http://example.com"))
        XCTAssertFalse(ServerURLValidator.isValid("ftp://x.com"))
        XCTAssertFalse(ServerURLValidator.isValid("not a url"))
    }

    /// DeviceAuth 凭据存取与 deviceId 生成（内存 store 注入）
    func testDeviceAuthCredentialRoundtrip() async throws {
        let store = InMemoryCredentialStore()
        let auth = DeviceAuth(store: store)
        let deviceIDBefore = await auth.currentDeviceID()
        XCTAssertNil(deviceIDBefore, "未注册时应无 deviceId")
        // 注册写入的 deviceId 可原样读回
        try store.write("test-device-id", key: DeviceAuth.deviceIDKey)
        let deviceIDAfter = await auth.currentDeviceID()
        XCTAssertEqual(deviceIDAfter, "test-device-id")
    }
}
