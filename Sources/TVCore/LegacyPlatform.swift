import Foundation
import Darwin

/// @brief A delay usable before Swift's Duration runtime (iOS 16).
public struct TVDelay: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let seconds: Double
    public static let zero = Self.seconds(0)
    public static func seconds<T: BinaryInteger>(_ value: T) -> Self { Self(seconds: Double(value)) }
    public static func seconds(_ value: Double) -> Self { Self(seconds: value) }
    public static func milliseconds<T: BinaryInteger>(_ value: T) -> Self { Self(seconds: Double(value) / 1000) }
    public static func milliseconds(_ value: Double) -> Self { Self(seconds: value / 1000) }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.seconds < rhs.seconds }
    public var description: String { "\(seconds) seconds" }

    /// @brief Playback time without the iOS 16 Duration formatter.
    public func clock(hours: Bool = false) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "--:--" }
        let value = Int(seconds)
        func padded(_ value: Int) -> String { value < 10 ? "0\(value)" : String(value) }
        if hours { return "\(value / 3600):\(padded(value / 60 % 60)):\(padded(value % 60))" }
        return "\(value / 60):\(padded(value % 60))"
    }
}

/// @brief Sleeps without blocking a thread; cancellation propagates to the caller.
/// @note No shared state. Do not call from an interrupt context.
public func tvSleep(for delay: TVDelay) async throws {
    let nanoseconds = delay.seconds * 1_000_000_000
    guard nanoseconds.isFinite, nanoseconds >= 0, nanoseconds < Double(UInt64.max) else {
        throw NSError(domain: "TVDelay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid delay"])
    }
    try await Task<Never, Never>.sleep(nanoseconds: UInt64(nanoseconds))
}

/// @brief Monotonic time including device sleep, available since iOS 10.
public struct TVInstant: Sendable, Comparable {
    private let ticks: UInt64
    public static var now: Self { Self(ticks: mach_continuous_time()) }
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()
    public func duration(to other: Self) -> TVDelay {
        let delta = other.ticks >= ticks ? Double(other.ticks - ticks) : -Double(ticks - other.ticks)
        return .seconds(delta * Self.secondsPerTick)
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.ticks < rhs.ticks }
    public static func + (lhs: Self, rhs: TVDelay) -> Self {
        let delta = rhs.seconds / secondsPerTick
        precondition(delta.isFinite && delta >= 0 && delta < Double(UInt64.max))
        let (ticks, overflow) = lhs.ticks.addingReportingOverflow(UInt64(delta))
        precondition(!overflow)
        return Self(ticks: ticks)
    }
}

/// @brief Protects one value on iOS 15; withLock is non-reentrant and must not suspend.
/// @warning Recursively acquiring this lock deadlocks. Never use it in an interrupt handler.
final class TVLocked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(initialState: Value) { value = initialState }
    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

extension URL {
    /// @brief Appends query items without discarding the existing query or fragment.
    func tvAppending(queryItems: [URLQueryItem]) -> URL {
        guard var parts = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        parts.queryItems = (parts.queryItems ?? []) + queryItems
        return parts.url ?? self
    }
}

/// @brief Foundation regex captures retain indices into the original string, including Unicode.
struct TVRegexMatch {
    let captures: [Substring]
    var range: Range<String.Index> { captures[0].startIndex..<captures[0].endIndex }
    subscript(_ index: Int) -> Substring { captures[index] }
}

extension StringProtocol where SubSequence == Substring {
    func tvMatches(_ pattern: String) -> [TVRegexMatch] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = String(self)
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            TVRegexMatch(captures: (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: self) else { return self[startIndex..<startIndex] }
                return self[range]
            })
        }
    }
    /// @brief Stops at the first match instead of allocating every match in a large source document.
    func tvFirstMatch(_ pattern: String) -> TVRegexMatch? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let text = String(self)
        guard let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return TVRegexMatch(captures: (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: self) else { return self[startIndex..<startIndex] }
            return self[range]
        })
    }
    func tvReplacing(_ pattern: String, with replacement: String) -> String {
        String(self).replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }
}
