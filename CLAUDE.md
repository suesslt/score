# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Score is a shared Swift package providing financial base types, temporal utilities, validation, CSV import/export, and a service middleware pipeline. It is used as a local dependency by sibling projects (Konten, Odyssey, SwissInvoice, Stromabrechnungen, Auftritte, EpocServer).

## Build & Test Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a single test
swift test --filter ScoreTests.MoneyTests
```

## Architecture

SPM package (Swift 6.0, iOS 17+, macOS 14+) with two products:
- **Score** — Core financial and utility types
- **ScoreUI** — SwiftUI/UIKit utilities (depends on Score)

### Module: Score

#### Financial Types (`Sources/Score/Financial/`)

| Type | Description |
|------|-------------|
| `Money` | Currency-safe monetary amounts with `Decimal` precision. Arithmetic operators (`+`, `-`, `*`, `/`) enforce matching currencies via `precondition`. Supports formatting and Swiss 5-centime rounding. |
| `Currency` | ISO 4217 enum with 180+ currencies. Provides `decimalPlaces`, `symbol`, localized German `displayName`. |
| `Percent` | Percentage stored as factor (e.g. `0.10` = 10%). Factory methods: `Percent("10%")`, `Percent(decimal: 0.10)`. |
| `FXRate` | Bid/ask exchange rates with `mid`, `spread`. Conversion: `convert(_:at:)` with `.mid`/`.bid`/`.ask`. Inverse via `inverse()`. |
| `VATCalculation` | VAT split into net/gross amounts. Supports inclusive/exclusive calculation. |
| `DayCountRule` | Financial day count conventions: ACT/360, ACT/365, 30/360, etc. |
| `InterestCalculationRule` | Interest accrual rules. |

#### Temporal Types (`Sources/Score/Temporal/`)

| Type | Description |
|------|-------------|
| `YearMonth` | Year-month value type. Parsing, comparison, month arithmetic (`adding(months:)`), date conversion. |

#### Services (`Sources/Score/Services/`)

| Type | Description |
|------|-------------|
| `ServicePipeline` | Async middleware chain for cross-cutting concerns. |
| `ServiceMiddleware` | Protocol for pipeline interceptors. |
| `LoggingMiddleware` | Standard logging implementation. |
| `ServiceError` | Typed errors: `.notFound`, `.validation`, `.businessRule`, `.persistence`, `.authorization`, `.conflict`, `.calculation`, `.importError`. |

#### CSV (`Sources/Score/CSV/`)

| Type | Description |
|------|-------------|
| `CSVExportable` | Protocol — types that export as CSV rows. |
| `ExportColumn` | Column metadata (title, width hint). |
| `CSVExporter` | Export utility. |
| `CSVImporter` | Import utility with encoding detection. |

#### Validation (`Sources/Score/Validation/`)

| Type | Description |
|------|-------------|
| `IBANValidator` | ISO 13616 / ISO 7064 (Mod-97) IBAN validation. |
| `SCORReferenceGenerator` | ISO 11649 creditor reference formatting with Mod 97 check digits. |

#### Extensions (`Sources/Score/Extensions/`)
- `Date+Formatting` — Date formatting utilities
- `Decimal+Formatting` — Decimal formatting utilities

#### Utilities (`Sources/Score/Utilities/`)
- `SimpleProfiler` — Performance measurement

### Module: ScoreUI (`Sources/ScoreUI/`)

| Type | Description |
|------|-------------|
| `PDFRenderer` | UIKit-based PDF generation from SwiftUI/UIKit views. |
| `Binding+Decimal` | SwiftUI binding helpers for Decimal input fields. |
| `ErrorAlertModifier` / `.errorAlert()` | SwiftUI modifier for error presentation via `ErrorHandler`. |
| `ErrorHandler` | Observable error state management. |

## Conventions

- All types are `Sendable`-compliant (Swift 6 concurrency)
- Value-based design (structs with protocols)
- `Decimal` arithmetic throughout — no floating-point for financial calculations
- `precondition`-based currency matching on `Money` arithmetic
- No external dependencies (pure Foundation/UIKit)

## Test Coverage

8 test suites: MoneyTests, CurrencyTests, PercentTests, FXRateTests, VATCalculationTests, YearMonthTests, IBANValidatorTests, SCORReferenceGeneratorTests.
