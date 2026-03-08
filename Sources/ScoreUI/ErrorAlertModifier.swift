import SwiftUI

/// Error handler for user-facing error alerts.
@MainActor
public class ErrorHandler: ObservableObject {
    @Published public var currentError: ErrorWrapper?
    @Published public var isShowingError = false

    public init() {}

    public func handle(_ error: Error, title: String = "Error", message: String? = nil) {
        currentError = ErrorWrapper(
            error: error,
            title: title,
            message: message ?? error.localizedDescription
        )
        isShowingError = true
    }
}

public struct ErrorWrapper: Identifiable, Sendable {
    public let id = UUID()
    public let error: any Error
    public let title: String
    public let message: String
}

/// ViewModifier for error handling alerts.
public struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler

    public init(errorHandler: ErrorHandler) {
        self.errorHandler = errorHandler
    }

    public func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.title ?? "Error",
                isPresented: $errorHandler.isShowingError,
                presenting: errorHandler.currentError
            ) { _ in
                Button("OK", role: .cancel) {
                    errorHandler.currentError = nil
                }
            } message: { error in
                Text(error.message)
            }
    }
}

extension View {
    public func errorAlert(errorHandler: ErrorHandler) -> some View {
        modifier(ErrorAlertModifier(errorHandler: errorHandler))
    }
}
