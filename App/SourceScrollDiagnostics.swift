#if os(iOS)
import SwiftUI
import UIKit
import TVCore

/// @brief Observe the iOS 15 source page for ten seconds without changing its layout or scrolling.
/// @note Main actor only. The timer captures the probe weakly and stops when detached.
/// No delegate, gesture recognizer, content offset or inset is replaced.
struct SourceScrollDiagnostics: UIViewRepresentable {
    let loading: Bool
    let videos: Int

    func makeUIView(context: Context) -> Probe {
        let view = Probe(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: Probe, context: Context) {
        view.loading = loading
        view.videos = videos
    }

    static func dismantleUIView(_ view: Probe, coordinator: ()) { view.stop() }

    final class Probe: UIView {
        var loading = false
        var videos = 0
        private var timer: Timer?
        private var ticks = 0
        private var previous = ""

        override func didMoveToWindow() {
            super.didMoveToWindow()
            stop()
            guard window != nil, ticks < 40 else { return }
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in self?.sample() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        func stop() { timer?.invalidate(); timer = nil }

        private func sample() {
            guard window != nil else { stop(); return }
            ticks += 1
            defer { if ticks >= 40 { stop() } }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    let inset = scroll.adjustedContentInset
                    let frame = scroll.convert(scroll.bounds, to: window)
                    let phase = scroll.isDragging ? "dragging" : scroll.isDecelerating ? "decelerating" : "idle"
                    let message = String(format:
                        "offsetY=%.1f insetTop=%.1f insetBottom=%.1f rawInsetTop=%.1f rawInsetBottom=%.1f contentHeight=%.1f viewportY=%.1f viewportWidth=%.1f viewportHeight=%.1f",
                        Double(scroll.contentOffset.y), Double(inset.top), Double(inset.bottom), Double(scroll.contentInset.top), Double(scroll.contentInset.bottom),
                        Double(scroll.contentSize.height), Double(frame.minY), Double(scroll.bounds.width), Double(scroll.bounds.height))
                        + " phase=\(phase) busy=\(loading) videos=\(videos)"
                    if message != previous {
                        Diagnostics.shared.record(.info, "site-layout", "probe=\(ObjectIdentifier(self)) sample=\(ticks) " + message)
                        previous = message
                    }
                    if ticks == 40 { Diagnostics.shared.record(.info, "site-layout", "Sampling finished") }
                    return
                }
                ancestor = view.superview
            }
            if ticks == 1 || ticks == 40 {
                Diagnostics.shared.record(.info, "site-layout", "sample=\(ticks) enclosing scroll view not found")
            }
        }
    }
}
#endif
