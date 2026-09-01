//
//  Navigation.swift
//  Variations
//
//  路由：NavigationStack value-based，Route → 各流程视图。
//

import SwiftUI

enum Route: Hashable {
    /// 官方模版流程（选图→编译→编辑）
    case officialFlow(SkillCard)
    /// 用户 SKILL 模版流程（inlineSkill 编译）
    case userFlow(UserSkillTemplate)
    /// 直接输入提示词
    case direct
    /// 新建用户 SKILL 模版
    case newSkill
    /// 编辑用户 SKILL 模版
    case editSkill(UserSkillTemplate)
    /// 谱写变奏（生成中）→ 结果舞台
    case composing(FlowState)
    /// 结果舞台
    case result(VariationRecord)
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .officialFlow(let skill):
            TemplateFlowView(flow: FlowState(kind: .official(skill)))
        case .userFlow(let template):
            TemplateFlowView(flow: FlowState(kind: .userTemplate(name: template.name, body: template.body)))
        case .direct:
            DirectPromptView()
        case .newSkill:
            SkillEditorView()
        case .editSkill(let template):
            SkillEditorView(template: template)
        case .composing(let flow):
            ComposingView(flow: flow)
        case .result(let record):
            ResultView(record: record)
        }
    }
}
