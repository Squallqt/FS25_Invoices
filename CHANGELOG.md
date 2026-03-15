# Changelog

All notable changes to FS25_Invoices will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for v1.2.0.0

- Late payment penalties with automatic surcharge
- Manual work entry for custom service types
- Admin settings UI for VAT rate configuration in-game

## [1.1.0.0] - 2026-03-15

### Added

- Realistic VAT system based on French fiscal law with 4 rate groups (service 20%, fieldwork 5.5%, forestry 10%, product 5.5%)
- Per-lineItem editable VAT rate in wizard step 4
- HT / TVA / TTC breakdown displayed in WizardStep4 and DetailDialog
- Externalized VAT configuration in `data/vatRates.xml`
- Optional RedTape mod integration (runtime detection, VAT deducted from economy when active)
- Separate Finance tab entries: Invoice Income (HT) and Invoice Expense (TTC)
- Dynamic separator in total bar adapting to text width
- Rounded corners on total bar background

### Changed

- Split single `MoneyType.INVOICE_PAYMENT` into `INVOICE_INCOME` and `INVOICE_EXPENSE`
- Savegame version bumped from 2 to 3 (v2 retrocompat preserved)
- Footer layout: TVA input added, other inputs rebalanced

### Technical

- VAT formula: `TVA = round(TTC × rate / (1 + rate))`, `HT = TTC - TVA`
- Server-authoritative VAT recalculation in `InvoiceCreateEvent`
- Stream serialization updated for `vatAmount`, `totalHT`, per-lineItem `vatRate`

## [1.0.0.0] - 2026-02-18

### Added
- Initial ModHub release
- 54 predefined work types covering all agricultural operations
- 4-step invoice creation wizard
- Incoming/outgoing invoice management interface
- Payment processing with Finance tab integration
- Automatic payment reminder system
- Multiplayer synchronization with late-join support
- Savegame persistence
- 25 language localizations
- Dynamic pricing based on economic difficulty
- Field reference system for invoices

### Technical
- MVC architecture with service layer
- Custom network events for multiplayer sync
- Server-authoritative money transfers
- XML-based savegame serialization
- Custom Finance integration via MoneyType registration