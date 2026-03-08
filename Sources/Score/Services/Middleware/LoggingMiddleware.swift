import Foundation
import os

/// Logs every service request with timing information.
public struct LoggingMiddleware: ServiceMiddleware {
    private let logger: Logger

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.score", category: String = "ServicePipeline") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    nonisolated public func intercept<Request: Sendable, Response: Sendable>(
        request: Request,
        next: @Sendable (Request) async throws -> Response
    ) async throws -> Response {
        let requestName = String(describing: type(of: request))
        let start = ContinuousClock.now
        logger.debug("[\(requestName)] started")

        do {
            let response = try await next(request)
            let elapsed = start.duration(to: .now)
            logger.info("[\(requestName)] completed in \(elapsed)")
            return response
        } catch {
            let elapsed = start.duration(to: .now)
            logger.error("[\(requestName)] failed after \(elapsed): \(error.localizedDescription)")
            throw error
        }
    }
}
