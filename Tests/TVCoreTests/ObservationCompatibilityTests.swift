import Foundation
import Observation
import Perception
import Testing
@testable import TVCore

/// The tracking callback is Sendable; a lock protects the test's notification count.
private final class ObservationNotifications: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func received() { lock.lock(); defer { lock.unlock() }; count += 1 }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@Test @MainActor func sourceOrderNotifiesThroughCompatibilityTracking() throws {
    let defaults = try #require(UserDefaults(suiteName: "observation." + UUID().uuidString))
    let model = SourceOrder(defaults: defaults)
    let notifications = ObservationNotifications()
    withPerceptionTracking { _ = model.enabled } onChange: { notifications.received() }
    model.enabled.toggle()
    #expect(notifications.value == 1)
    #expect(model.revision == 1)
    // Tracking is one-shot; registering again must observe subsequent changes.
    withPerceptionTracking { _ = model.enabled } onChange: { notifications.received() }
    model.enabled.toggle()
    #expect(notifications.value == 2)
    #expect(model.revision == 2)
    defaults.removeObject(forKey: "sourceOrder.enabled")
}

@Test @MainActor func ignoredSourceOrderCallbackDoesNotNotifyObservers() throws {
    let defaults = try #require(UserDefaults(suiteName: "observation." + UUID().uuidString))
    let model = SourceOrder(defaults: defaults)
    let notifications = ObservationNotifications()
    withPerceptionTracking { _ = model.onChange } onChange: { notifications.received() }
    model.onChange = {}
    #expect(notifications.value == 0)
}

@available(iOS 17, macOS 14, tvOS 17, *)
@Test @MainActor func compatibilityModelsStillNotifyNativeObservation() throws {
    let defaults = try #require(UserDefaults(suiteName: "observation." + UUID().uuidString))
    let model = SourceOrder(defaults: defaults)
    let notifications = ObservationNotifications()
    withObservationTracking { _ = model.enabled } onChange: { notifications.received() }
    model.enabled.toggle()
    #expect(notifications.value == 1)
    defaults.removeObject(forKey: "sourceOrder.enabled")
}
