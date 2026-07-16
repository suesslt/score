import Foundation
#if canImport(os)
import os
#endif

/// Logs every service request with timing information.
public struct LoggingMiddleware: ServiceMiddleware {
    #if canImport(os)
    private let logger: Logger
    #else
    private let category: String
    #endif

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.score", category: String = "ServicePipeline") {
        #if canImport(os)
        self.logger = Logger(subsystem: subsystem, category: category)
        #else
        self.category = category
        #endif
    }

    nonisolated public func intercept<Request: Sendable, Response: Sendable>(
        request: Request,
        next: @Sendable (Request) async throws -> Response
    ) async throws -> Response {
        let requestName = String(describing: type(of: request))
        let start = ContinuousClock.now
        #if canImport(os)
        logger.debug("[\(requestName)] started")
        #else
        print("[\(category)] [\(requestName)] started")
        #endif

        do {
            let response = try await next(request)
            let elapsed = start.duration(to: .now)
            #if canImport(os)
            logger.info("[\(requestName)] completed in \(elapsed)")
            #else
            print("[\(category)] [\(requestName)] completed in \(elapsed)")
            #endif
            return response
        } catch {
            let elapsed = start.duration(to: .now)
            #if canImport(os)
            logger.error("[\(requestName)] failed after \(elapsed): \(error.localizedDescription)")
            #else
            print("[\(category)] [\(requestName)] failed after \(elapsed): \(error.localizedDescription)")
            #endif
            throw error
        }
    }
}
