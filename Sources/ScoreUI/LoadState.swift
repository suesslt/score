import Score

/// The state of an asynchronous screen (UI-5): explicit `idle/loading/loaded/failed`,
/// so a load in progress, an empty result, and an error are always distinguishable.
public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(DomainError)

    public var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    public var error: DomainError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension LoadState: Equatable where Value: Equatable {}
