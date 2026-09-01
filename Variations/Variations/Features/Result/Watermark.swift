//
//  Watermark.swift
//  Variations
//
//  导出水印：仅导出/分享时烧入右下角「Variation No.X」标签，预览不烧。
//

import UIKit

enum Watermark {

    nonisolated static func burn(_ image: UIImage, label: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)

            let fontSize = max(20, image.size.width * 0.028)
            let font = UIFont.italicSystemFont(ofSize: fontSize)
            let text = label as NSString
            let textSize = text.size(withAttributes: [.font: font])
            let padding = fontSize * 0.5
            let inset = fontSize * 0.9

            let rect = CGRect(
                x: image.size.width - textSize.width - padding * 2 - inset,
                y: image.size.height - textSize.height - padding * 2 - inset,
                width: textSize.width + padding * 2,
                height: textSize.height + padding * 2
            )
            let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.3)
            UIColor(white: 0.98, alpha: 0.85).setFill()
            path.fill()

            text.draw(
                at: CGPoint(x: rect.minX + padding, y: rect.minY + padding),
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor(white: 0.15, alpha: 1),
                ]
            )
        }
    }
}
