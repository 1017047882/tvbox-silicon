import SwiftUI
import TVCore
#if os(iOS)
import UIKit
#endif

struct TVActionLayout<Content: View>: View {
    let stacked: Bool
    @ViewBuilder var content: Content
    var body: some View {
        if stacked { VStack(spacing: 10) { content } }
        else { HStack(spacing: 12) { content } }
    }
}

/// @brief Keeps the empty-state explanation and actions available on iOS 15.
struct TVEmptyState: View {
    private let label: AnyView
    private let description: AnyView
    private let actions: AnyView
    init(_ title: String, systemImage: String, description: Text? = nil) {
        label = AnyView(Label(title, systemImage: systemImage))
        self.description = AnyView(description)
        actions = AnyView(EmptyView())
    }
    init<Label: View, Description: View, Actions: View>(
        @ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description, @ViewBuilder actions: () -> Actions
    ) {
        self.label = AnyView(label()); self.description = AnyView(description()); self.actions = AnyView(actions())
    }
    init<Label: View, Description: View>(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description) {
        self.init(label: label, description: description, actions: { EmptyView() })
    }
    static func search(text: String = "") -> Self {
        Self(L10n.text("No Results"), systemImage: "magnifyingglass", description: Text(text))
    }
    var body: some View {
        if #available(iOS 17, macOS 14, tvOS 17, *) {
            ContentUnavailableView { label } description: { description } actions: { actions }
        } else {
            VStack(spacing: 16) {
                label.font(.title2).multilineTextAlignment(.center)
                description.foregroundStyle(.secondary).multilineTextAlignment(.center)
                actions
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// @brief A form row with the same label and value on older systems.
struct TVLabeledContent: View {
    private let label: AnyView
    private let content: AnyView
    init<Content: View, Label: View>(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = AnyView(label()); self.content = AnyView(content())
    }
    init<Content: View>(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content, label: { Text(title) })
    }
    var body: some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) {
            LabeledContent { content } label: { label }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 16) { label; Spacer(minLength: 8); content }
        }
    }
}

struct TVShareLink<Label: View>: View {
    let item: URL
    @ViewBuilder var label: Label
    @State private var sharing = false
    var body: some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) {
            ShareLink(item: item) { label }
        } else {
            #if os(iOS)
            Button { sharing = true } label: { label }
                .sheet(isPresented: $sharing) { TVActivitySheet(item: item) }
            #else
            EmptyView()
            #endif
        }
    }
}

#if os(iOS)
struct TVActivitySheet: UIViewControllerRepresentable {
    let item: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [item], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
