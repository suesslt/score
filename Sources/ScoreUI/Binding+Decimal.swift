import SwiftUI
import Score

// MARK: - Binding Helper for Decimal Input Fields

extension Binding where Value == Decimal {
    /// Creates a String binding for rate input fields.
    /// Normalizes input: comma to dot, removes apostrophes.
    /// Shows empty string for zero, sets zero for empty input.
    public func rateBinding() -> Binding<String> {
        Binding<String>(
            get: {
                wrappedValue == .zero ? "" : wrappedValue.formattedRate()
            },
            set: { newValue in
                let normalized = newValue
                    .replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: "'", with: "")
                if let decimal = Decimal(string: normalized) {
                    wrappedValue = decimal
                } else if newValue.isEmpty {
                    wrappedValue = .zero
                }
            }
        )
    }

    /// Creates a String binding for monetary amount input fields.
    public func amountBinding() -> Binding<String> {
        Binding<String>(
            get: {
                wrappedValue == .zero ? "" : wrappedValue.formattedAmount()
            },
            set: { newValue in
                let normalized = newValue
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "'", with: "")
                if let decimal = Decimal(string: normalized) {
                    wrappedValue = decimal
                } else if newValue.isEmpty {
                    wrappedValue = .zero
                }
            }
        )
    }
}
