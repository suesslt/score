import Foundation

/// Middleware protocol: enables cross-cutting concerns
/// (logging, audit, permissions) on every service call.
public protocol ServiceMiddleware: Sendable {
    /// Intercepts a service call. Must call `next(request)` to continue.
    nonisolated func intercept<Request: Sendable, Response: Sendable>(
        request: Request,
        next: @Sendable (Request) async throws -> Response
    ) async throws -> Response
}

/// Pipeline that chains middleware instances.
/// Every service call passes through the middleware chain before the handler executes.
public struct ServicePipeline: Sendable {
    private let middlewares: [ServiceMiddleware]

    public init(middlewares: [ServiceMiddleware] = []) {
        self.middlewares = middlewares
    }

    /// Executes the handler after all middlewares have been traversed.
    public func execute<Request: Sendable, Response: Sendable>(
        request: Request,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) async throws -> Response {
        // Build chain from inside out
        var next: @Sendable (Request) async throws -> Response = handler
        for middleware in middlewares.reversed() {
            let currentNext = next
            let currentMiddleware = middleware
            next = { request in
                try await currentMiddleware.intercept(
                    request: request,
                    next: currentNext
                )
            }
        }
        return try await next(request)
    }
}
