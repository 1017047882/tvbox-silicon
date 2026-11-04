import SwiftUI
#if os(iOS)
import UIKit
#endif

/// @brief Version gates for presentation and decoration. On iOS 15 sheets keep their standard size.
enum TVDetent: Hashable { case medium, large }
enum TVScrollVisibility: Equatable { case hidden, visible, automatic, never }
enum TVKeyboardDismissal: Equatable { case interactively, immediately, never }
enum TVBar: Equatable { case navigationBar, tabBar }
enum TVMargin { case scrollContent }
enum TVScrollTarget { case paging }

private struct TVChange<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: @MainActor (Value, Value) -> Void
    @State private var previous: Value
    @State private var appeared = false
    init(value: Value, initial: Bool, action: @escaping @MainActor (Value, Value) -> Void) {
        self.value = value; self.initial = initial; self.action = action
        _previous = State(initialValue: value)
    }
    func body(content: Content) -> some View {
        content.onAppear {
            guard !appeared else { return }
            appeared = true
            previous = value
            if initial { action(value, value) }
        }.onChange(of: value) { next in
            let old = previous
            previous = next
            action(old, next)
        }
    }
}

extension View {
    @ViewBuilder func tvToolbarColorScheme(_ scheme: ColorScheme?, for bar: TVBar) -> some View {
        #if os(iOS) || os(tvOS)
        if #available(iOS 16, tvOS 16, *) {
            if bar == .navigationBar { toolbarColorScheme(scheme, for: .navigationBar) }
            else { toolbarColorScheme(scheme, for: .tabBar) }
        } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvListRowSpacing(_ spacing: CGFloat) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { listRowSpacing(spacing) } else { self }
    }
    /// @brief Keeps artwork visible on iOS 15; parallax requires iOS 17.
    @ViewBuilder func tvPosterParallax() -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) {
            visualEffect { view, proxy in
                view.offset(y: min(0, -proxy.frame(in: .scrollView).minY * 0.16))
            }
        } else { self }
    }
    @ViewBuilder func tvOnPointerMove(_ action: @escaping () -> Void) -> some View {
        #if !os(tvOS)
        if #available(iOS 16, macOS 13, *) { onContinuousHover { _ in action() } } else { onHover { _ in action() } }
        #else
        self
        #endif
    }
    @ViewBuilder func tvLargeControl() -> some View {
        if #available(iOS 17, tvOS 17, *) { controlSize(.large) } else { controlSize(.regular) }
    }
    @ViewBuilder func tvCircleButtonBorder() -> some View {
        if #available(iOS 17, tvOS 17, *) { buttonBorderShape(.circle) } else { buttonBorderShape(.capsule) }
    }
    @ViewBuilder func tvLineLimit(_ limit: Int, reservesSpace: Bool) -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) { lineLimit(limit, reservesSpace: reservesSpace) } else { lineLimit(limit) }
    }
    @ViewBuilder func tvGroupedForm() -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) { formStyle(.grouped) } else { self }
    }
    @ViewBuilder func tvScrollContentBackground(_ visibility: Visibility) -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) { scrollContentBackground(visibility) } else { self }
    }
    @ViewBuilder func tvContentMargins(_ edges: Edge.Set, _ length: CGFloat, for placement: TVMargin) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { contentMargins(edges, length, for: .scrollContent) } else { padding(edges, length) }
    }
    @ViewBuilder func tvScrollTargetLayout() -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { scrollTargetLayout() } else { self }
    }
    @ViewBuilder func tvScrollTargetBehavior(_ behavior: TVScrollTarget) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { scrollTargetBehavior(.paging) } else { self }
    }
    @ViewBuilder func tvScrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { scrollPosition(id: id, anchor: anchor) } else {
            ScrollViewReader { proxy in
                self.onAppear { if let target = id.wrappedValue { proxy.scrollTo(target, anchor: anchor) } }
                    .onChange(of: id.wrappedValue) { target in if let target { proxy.scrollTo(target, anchor: anchor) } }
            }
        }
    }
    @ViewBuilder func tvContainerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center,
                                               _ length: @escaping (CGFloat, Axis) -> CGFloat) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { containerRelativeFrame(axes, alignment: alignment, length) } else {
            #if os(iOS)
            frame(minWidth: axes.contains(.horizontal) ? length(UIScreen.main.bounds.width, .horizontal) : nil,
                  minHeight: axes.contains(.vertical) ? length(UIScreen.main.bounds.height, .vertical) : nil, alignment: alignment)
            #else
            self
            #endif
        }
    }
    /// @brief Geometry updates using APIs available on iOS 15.
    func tvOnGeometryChange<Value: Equatable>(for type: Value.Type, of transform: @escaping (GeometryProxy) -> Value,
                                              action: @escaping (Value) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                let value = transform(proxy)
                Color.clear.onAppear { action(value) }.onChange(of: value) { action($0) }
            }
        }
    }
    func tvOnChange<Value: Equatable>(of value: Value, initial: Bool = false, _ action: @escaping @MainActor (Value, Value) -> Void) -> some View {
        modifier(TVChange(value: value, initial: initial, action: action))
    }
    func tvOnChange<Value: Equatable>(of value: Value, initial: Bool = false, _ action: @escaping @MainActor () -> Void) -> some View {
        tvOnChange(of: value, initial: initial) { _, _ in action() }
    }
    func tvOnChange<Value: Equatable>(of value: Value, initial: Bool = false, _ action: @escaping @MainActor (Value) -> Void) -> some View {
        tvOnChange(of: value, initial: initial) { _, next in action(next) }
    }
    @ViewBuilder func tvScrollIndicators(_ visibility: TVScrollVisibility) -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) {
            scrollIndicators(visibility == .never ? .never : visibility == .hidden ? .hidden : visibility == .visible ? .visible : .automatic)
        } else { self }
    }
    @ViewBuilder func tvScrollDismissesKeyboard(_ mode: TVKeyboardDismissal) -> some View {
        #if os(iOS)
        if #available(iOS 16, *) {
            scrollDismissesKeyboard(mode == .interactively ? .interactively : mode == .immediately ? .immediately : .never)
        } else {
            simultaneousGesture(DragGesture().onChanged { _ in
                if mode != .never { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            })
        }
        #else
        self
        #endif
    }
    @ViewBuilder func tvScrollClipDisabled(_ disabled: Bool = true) -> some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) { scrollClipDisabled(disabled) } else { self }
    }
    @ViewBuilder func tvToolbar(_ visibility: Visibility, for bar: TVBar) -> some View {
        #if os(iOS)
        if #available(iOS 16, *) {
            if bar == .navigationBar { toolbar(visibility, for: .navigationBar) } else { toolbar(visibility, for: .tabBar) }
        } else if bar == .navigationBar { navigationBarHidden(visibility == .hidden) } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvToolbarBackground(_ visibility: Visibility, for bar: TVBar) -> some View {
        #if os(iOS)
        if #available(iOS 16, *) {
            if bar == .navigationBar { toolbarBackground(visibility, for: .navigationBar) } else { toolbarBackground(visibility, for: .tabBar) }
        } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvPresentationDetents(_ detents: Set<TVDetent>) -> some View {
        #if os(iOS)
        if #available(iOS 16, *) { presentationDetents(Set(detents.map { $0 == .medium ? PresentationDetent.medium : .large })) } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvPresentationDragIndicator(_ visibility: Visibility) -> some View {
        #if os(iOS)
        if #available(iOS 16, *) { presentationDragIndicator(visibility) } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvPresentationCornerRadius(_ radius: CGFloat?) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) { presentationCornerRadius(radius) } else { self }
        #else
        self
        #endif
    }
    @ViewBuilder func tvPresentationBackground<Style: ShapeStyle>(_ style: Style) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) { presentationBackground(style) } else { background(style) }
        #else
        background(style)
        #endif
    }
    @ViewBuilder func tvPresentationBackground<Background: View>(@ViewBuilder content: () -> Background) -> some View {
        #if os(iOS)
        if #available(iOS 16.4, *) { presentationBackground(content: content) } else { background(content: content) }
        #else
        background(content: content)
        #endif
    }
}

extension Color {
    /// @brief A vertical tint gradient without the iOS 16 AnyGradient type.
    var tvGradient: LinearGradient {
        LinearGradient(colors: [opacity(0.8), self], startPoint: .top, endPoint: .bottom)
    }
}

extension ButtonBorderShape {
    static func tvRoundedRectangle(radius: CGFloat) -> Self {
        if #available(iOS 17, macOS 14, tvOS 17, *) { return .roundedRectangle(radius: radius) }
        return .roundedRectangle
    }
}

extension ControlSize {
    var tvIsLarge: Bool {
        if #available(iOS 17, tvOS 17, *) { return self == .large }
        return false
    }
}

extension Button where Label == SwiftUI.Label<Text, Image> {
    /// @brief The title-and-symbol initializer without its iOS 17 requirement.
    init(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { SwiftUI.Label(title, systemImage: systemImage) }
    }
}

extension Animation {
    static var tvSmooth: Animation { tvSmooth() }
    static func tvSmooth(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        if #available(iOS 17, macOS 14, tvOS 17, *) { return .smooth(duration: duration, extraBounce: extraBounce) }
        return .easeInOut(duration: duration)
    }
    static var tvSnappy: Animation { tvSnappy() }
    static func tvSnappy(duration: Double = 0.5, extraBounce: Double = 0) -> Animation {
        if #available(iOS 17, macOS 14, tvOS 17, *) { return .snappy(duration: duration, extraBounce: extraBounce) }
        return .spring(response: duration, dampingFraction: 0.85)
    }
    static func tvSpring(duration: Double = 0.5, bounce: Double = 0, blendDuration: Double = 0) -> Animation {
        if #available(iOS 17, macOS 14, tvOS 17, *) { return .spring(duration: duration, bounce: bounce, blendDuration: blendDuration) }
        return .spring(response: duration, dampingFraction: max(0.1, 1 - bounce), blendDuration: blendDuration)
    }
}
