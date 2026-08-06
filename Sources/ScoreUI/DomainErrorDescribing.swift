import Score

/// Hook for mapping a `DomainError` to user-facing, localized text.
///
/// The library deliberately ships no display strings (UI-26/UI-31): each project implements this
/// protocol once — with its own String Catalog and its own `businessRule` code table — and injects
/// it wherever errors are presented.
public protocol DomainErrorDescribing: Sendable {
    func userText(for error: DomainError) -> String
}
