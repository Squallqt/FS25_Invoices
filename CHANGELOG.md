# Changelog

All notable changes to FS25_Invoices will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for v1.1.0.0
- VAT/tax calculation with configurable rates
- Late payment penalties with automatic surcharge
- Manual work entry for custom service types
- RedTape mod integration (under evaluation)

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