//
//  Router.swift
//  Variations
//
//  编程式导航：每个 Tab 栈一个 Router（[Route] 栈，支持替换栈顶）。
//

import SwiftUI

@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    /// 替换栈顶（谱写变奏 → 结果舞台，避免返回到生成中页）
    func replaceLast(_ route: Route) {
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
    }

    func popToRoot() {
        path.removeAll()
    }
}
