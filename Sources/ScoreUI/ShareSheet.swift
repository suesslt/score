#if canImport(UIKit) && !os(watchOS)
import SwiftUI
import UIKit

/// `UIActivityViewController` als SwiftUI-View — der geteilte Share-Wrapper der
/// Scoreware-Apps (vorher je eine Kopie in fdpposter, Auftritte, …).
///
/// Präsentation über `.sheet`; auf dem iPad erscheint das System-Sheet als
/// Formsheet, ein Popover-Anker ist dann nicht nötig.
///
/// ```swift
/// .sheet(isPresented: $showShare) {
///     ShareSheet(items: [fileURL]) { completed in
///         if completed { markAsShared() }
///     }
/// }
/// ```
public struct ShareSheet: UIViewControllerRepresentable {
    private let items: [Any]
    private let onComplete: ((_ completed: Bool) -> Void)?

    /// - Parameters:
    ///   - items: Die Activity-Items (URLs, Bilder, Strings, …).
    ///   - onComplete: Wird nach dem Schliessen aufgerufen; `completed` sagt, ob
    ///     der Nutzer eine Aktivität abgeschlossen (nicht abgebrochen) hat.
    public init(items: [Any], onComplete: ((_ completed: Bool) -> Void)? = nil) {
        self.items = items
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let onComplete {
            controller.completionWithItemsHandler = { _, completed, _, _ in
                onComplete(completed)
            }
        }
        return controller
    }

    public func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
