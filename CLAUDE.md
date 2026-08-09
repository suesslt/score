# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Score is a shared Swift package providing framework kernel types, financial base types, temporal utilities, validation, CSV import/export, and a service middleware pipeline. It is used by sibling projects (bookscore, simscore, Aisopos, KWYK, Moneypenny, politscore, Stromabrechnungen, Auftritte, SwissInvoice). LLM clients live in the separate `ScoreAI` package (github.com/suesslt/ScoreAI) since Score v2.0.0.

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

SPM package (Swift 6.0, iOS 17+, macOS 14+) with five products:
- **Score** — Core financial and utility types
- **ScoreUI** — SwiftUI/UIKit utilities (depends on Score)
- **ScoreKeychain** — Shared keychain secret store
- **ScoreQueue** — Persistent message queue: model, coalescence, engine (Foundation only)
- **ScoreQueueGRDB** — SQLite store for `ScoreQueue` (the only target that links GRDB)

### Module: Score

#### Kernel (`Sources/Score/Kernel/`) — framework contract types (since v1.1.0)

| Type | Description |
|------|-------------|
| `DomainError` | The single serializable service error (ARCH §5.2). `notFound(entity:id:String)` with `UUID`/`Int` convenience factories; `businessRule(code:message:)` with code-only factory; `validation`, `conflict`, `unauthorized`, `storage`, `transport`. |
| `SortDirection`, `Sort`, `Pagination`, `PageLimits`, `Page` | Typed querying & pagination (ARCH §12.1). `Page<Item: Sendable>` is conditionally `Codable`/`Equatable`; `map`, `asyncMap`, `empty(size:)`, `pageCount`. Default page size 20, capped at 100. |
| `UnitOfWork` / `NoopUnitOfWork` | Transaction boundary protocol (`@escaping @Sendable` closure) + pass-through implementation for Config T. |
| `Principal` | Resolved caller identity (`userID: UUID`, `roles`, `isAdmin`) — ARCH §13.1. |

#### Financial Types (`Sources/Score/Financial/`)

| Type | Description |
|------|-------------|
| `Money` | Currency-safe monetary amounts with `Decimal` precision. Arithmetic operators (`+`, `-`, `*`, `/`) enforce matching currencies via `precondition`. Factories `Money.of(...)`, `Money.parse("CHF 100")`, Swiss formatting via `.formatted` ("1'234.56 CHF"), locale-parametrized `formatted(locale:)`, locale-independent `description` ("CHF 1234.56"), Swiss 5-centime rounding. |
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
| `CSVExporter` | Export utility. `exportCSVString()` for string output, `exportCSV()` for file output with configurable `ExportLocation` (`.temp`, `.documents`, `.custom`). |
| `CSVImporter` | Import utility. `parse(from: URL)` for files, `parse(from: String)` for strings. RFC 4180 multiline support. |
| `CSVImporter.parseWithErrors()` | Row-level error tracking: returns `CSVImportResult<T>` with `.valid` and `.errors` arrays. |
| `CSVImportResult<T>` | Result type with `valid: [T]`, `errors: [CSVImportRowError]`, `totalCount`, `hasErrors`. |

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

### Module: ScoreQueue (`Sources/ScoreQueue/`)

A durable outbound queue for pushing local changes into an external system
(address book, calendar, a remote API) **in the background**, so the UI never
waits for a foreign write. Foundation only — no persistence, no logging, no UI.

| Type | Description |
|------|-------------|
| `QueuedMessage` | The stored **intent** (`stream`, `subject`, `kind`, `attempts`, `nextAttemptAt`, `state`, `lastError`) — deliberately **no payload**: the body is read fresh from the owning row at delivery time, so late comparisons (member diffs, field masks against the current remote record) still work. `label` exists only so the failure list can name the subject. |
| `QueuedMessage.Kind.coalesced(existing:incoming:)` | The merge table as a pure function: create+update → create, create+delete → **nothing**, update+delete → delete, delete+update → update. At most one open message per `(stream, subject)`. |
| `MessageStore` | Storage port. **Must be able to run `enqueue` inside the caller's transaction** — a row change and the message about it are committed together, or not at all. |
| `InMemoryMessageStore` | Configuration T — same coalescence, same ordering. |
| `MessageHandler` | One per stream; delivers and returns a `HandlerOutcome`. Delivery must be idempotent. |
| `HandlerOutcome` | `.done`, `.discarded(reason:)` (remote state is newer — the intent is dropped and named), `.deferred(until:)` (not ready — no failed attempt), `.parked(reason:)` (no permission — the whole drain stops, no failed attempt). |
| `RetryPolicy` | `.standard` = 5 s / 30 s / 2 min. After the delays are used up the message comes to rest as `failed` and is only picked up again via `clearFailure`. |
| `QueueEngine` | Actor: `drain()` (never throws), `failedMessages()`, `retry(id:)`, `discard(id:)`. Reports through a `QueueEvent` observer — the library logs nothing itself, because it cannot know a host's privacy rules. |

### Module: ScoreQueueGRDB (`Sources/ScoreQueueGRDB/`)

| Type | Description |
|------|-------------|
| `GRDBMessageStore` | SQLite implementation. Raw SQL with explicit `Date` arguments on purpose: a Codable record would encode dates as numbers while a bound comparison parameter goes through `DatabaseValueConvertible` as text — `due(at:)` would quietly return the wrong rows. |
| `DatabaseAccess` | How the store reaches the database. Not a `DatabaseWriter`, so a host that brackets its own transactions (queue held across `await`, savepoints inside) can hand its bracket in and get transactional `enqueue`. `DatabaseWriterAccess` is the plain implementation. |
| `QueueMigration` | `register(in:name:)` into the host's own migrator — table `scoreQueueMessage`, unique index on `(stream, subject)` (the coalescence rule enforced by the database), index on `(state, nextAttemptAt)` (what the drain reads along). |

### Module: ScoreUI (`Sources/ScoreUI/`)

| Type | Description |
|------|-------------|
| `PDFRenderer` | CoreGraphics/CoreText PDF generation base class. Text (left/right-aligned), lines, shapes, images, page breaks. Subclass for domain-specific renderers. |
| `PDFTableLayout` | Table column definitions (label, x, width, rightAligned). Factory: `.evenColumns()`. |
| `PDFTableColumn` | Single column definition for table layouts. |
| `PDFRowStyle` | Row visual styles: `.normal`, `.bold`, `.header`, `.detail`, `.totals(lineStyle:)`. |
| `PDFLineStyle` | Line styles: `.single`, `.double`, `.dashed`. |
| `PDFColumnTracker` | Tracks independent y-positions for multi-column layouts (e.g. balance sheet). |
| `PDFRenderer` extensions | `drawTableHeader()`, `drawTableRow()`, `drawAlternatingRowBackground()`, `drawStyledHRule()`. |
| `LabeledTextField` | `LabeledContent` + right-aligned `TextField` form component (iOS; moved here from `Score`). |
| `LoadState` | `idle/loading/loaded/failed` state for async screens (UI-5), `failed` carries `DomainError`. |
| `DomainErrorDescribing` | Hook protocol: projects map `DomainError` → localized user text (library ships no display strings). |
| `Binding+Decimal` | SwiftUI binding helpers for Decimal input fields. |
| `ErrorAlertModifier` / `.errorAlert()` | SwiftUI modifier for error presentation via `ErrorHandler`. |
| `ErrorHandler` | Observable error state management. |

## Conventions

- All types are `Sendable`-compliant (Swift 6 concurrency)
- Value-based design (structs with protocols)
- `Decimal` arithmetic throughout — no floating-point for financial calculations
- `precondition`-based currency matching on `Money` arithmetic
- No external dependencies (pure Foundation/UIKit) — except `ScoreQueueGRDB`, the only target that links GRDB

## Test Coverage

Test suites (183 tests): MoneyTests, CurrencyTests, PercentTests, FXRateTests, VATCalculationTests, YearMonthTests, IBANValidatorTests, SCORReferenceGeneratorTests, CSVTests, KernelTests, PostalAddressTests, HomeTimeZoneTests, KeychainSecretStoreTests, Coalescence, RetryPolicy, QueueEngine, MessageStore contract, Transactional enqueue.
