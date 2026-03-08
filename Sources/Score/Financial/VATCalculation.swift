import Foundation

/// Result of a VAT split (net amount + VAT amount).
public struct VATCalculation: Sendable {
    public let netAmount: Decimal
    public let vatAmount: Decimal

    /// Calculates net and VAT amounts from a total.
    /// - Parameters:
    ///   - amount: Gross (inclusive) or net amount (exclusive)
    ///   - rate: VAT rate in percent (e.g. 8.1)
    ///   - inclusive: `true` if the amount already includes VAT
    /// - Returns: Split into net amount and VAT amount
    public static func calculate(amount: Decimal, rate: Decimal, inclusive: Bool) -> VATCalculation {
        if inclusive {
            let divisor = 1 + rate / 100
            var net = amount / divisor
            var rounded = Decimal()
            NSDecimalRound(&rounded, &net, 2, .plain)
            return VATCalculation(netAmount: rounded, vatAmount: amount - rounded)
        } else {
            return VATCalculation(netAmount: amount, vatAmount: amount * rate / 100)
        }
    }
}
