import SwiftUI
#if os(iOS)
import UIKit
#endif

enum TVSymbolEffect { case replace, bounce, variableColor; var iterative: Self { self } }
enum TVContentTransition {
    case opacity, number(Double), symbol
    static func numericText(value: Double = 0) -> Self { .number(value) }
    static func symbolEffect(_ effect: TVSymbolEffect) -> Self { .symbol }
}
enum TVImpactWeight: Equatable { case light, medium }
enum TVFeedback {
    case selection, impact(weight: TVImpactWeight)
    @MainActor func play() {
        #if os(iOS)
        switch self {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .impact(let weight): UIImpactFeedbackGenerator(style: weight == .light ? .light : .medium).impactOccurred()
        }
        #endif
    }
}

extension View {
    @ViewBuilder func tvContentTransition(_ transition: TVContentTransition) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) {
            switch transition {
            case .opacity: contentTransition(.opacity)
            case .number(let value): contentTransition(.numericText(value: value))
            case .symbol: contentTransition(.symbolEffect(.replace))
            }
        } else { self }
    }
    @ViewBuilder func tvSymbolEffect(_ effect: TVSymbolEffect, isActive: Bool = true) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) {
            symbolEffect(.variableColor.iterative, isActive: isActive)
        } else { self }
    }
    @ViewBuilder func tvSymbolEffect<Value: Equatable>(_ effect: TVSymbolEffect, value: Value) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { symbolEffect(.bounce, value: value) } else { self }
    }
    func tvSensoryFeedback<Value: Equatable>(trigger: Value, _ feedback: @escaping (Value, Value) -> TVFeedback?) -> some View {
        tvOnChange(of: trigger) { old, next in feedback(old, next)?.play() }
    }
    func tvSensoryFeedback<Value: Equatable>(_ feedback: TVFeedback, trigger: Value) -> some View {
        tvOnChange(of: trigger) { feedback.play() }
    }
}
