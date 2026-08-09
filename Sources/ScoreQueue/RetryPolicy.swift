import Foundation

/// How often a failing message is retried, and how long the waits are.
///
/// After the *n*-th failed attempt the message waits `delays[n - 1]`; once the
/// delays are used up it comes to rest as `failed` and is only picked up again
/// when someone clears the failure. Three quiet retries, then a named entry —
/// rather than a message that keeps trying forever and is never noticed.
public struct RetryPolicy: Sendable, Equatable {

    public let delays: [TimeInterval]

    public init(delays: [TimeInterval]) {
        self.delays = delays
    }

    /// 5 s, 30 s, 2 min.
    public static let standard = RetryPolicy(delays: [5, 30, 120])

    /// What happens after a failed attempt number `attempts`.
    public enum Next: Sendable, Equatable {
        case retry(at: Date)
        case markFailed
    }

    public func next(afterAttempt attempts: Int, now: Date) -> Next {
        guard attempts >= 1, attempts <= delays.count else { return .markFailed }
        return .retry(at: now.addingTimeInterval(delays[attempts - 1]))
    }
}
